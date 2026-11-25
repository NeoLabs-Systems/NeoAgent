// Package github is GitHub as a chat surface: approved people @mention the
// agent's account on an issue or pull request and it answers in that thread.
// Nothing is registered on GitHub; each agent polls its watched repositories
// with its own Mentions connection and keeps its own cursors.
package github

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/messaging"
	"github.com/NeoLabs-Systems/neolabs-go/ssrf"
)

const (
	defaultPollInterval   = 30 * time.Second
	maxPagesPerPoll       = 3
	maxSeenComments       = 2000
	maxTrackedRunComments = 500
	notificationsCursor   = "@notifications"
	accessTargetsTTL      = 5 * time.Minute
	defaultAPIURL         = "https://api.github.com"
)

var (
	threadIDPattern = regexp.MustCompile(`^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#(\d+)(?::(\d+))?$`)
	pullPathPattern = regexp.MustCompile(`/pull/\d+`)
	repoRoles       = []string{"OWNER", "MEMBER", "COLLABORATOR"}
)

// Credentials gives the token of the agent's connected GitHub "Mentions"
// integration. It is read on every request so a reconnect or disconnect under
// Integrations takes effect without restarting the platform.
type Credentials interface {
	// MentionsToken returns the access token, or "" when the agent has no
	// connected Mentions account.
	MentionsToken(ctx context.Context, userID int64, agentID string) (string, error)
}

// Cursors persists each agent's polling position (the agent setting
// github_mentions_cursors: repository, lower-cased, to the newest created_at
// seen).
type Cursors interface {
	Load(ctx context.Context, userID int64, agentID string) (map[string]string, error)
	Save(ctx context.Context, userID int64, agentID string, cursors map[string]string) error
}

// Deps are the adapter's dependencies.
type Deps struct {
	Credentials Credentials
	Cursors     Cursors
	// APIURL overrides https://api.github.com.
	APIURL string
	// Client overrides the HTTP client (default: an ssrf client).
	Client *http.Client
	// PollInterval overrides the 30 second polling interval.
	PollInterval time.Duration
}

// Factory builds GitHub connections.
func Factory(deps Deps) messaging.Factory {
	return func(cfg messaging.Config, ev messaging.Events) (messaging.Platform, error) {
		if deps.APIURL == "" {
			deps.APIURL = defaultAPIURL
		}
		if deps.Client == nil {
			deps.Client = ssrf.NewClient(ssrf.Options{})
		}
		if deps.PollInterval == 0 {
			deps.PollInterval = defaultPollInterval
		}
		log := cfg.Log
		if log == nil {
			log = slog.Default()
		}
		return &Platform{
			deps: deps, ev: ev, userID: cfg.UserID, agentID: cfg.AgentID, log: log,
			guard:      messaging.NewAccessGuard("github", cfg, ev),
			status:     messaging.StatusDisconnected,
			seen:       newOrderedSet(maxSeenComments),
			ownIDs:     map[int64]bool{},
			runComment: newRunComments(),
		}, nil
	}
}

type account struct {
	ID    int64
	Login string
}

// Platform is one agent's GitHub connection.
type Platform struct {
	deps    Deps
	ev      messaging.Events
	userID  int64
	agentID string
	log     *slog.Logger
	guard   *messaging.AccessGuard

	mu       sync.Mutex
	status   string
	account  *account
	cursors  map[string]string
	cancel   context.CancelFunc
	loopDone chan struct{}
	polling  sync.Mutex

	seen       *orderedSet
	ownIDs     map[int64]bool // guarded by mu
	runComment *runComments
	targets    *targetsCache
}

func (p *Platform) Status() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.status
}

func (p *Platform) setStatus(s string) {
	p.mu.Lock()
	p.status = s
	p.mu.Unlock()
}

func (p *Platform) SetAccessPolicy(a messaging.AccessPolicy) { p.guard.SetPolicy(a) }
func (p *Platform) AccessPolicy() messaging.AccessPolicy     { return p.guard.Policy() }

func (p *Platform) AuthInfo() map[string]any {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.account == nil {
		return nil
	}
	return map[string]any{"username": p.account.Login}
}

// WatchedRepos is the access policy read as a watch list: a repository is
// polled when a rule names it, on its own or as the place an approved person
// may ask.
func (p *Platform) WatchedRepos() []string {
	policy := p.guard.Policy()
	if policy.SharedPolicy == "disabled" {
		return nil
	}
	byLower := map[string]string{}
	var order []string
	add := func(repo string) {
		key := strings.ToLower(repo)
		if _, ok := byLower[key]; !ok {
			order = append(order, key)
		}
		byLower[key] = repo
	}
	for _, r := range policy.SharedSpaceRules {
		if r.Scope == "group" {
			add(r.Value)
		}
	}
	for _, r := range policy.SharedMemberRules {
		if r.SpaceScope == "group" {
			add(r.SpaceValue)
		}
	}
	out := make([]string, len(order))
	for i, k := range order {
		out[i] = byLower[k]
	}
	return out
}

// --- REST ---------------------------------------------------------------------

// APIError is a failed GitHub API call.
type APIError struct {
	Status  int
	Message string
}

func (e *APIError) Error() string { return e.Message }

type query [][2]string

type request struct {
	method string
	path   string
	query  query
	body   any
}

func (p *Platform) token(ctx context.Context) (string, error) {
	return p.deps.Credentials.MentionsToken(ctx, p.userID, p.agentID)
}

// call runs one API request and decodes a JSON answer into out (when not nil).
func (p *Platform) call(ctx context.Context, token string, r request, out any) error {
	base, err := url.Parse(p.deps.APIURL)
	if err != nil {
		return err
	}
	ref, err := url.Parse(r.path)
	if err != nil {
		return err
	}
	u := base.ResolveReference(ref)
	if len(r.query) > 0 {
		parts := make([]string, len(r.query))
		for i, kv := range r.query {
			parts[i] = url.QueryEscape(kv[0]) + "=" + url.QueryEscape(kv[1])
		}
		u.RawQuery = strings.Join(parts, "&")
	}
	var body io.Reader
	if r.body != nil {
		raw, err := json.Marshal(r.body)
		if err != nil {
			return err
		}
		body = bytes.NewReader(raw)
	}
	method := r.method
	if method == "" {
		method = http.MethodGet
	}
	req, err := http.NewRequestWithContext(ctx, method, u.String(), body)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := p.deps.Client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 16<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		return apiError(resp.StatusCode, raw)
	}
	if out == nil || resp.StatusCode == 204 || resp.StatusCode == 205 || len(bytes.TrimSpace(raw)) == 0 {
		return nil
	}
	return json.Unmarshal(raw, out)
}

func apiError(status int, raw []byte) error {
	var data struct {
		Message string `json:"message"`
	}
	if json.Unmarshal(raw, &data) != nil {
		return &APIError{Status: status, Message: fmt.Sprintf("GitHub API error %d: %s", status, raw)}
	}
	if data.Message == "" {
		data.Message = fmt.Sprintf("GitHub API error: %d", status)
	}
	return &APIError{Status: status, Message: data.Message}
}

// --- Connection lifecycle -----------------------------------------------------

func (p *Platform) Connect(ctx context.Context) error {
	token, err := p.token(ctx)
	if err != nil {
		return err
	}
	if token == "" {
		return errors.New("Connect a GitHub account under Integrations → GitHub → Mentions first.")
	}
	var user struct {
		ID    int64  `json:"id"`
		Login string `json:"login"`
	}
	if err := p.call(ctx, token, request{path: "/user"}, &user); err != nil {
		return err
	}
	cursors, err := p.deps.Cursors.Load(ctx, p.userID, p.agentID)
	if err != nil {
		return err
	}
	if cursors == nil {
		cursors = map[string]string{}
	}
	p.mu.Lock()
	p.account = &account{ID: user.ID, Login: user.Login}
	p.cursors = cursors
	p.status = messaging.StatusConnected
	loopCtx, cancel := context.WithCancel(context.Background())
	p.cancel, p.loopDone = cancel, make(chan struct{})
	done := p.loopDone
	p.mu.Unlock()
	p.ev.Connected()
	go p.loop(loopCtx, done)
	return nil
}

func (p *Platform) loop(ctx context.Context, done chan struct{}) {
	defer close(done)
	delay := time.Duration(0)
	for {
		select {
		case <-ctx.Done():
			return
		case <-time.After(delay):
		}
		p.Poll(ctx)
		if p.Status() != messaging.StatusConnected {
			return
		}
		delay = p.deps.PollInterval
	}
}

func (p *Platform) Disconnect(context.Context) error {
	p.mu.Lock()
	cancel, done := p.cancel, p.loopDone
	p.cancel, p.loopDone = nil, nil
	p.status = messaging.StatusDisconnected
	p.mu.Unlock()
	if cancel != nil {
		cancel()
		<-done
	}
	p.ev.Disconnected(messaging.Disconnect{Manual: true})
	return nil
}

// Logout holds no login, so it is a disconnect.
func (p *Platform) Logout(ctx context.Context) error { return p.Disconnect(ctx) }

func (p *Platform) lostAuth() {
	p.setStatus(messaging.StatusDisconnected)
	p.ev.Disconnected(messaging.Disconnect{RequiresUserAction: true, Reason: "authentication_required"})
}

// --- Polling --------------------------------------------------------------------

type commentSource struct {
	kind  string
	path  string
	query query
	// number is the issue or pull request number the item belongs to.
	number func(c *comment) int64
}

func numberFromURL(u string) int64 {
	i := strings.LastIndex(u, "/")
	if i < 0 {
		return 0
	}
	n, err := strconv.ParseInt(u[i+1:], 10, 64)
	if err != nil {
		return 0
	}
	return n
}

// Where a mention can be written: a comment in the conversation, a line
// comment in a review, or the description of a new issue or pull request.
var (
	issueComment  = &commentSource{kind: "issue_comment", path: "issues/comments", number: func(c *comment) int64 { return numberFromURL(c.IssueURL) }}
	reviewComment = &commentSource{kind: "review_comment", path: "pulls/comments", number: func(c *comment) int64 { return numberFromURL(c.PullRequestURL) }}
	issueBody     = &commentSource{kind: "issue_body", path: "issues", query: query{{"state", "all"}}, number: func(c *comment) int64 { return c.Number }}
	allSources    = []*commentSource{issueComment, reviewComment, issueBody}
)

type comment struct {
	ID   int64 `json:"id"`
	User struct {
		ID    int64  `json:"id"`
		Login string `json:"login"`
		Type  string `json:"type"`
	} `json:"user"`
	Body              string `json:"body"`
	CreatedAt         string `json:"created_at"`
	HTMLURL           string `json:"html_url"`
	AuthorAssociation string `json:"author_association"`
	InReplyToID       int64  `json:"in_reply_to_id"`
	Path              string `json:"path"`
	Line              int64  `json:"line"`
	DiffHunk          string `json:"diff_hunk"`
	IssueURL          string `json:"issue_url"`
	PullRequestURL    string `json:"pull_request_url"`
	Number            int64  `json:"number"`
}

// Poll reads every watched repository and the account's notifications once. A
// poll already running is waited for rather than doubled.
func (p *Platform) Poll(ctx context.Context) {
	p.polling.Lock()
	defer p.polling.Unlock()
	p.pollOnce(ctx)
}

func (p *Platform) pollOnce(ctx context.Context) {
	if p.Status() != messaging.StatusConnected {
		return
	}
	token, err := p.token(ctx)
	if err != nil || token == "" {
		p.lostAuth()
		return
	}
	startedAt := time.Now().UTC().Format("2006-01-02T15:04:05.000Z")
	watched := p.WatchedRepos()
	for _, repo := range watched {
		key := strings.ToLower(repo)
		// A newly watched repository starts now, or at the mention that led the
		// owner to approve it, so that request still gets its answer.
		since := p.cursor(key)
		if since == "" {
			since = startedAt
		}
		newest := since
		failed := error(nil)
		for _, source := range allSources {
			if newest, failed = p.pollSource(ctx, token, repo, source, since, newest); failed != nil {
				break
			}
		}
		if failed == nil {
			p.setCursor(key, newest)
			continue
		}
		var apiErr *APIError
		if errors.As(failed, &apiErr) && apiErr.Status == http.StatusUnauthorized {
			p.lostAuth()
			return
		}
		p.log.Warn("GitHub polling failed", "repository", repo, "error", failed)
	}
	watchedSet := make(map[string]bool, len(watched))
	for _, r := range watched {
		watchedSet[strings.ToLower(r)] = true
	}
	if err := p.discoverMentions(ctx, token, watchedSet, startedAt); err != nil {
		p.log.Warn("Reading GitHub notifications failed", "error", err)
	}
	p.mu.Lock()
	snapshot := make(map[string]string, len(p.cursors))
	for k, v := range p.cursors {
		snapshot[k] = v
	}
	p.mu.Unlock()
	if err := p.deps.Cursors.Save(ctx, p.userID, p.agentID, snapshot); err != nil {
		p.log.Warn("Saving GitHub cursors failed", "error", err)
	}
}

func (p *Platform) cursor(key string) string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.cursors[key]
}

func (p *Platform) setCursor(key, value string) {
	p.mu.Lock()
	p.cursors[key] = value
	p.mu.Unlock()
}

func (p *Platform) pollSource(ctx context.Context, token, repo string, src *commentSource, since, newest string) (string, error) {
	for page := 1; page <= maxPagesPerPoll; page++ {
		q := append(append(query{}, src.query...),
			[2]string{"since", since}, [2]string{"sort", "created"}, [2]string{"direction", "asc"},
			[2]string{"per_page", "100"}, [2]string{"page", strconv.Itoa(page)})
		var list []comment
		if err := p.call(ctx, token, request{path: "/repos/" + repo + "/" + src.path, query: q}, &list); err != nil {
			return newest, err
		}
		for i := range list {
			c := &list[i]
			// `since` matches on update time; older comments that were edited are
			// not new requests.
			if c.CreatedAt < since {
				continue
			}
			if c.CreatedAt > newest {
				newest = c.CreatedAt
			}
			p.handleComment(ctx, token, repo, src, c, "")
		}
		if len(list) < 100 {
			break
		}
	}
	return newest, nil
}

// discoverMentions finds mentions outside the watched repositories through the
// account's notifications. A person approved everywhere is answered there;
// anyone else raises the usual "allow this sender?" prompt.
func (p *Platform) discoverMentions(ctx context.Context, token string, watched map[string]bool, startedAt string) error {
	since := p.cursor(notificationsCursor)
	if since == "" {
		since = startedAt
	}
	var notifications []struct {
		UpdatedAt  string `json:"updated_at"`
		Reason     string `json:"reason"`
		Repository struct {
			FullName string `json:"full_name"`
		} `json:"repository"`
		Subject struct {
			LatestCommentURL string `json:"latest_comment_url"`
			URL              string `json:"url"`
		} `json:"subject"`
	}
	q := query{{"all", "true"}, {"participating", "true"}, {"since", since}, {"per_page", "50"}}
	if err := p.call(ctx, token, request{path: "/notifications", query: q}, &notifications); err != nil {
		return err
	}
	newest := since
	for _, n := range notifications {
		if n.UpdatedAt > newest {
			newest = n.UpdatedAt
		}
		repo := n.Repository.FullName
		if n.Reason != "mention" || repo == "" || watched[strings.ToLower(repo)] {
			continue
		}
		raw := n.Subject.LatestCommentURL
		if raw == "" {
			raw = n.Subject.URL
		}
		src := issueBody
		switch {
		case strings.Contains(raw, "/pulls/comments/") && numberFromURL(raw) > 0:
			src = reviewComment
		case strings.Contains(raw, "/issues/comments/") && numberFromURL(raw) > 0:
			src = issueComment
		}
		u, err := url.Parse(raw)
		if err != nil || u.Host == "" {
			return fmt.Errorf("invalid notification url %q", raw)
		}
		var item comment
		if err := p.call(ctx, token, request{path: u.Path}, &item); err != nil {
			return err
		}
		blocked := p.handleComment(ctx, token, repo, src, &item, "discovered")
		key := strings.ToLower(repo)
		if cur := p.cursor(key); blocked && item.CreatedAt != "" && (cur == "" || item.CreatedAt < cur) {
			p.setCursor(key, item.CreatedAt)
		}
	}
	p.setCursor(notificationsCursor, newest)
	return nil
}

func (p *Platform) markSeen(key string) { p.seen.add(key) }

func (p *Platform) isOwnReviewComment(ctx context.Context, token, repo string, id int64) bool {
	if id == 0 {
		return false
	}
	if p.ownComment(id) {
		return true
	}
	var parent comment
	if err := p.call(ctx, token, request{path: fmt.Sprintf("/repos/%s/pulls/comments/%d", repo, id)}, &parent); err != nil {
		return false
	}
	return parent.User.ID == p.accountID()
}

func (p *Platform) ownComment(id int64) bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.ownIDs[id]
}

func (p *Platform) rememberOwn(id int64) {
	p.mu.Lock()
	p.ownIDs[id] = true
	p.mu.Unlock()
}

func (p *Platform) accountID() int64 {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.account.ID
}

// mentionsAccount is the pattern (^|[^A-Za-z0-9_-])@login(?![A-Za-z0-9_-]),
// ignoring case.
func (p *Platform) mentionsAccount(body string) bool {
	p.mu.Lock()
	login := p.account.Login
	p.mu.Unlock()
	return mentions(body, login)
}

func isHandleChar(b byte) bool {
	return b >= 'a' && b <= 'z' || b >= 'A' && b <= 'Z' || b >= '0' && b <= '9' || b == '_' || b == '-'
}

func mentions(body, login string) bool {
	hay, needle := strings.ToLower(body), "@"+strings.ToLower(login)
	for from := 0; ; {
		i := strings.Index(hay[from:], needle)
		if i < 0 {
			return false
		}
		i += from
		end := i + len(needle)
		if (i == 0 || !isHandleChar(body[i-1])) && (end >= len(body) || !isHandleChar(body[end])) {
			return true
		}
		from = i + 1
	}
}

// handleComment turns one comment into a message when it addresses the agent.
// It returns true when a mention was refused by the access policy.
func (p *Platform) handleComment(ctx context.Context, token, repo string, src *commentSource, c *comment, seenPrefix string) bool {
	messageID := fmt.Sprintf("%s:%d", src.kind, c.ID)
	seenKey := messageID
	if seenPrefix != "" {
		seenKey = seenPrefix + ":" + messageID
	}
	if p.seen.has(seenKey) {
		return false
	}
	p.markSeen(seenKey)

	if c.User.ID == p.accountID() {
		if src.kind == reviewComment.kind {
			p.rememberOwn(c.ID)
		}
		return false
	}
	if c.User.Type == "Bot" {
		return false
	}
	mentioned := p.mentionsAccount(c.Body)
	replied := !mentioned && src.kind == reviewComment.kind && p.isOwnReviewComment(ctx, token, repo, c.InReplyToID)
	// Chatter that does not address the agent is none of its business and
	// should not show up as a blocked sender either.
	if !mentioned && !replied {
		return false
	}
	number := src.number(c)
	if number == 0 {
		return false
	}
	isPR := src.kind == reviewComment.kind || pullPathPattern.MatchString(c.HTMLURL)
	chatID := fmt.Sprintf("%s#%d", repo, number)
	if src.kind == reviewComment.kind {
		thread := c.InReplyToID
		if thread == 0 {
			thread = c.ID
		}
		chatID = fmt.Sprintf("%s:%d", chatID, thread)
	}
	login := c.User.Login
	if login == "" {
		login = strconv.FormatInt(c.User.ID, 10)
	}
	kind := "issue"
	if isPR {
		kind = "pull request"
	}
	association := strings.ToUpper(c.AuthorAssociation)
	if association == "" {
		association = "NONE"
	}
	threadKind := "issue"
	if isPR {
		threadKind = "pull_request"
	}
	meta := map[string]any{"threadNumber": number, "threadKind": threadKind, "commentUrl": nil}
	if c.HTMLURL != "" {
		meta["commentUrl"] = c.HTMLURL
	}
	in := messaging.Inbound{
		Platform: "github", ChatID: chatID, MessageID: messageID, Sender: strconv.FormatInt(c.User.ID, 10),
		SenderName: "@" + login, SenderUsername: login, SenderTag: "@" + login, Content: c.Body, IsGroup: true,
		WasMentioned: mentioned, RepliedToAgent: replied, GroupID: repo, GroupName: repo,
		ChannelName: fmt.Sprintf("%s #%d", kind, number), RoleIDs: []string{association},
		Timestamp: c.CreatedAt, Metadata: meta,
	}
	if src.kind == reviewComment.kind && c.DiffHunk != "" {
		hunk := []rune(c.DiffHunk)
		if len(hunk) > 1500 {
			hunk = hunk[len(hunk)-1500:]
		}
		where := c.Path
		if c.Line != 0 {
			where += ":" + strconv.FormatInt(c.Line, 10)
		}
		in.ChannelContext = []messaging.ContextEntry{{Author: "review context", Content: where + "\n" + string(hunk)}}
	}
	access := messaging.AccessContext{
		Platform: "github", SenderID: in.Sender, ChatID: chatID, IsShared: true, GroupID: repo, ChannelID: chatID,
		RoleIDs: in.RoleIDs, WasMentioned: mentioned,
	}
	if !p.guard.Check(access, messaging.BlockedOptions{SenderName: in.SenderName, GroupLabel: repo, Meta: repo + " " + in.ChannelName}).Allowed {
		return true
	}
	p.ev.Message(in)
	return false
}

// --- Sending ----------------------------------------------------------------------

type thread struct {
	repo            string
	number          int64
	reviewCommentID int64
}

func parseThreadID(chatID string) (thread, bool) {
	m := threadIDPattern.FindStringSubmatch(strings.TrimSpace(chatID))
	if m == nil {
		return thread{}, false
	}
	t := thread{repo: m[1]}
	t.number, _ = strconv.ParseInt(m[2], 10, 64)
	if m[3] != "" {
		t.reviewCommentID, _ = strconv.ParseInt(m[3], 10, 64)
	}
	return t, true
}

// SendMessage keeps one comment per run and thread: the run's first message
// (usually its opening line) is posted, and every later one, ending with the
// answer, replaces it. A thread then shows one reply that grows into the result
// instead of a trail of status comments. The run is opts.RunID.
func (p *Platform) SendMessage(ctx context.Context, to, content string, opts messaging.SendOptions) (messaging.SendResult, error) {
	t, ok := parseThreadID(to)
	if !ok {
		return messaging.SendResult{}, fmt.Errorf("Not a GitHub thread: %s. Use owner/repo#number.", to)
	}
	token, err := p.token(ctx)
	if err != nil {
		return messaging.SendResult{}, err
	}
	if token == "" {
		return messaging.SendResult{}, errors.New("The GitHub Mentions account for this agent is not connected.")
	}
	commentsPath := "/repos/" + t.repo + "/issues/comments"
	if t.reviewCommentID != 0 {
		commentsPath = "/repos/" + t.repo + "/pulls/comments"
	}
	runKey := ""
	if opts.RunID != "" {
		runKey = opts.RunID + "|" + to
	}
	body := map[string]string{"body": content}
	if existing := p.runComment.get(runKey); existing != 0 {
		if err := p.call(ctx, token, request{method: http.MethodPatch, path: fmt.Sprintf("%s/%d", commentsPath, existing), body: body}, nil); err != nil {
			return messaging.SendResult{}, err
		}
		return messaging.SendResult{Success: true, MessageID: strconv.FormatInt(existing, 10)}, nil
	}
	createPath := fmt.Sprintf("/repos/%s/issues/%d/comments", t.repo, t.number)
	if t.reviewCommentID != 0 {
		createPath = fmt.Sprintf("/repos/%s/pulls/%d/comments/%d/replies", t.repo, t.number, t.reviewCommentID)
	}
	var created struct {
		ID int64 `json:"id"`
	}
	if err := p.call(ctx, token, request{method: http.MethodPost, path: createPath, body: body}, &created); err != nil {
		return messaging.SendResult{}, err
	}
	if t.reviewCommentID != 0 && created.ID != 0 {
		p.rememberOwn(created.ID)
	}
	if runKey != "" && created.ID != 0 {
		p.runComment.set(runKey, created.ID)
	}
	res := messaging.SendResult{Success: true}
	if created.ID != 0 {
		res.MessageID = strconv.FormatInt(created.ID, 10)
	}
	return res, nil
}

// MarkRead is GitHub's read receipt: an eyes reaction on the comment the agent
// picked up, shown as soon as the run starts.
func (p *Platform) MarkRead(ctx context.Context, chatID, messageID string) error {
	t, ok := parseThreadID(chatID)
	kind, id, _ := strings.Cut(messageID, ":")
	if !ok || id == "" {
		return nil
	}
	token, err := p.token(ctx)
	if err != nil || token == "" {
		return err
	}
	targets := map[string]string{
		"issue_comment":  fmt.Sprintf("/repos/%s/issues/comments/%s/reactions", t.repo, id),
		"review_comment": fmt.Sprintf("/repos/%s/pulls/comments/%s/reactions", t.repo, id),
		"issue_body":     fmt.Sprintf("/repos/%s/issues/%d/reactions", t.repo, t.number),
	}
	path, known := targets[kind]
	if !known {
		return nil
	}
	return p.call(ctx, token, request{method: http.MethodPost, path: path, body: map[string]string{"content": "eyes"}}, nil)
}

// --- Access targets ---------------------------------------------------------------

type targetsCache struct {
	watchKey string
	at       time.Time
	targets  []messaging.AccessTarget
}

// ListAccessTargets offers the repository roles and the account's repositories.
// The client loads every platform's catalog on each messaging refresh, so the
// answer is cached for five minutes.
func (p *Platform) ListAccessTargets(ctx context.Context) ([]messaging.AccessTarget, error) {
	if p.Status() != messaging.StatusConnected {
		return nil, nil
	}
	token, err := p.token(ctx)
	if err != nil || token == "" {
		return nil, err
	}
	watchKey := strings.Join(p.WatchedRepos(), "\n")
	p.mu.Lock()
	cached := p.targets
	p.mu.Unlock()
	if cached != nil && cached.watchKey == watchKey && time.Since(cached.at) < accessTargetsTTL {
		return cached.targets, nil
	}
	targets := make([]messaging.AccessTarget, 0, len(repoRoles))
	for _, role := range repoRoles {
		targets = append(targets, messaging.AccessTarget{
			Source: "live", Bucket: "sharedActorRules", Scope: "role", Value: role,
			Label: "Every " + strings.ToLower(role), Subtitle: "GitHub repository role",
		})
	}
	var repos []struct {
		FullName string `json:"full_name"`
		Private  bool   `json:"private"`
	}
	// A failure here only leaves the repository list out, as in Node.
	_ = p.call(ctx, token, request{path: "/user/repos", query: query{{"per_page", "100"}, {"sort", "pushed"}}}, &repos)
	for _, r := range repos {
		subtitle := "Public repository"
		if r.Private {
			subtitle = "Private repository"
		}
		targets = append(targets, messaging.AccessTarget{
			Source: "live", Bucket: "sharedSpaceRules", Scope: "group", Value: r.FullName, Label: r.FullName, Subtitle: subtitle,
		})
	}
	p.mu.Lock()
	p.targets = &targetsCache{watchKey: watchKey, at: time.Now(), targets: targets}
	p.mu.Unlock()
	return targets, nil
}
