package skills

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"errors"
	"github.com/NeoLabs-Systems/neoagent/internal/jsrules"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/workspace"
	"github.com/NeoLabs-Systems/neolabs-go/dbx"
	"github.com/NeoLabs-Systems/neolabs-go/httpx"
	"github.com/NeoLabs-Systems/neolabs-go/sessionx"
)

const (
	jsonBodyLimit  = 10 << 20
	libraryMaxSize = 32 * 1024 * 1024
)

// Auditor builds the capability audit of the skills.
type Auditor interface {
	AuditSkills() any
}

// Config wires the skills routes.
type Config struct {
	DB       *dbx.DB
	Runner   *Runner
	SkillsSh *SkillsSh
	Log      *slog.Logger
	// Audit serves GET /api/skills/audit/summary; without it the route answers 503.
	Audit Auditor
	// UserID returns the signed-in account of a request. Nil reads "userId"
	// from the session.
	UserID func(*http.Request) (int64, bool)
	Now    func() time.Time
}

// API serves the /api/skills routes.
type API struct {
	db       *dbx.DB
	runner   *Runner
	skillsSh *SkillsSh
	log      *slog.Logger
	audit    Auditor
	userID   func(*http.Request) (int64, bool)
	now      func() time.Time
}

// New builds the API.
func New(cfg Config) *API {
	a := &API{db: cfg.DB, runner: cfg.Runner, skillsSh: cfg.SkillsSh, log: cfg.Log, audit: cfg.Audit, userID: cfg.UserID, now: cfg.Now}
	if a.userID == nil {
		a.userID = sessionUserID
	}
	if a.now == nil {
		a.now = time.Now
	}
	return a
}

func sessionUserID(r *http.Request) (int64, bool) {
	sess := sessionx.FromContext(r.Context())
	if sess == nil {
		return 0, false
	}
	return sess.Int64("userId")
}

type handler func(w http.ResponseWriter, r *http.Request, userID int64)

func (a *API) authed(fn handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		userID, ok := a.userID(r)
		if !ok {
			httpx.Error(w, 401, "Unauthorized")
			return
		}
		fn(w, r, userID)
	})
}

// Routes registers the skills routes on mux.
func (a *API) Routes(mux *http.ServeMux) {
	mux.Handle("GET /api/skills/{$}", a.authed(a.list))
	mux.Handle("GET /api/skills", a.authed(a.list))
	mux.Handle("POST /api/skills/{$}", a.authed(a.create))
	mux.Handle("POST /api/skills", a.authed(a.create))
	mux.Handle("GET /api/skills/metrics/summary", a.authed(a.metrics))
	mux.Handle("GET /api/skills/audit/summary", a.authed(a.auditSummary))
	mux.Handle("GET /api/skills/skills-sh/search", a.authed(a.searchSkillsSh))
	mux.Handle("GET /api/skills/skills-sh/featured", a.authed(a.featuredSkillsSh))
	mux.Handle("POST /api/skills/skills-sh/install", a.authed(a.installSkillsSh))
	mux.Handle("GET /api/skills/builtin-libraries", a.authed(a.builtinLibraries))
	mux.Handle("POST /api/skills/builtin-libraries/{id}", a.authed(a.installBuiltin))
	mux.Handle("POST /api/skills/library", a.authed(a.uploadLibrary))
	mux.Handle("PUT /api/skills/library/{library}", a.authed(a.toggleLibrary))
	mux.Handle("DELETE /api/skills/library/{library}", a.authed(a.deleteLibrary))
	mux.Handle("GET /api/skills/{name}", a.authed(a.get))
	mux.Handle("PUT /api/skills/{name}", a.authed(a.update))
	mux.Handle("DELETE /api/skills/{name}", a.authed(a.remove))
}

// body is a JSON request body; a request without one has no members.
type body map[string]any

func readBody(r *http.Request) (body, error) {
	if !strings.Contains(strings.ToLower(r.Header.Get("Content-Type")), "json") {
		return body{}, nil
	}
	raw, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, jsonBodyLimit))
	if err != nil {
		return nil, errors.New("Request body too large")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] == '[' {
		return body{}, nil
	}
	var b body
	if err := json.Unmarshal(raw, &b); err != nil || b == nil {
		return nil, errors.New("Invalid JSON body")
	}
	return b, nil
}

// text is String(value || ”) of a member.
func (b body) text(key string) string { return jsrules.OrEmpty(b[key]) }

func queryText(r *http.Request, key string) string { return strings.Join(r.URL.Query()[key], ",") }

// fail answers a failure the way sendJsonError did: errors that carry a
// status below 500 show their message, everything else is a server error.
func (a *API) fail(w http.ResponseWriter, err error) {
	var status *StatusError
	if errors.As(err, &status) {
		httpx.Error(w, status.Status, status.Message)
		return
	}
	a.serverError(w, err)
}

func (a *API) serverError(w http.ResponseWriter, err error) {
	a.log.Error("skills route failed", "error", err)
	httpx.Error(w, 500, err.Error())
}

// refused answers a refusal with the status the route gives it.
func (a *API) refused(w http.ResponseWriter, err error, status int) {
	if refusal, ok := asRefusal(err); ok {
		httpx.Error(w, status, refusal.Message)
		return
	}
	a.serverError(w, err)
}

func serialize(s Skill) workspace.Obj {
	return workspace.Obj{
		{Key: "name", Value: s.Name},
		{Key: "description", Value: s.Description},
		{Key: "enabled", Value: s.Enabled()},
		{Key: "draft", Value: s.Metadata.Value("draft") == true},
		{Key: "category", Value: jsrules.OrDefault(s.Metadata.Value("category"), "general")},
		{Key: "trigger", Value: jsrules.OrDefault(s.Metadata.Value("trigger"), "")},
		{Key: "source", Value: jsrules.OrDefault(s.Metadata.Value("source"), "local")},
		{Key: "autoCreated", Value: s.Metadata.Value("auto_created") == true},
		{Key: "filePath", Value: s.FilePath},
		{Key: "skillsShId", Value: jsrules.OrDefault(s.Metadata.Value("skills_sh_id"), "")},
		{Key: "library", Value: jsrules.OrDefault(s.Metadata.Value("library"), "")},
		{Key: "readOnly", Value: s.ReadOnly},
		{Key: "ownerType", Value: jsrules.OrDefault(s.OwnerType, "global")},
	}
}

func (a *API) list(w http.ResponseWriter, r *http.Request, userID int64) {
	skills := a.runner.GetAll(userID)
	sort.SliceStable(skills, func(i, j int) bool {
		di, dj := skills[i].Metadata.Value("draft") == true, skills[j].Metadata.Value("draft") == true
		if di != dj {
			return di
		}
		return localeLess(skills[i].Name, skills[j].Name)
	})
	out := make([]workspace.Obj, len(skills))
	for i, s := range skills {
		out[i] = serialize(s)
	}
	httpx.WriteJSON(w, 200, out)
}

func (a *API) metrics(w http.ResponseWriter, r *http.Request, userID int64) {
	rows, err := a.db.R.QueryContext(r.Context(), `SELECT skill_name, invocation_count, success_count, failure_count,
		correction_count, total_tokens, last_used_at
		FROM skill_metrics WHERE user_id = ?
		ORDER BY invocation_count DESC, skill_name ASC`, userID)
	if err != nil {
		a.serverError(w, err)
		return
	}
	defer rows.Close()
	out := []workspace.Obj{}
	for rows.Next() {
		var name string
		var inv, ok, fail, corr, tokens sql.NullInt64
		var last sql.NullString
		if err := rows.Scan(&name, &inv, &ok, &fail, &corr, &tokens, &last); err != nil {
			a.serverError(w, err)
			return
		}
		recommendation := "keep"
		switch {
		case inv.Int64 >= 5 && float64(fail.Int64)/float64(inv.Int64) >= 0.4:
			recommendation = "improve_or_disable"
		case inv.Int64 >= 10 && ok.Int64 == 0:
			recommendation = "disable_or_delete"
		case inv.Int64 == 0:
			recommendation = "review_unused"
		}
		var rate, lastUsed any
		if inv.Int64 > 0 {
			rate = float64(ok.Int64) / float64(inv.Int64)
		}
		if last.Valid {
			lastUsed = last.String
		}
		out = append(out, workspace.Obj{
			{Key: "skillName", Value: name}, {Key: "invocationCount", Value: inv.Int64},
			{Key: "successCount", Value: ok.Int64}, {Key: "failureCount", Value: fail.Int64},
			{Key: "correctionCount", Value: corr.Int64}, {Key: "totalTokens", Value: tokens.Int64},
			{Key: "successRate", Value: rate}, {Key: "lastUsedAt", Value: lastUsed},
			{Key: "recommendation", Value: recommendation},
		})
	}
	if err := rows.Err(); err != nil {
		a.serverError(w, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (a *API) auditSummary(w http.ResponseWriter, r *http.Request, userID int64) {
	if a.audit == nil {
		httpx.Error(w, 503, "Capability audit is not available")
		return
	}
	httpx.WriteJSON(w, 200, a.audit.AuditSkills())
}

// withInstalledNames adds the name the user has each listed skill installed
// under, or an empty one.
func (a *API) withInstalledNames(userID int64, listings []Listing) []Listing {
	installed := InstalledNames(a.runner.GetAll(userID))
	for i := range listings {
		listings[i].InstalledName = installed[listings[i].ID]
	}
	return listings
}

func (a *API) searchSkillsSh(w http.ResponseWriter, r *http.Request, userID int64) {
	found, err := a.skillsSh.Search(r.Context(), queryText(r, "q"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, a.withInstalledNames(userID, found))
}

func (a *API) featuredSkillsSh(w http.ResponseWriter, r *http.Request, userID int64) {
	list := "popular"
	if v := queryText(r, "list"); v != "" {
		list = v
	}
	found, err := a.skillsSh.Featured(r.Context(), list)
	if err != nil {
		a.fail(w, err)
		return
	}
	// The cached list is shared, so the installed names go on a copy.
	httpx.WriteJSON(w, 200, a.withInstalledNames(userID, append([]Listing(nil), found...)))
}

func (a *API) installSkillsSh(w http.ResponseWriter, r *http.Request, userID int64) {
	b, err := readBody(r)
	if err != nil {
		httpx.Error(w, 400, err.Error())
		return
	}
	name := jsrules.OrDefault(b["name"], b["skillId"])
	result, err := a.skillsSh.Install(r.Context(), a.runner, userID, Ref{
		Source: b.text("source"), SkillID: b.text("skillId"), Name: jsrules.OrEmpty(name),
	})
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 201, workspace.Obj{
		{Key: "success", Value: true}, {Key: "name", Value: result.Name}, {Key: "fileCount", Value: result.FileCount},
	})
}

func (a *API) builtinLibraries(w http.ResponseWriter, r *http.Request, userID int64) {
	libraries, err := a.runner.BuiltinLibraries()
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, libraries)
}

func installStatus(result Installed) int {
	if len(result.Installed) > 0 {
		return 201
	}
	return 200
}

func (a *API) installBuiltin(w http.ResponseWriter, r *http.Request, userID int64) {
	result, err := a.runner.InstallBuiltin(r.Context(), userID, r.PathValue("id"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, installStatus(result), result)
}

// libraryUpload is the archive and the library name a multipart request carries.
type libraryUpload struct {
	archive  []byte
	filename string
	name     string
}

// readUpload reads the multipart body the way the Node upload handler did: one
// file in the "archive" field of at most 32 MB.
func readUpload(r *http.Request) (libraryUpload, *StatusError) {
	var up libraryUpload
	reader, err := r.MultipartReader()
	if err != nil {
		return up, nil
	}
	hasFile := false
	for {
		part, err := reader.NextPart()
		if err == io.EOF {
			return up, nil
		}
		if err != nil {
			return up, &StatusError{Status: 400, Message: "Malformed multipart body"}
		}
		if part.FileName() == "" {
			value, _ := io.ReadAll(io.LimitReader(part, 1<<20))
			if part.FormName() == "name" {
				up.name = string(value)
			}
			continue
		}
		if part.FormName() != "archive" {
			return up, &StatusError{Status: 400, Message: "Unexpected field"}
		}
		if hasFile {
			return up, &StatusError{Status: 400, Message: "Too many files"}
		}
		hasFile = true
		data, tooLarge := readFile(part)
		if tooLarge != nil {
			return up, tooLarge
		}
		up.archive, up.filename = data, part.FileName()
	}
}

func readFile(part *multipart.Part) ([]byte, *StatusError) {
	data, _ := io.ReadAll(io.LimitReader(part, libraryMaxSize+1))
	if len(data) > libraryMaxSize {
		return nil, &StatusError{Status: 413, Message: "The zip is larger than 32 MB"}
	}
	return data, nil
}

func (a *API) uploadLibrary(w http.ResponseWriter, r *http.Request, userID int64) {
	r.Body = http.MaxBytesReader(w, r.Body, libraryMaxSize+1<<20)
	up, failure := readUpload(r)
	if failure != nil {
		httpx.Error(w, failure.Status, failure.Message)
		return
	}
	if up.archive == nil {
		httpx.Error(w, 400, "No zip file was uploaded")
		return
	}
	name := up.name
	if name == "" {
		name = queryText(r, "name")
	}
	result, err := a.runner.InstallLibrary(r.Context(), userID, up.archive, up.filename, name)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, installStatus(result), result)
}

func (a *API) toggleLibrary(w http.ResponseWriter, r *http.Request, userID int64) {
	b, err := readBody(r)
	if err != nil {
		httpx.Error(w, 400, err.Error())
		return
	}
	enabled, isBool := b["enabled"].(bool)
	if !isBool {
		httpx.Error(w, 400, "enabled must be true or false")
		return
	}
	result, err := a.runner.SetLibraryEnabled(r.Context(), userID, r.PathValue("library"), enabled)
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, result)
}

func (a *API) deleteLibrary(w http.ResponseWriter, r *http.Request, userID int64) {
	result, err := a.runner.DeleteLibrary(r.Context(), userID, r.PathValue("library"))
	if err != nil {
		a.fail(w, err)
		return
	}
	httpx.WriteJSON(w, 200, result)
}

func (a *API) get(w http.ResponseWriter, r *http.Request, userID int64) {
	skill, ok := a.runner.GetSkill(r.PathValue("name"), userID)
	if !ok {
		httpx.Error(w, 404, "Skill not found")
		return
	}
	content, err := os.ReadFile(skill.FilePath)
	if err != nil {
		a.serverError(w, err)
		return
	}
	httpx.WriteJSON(w, 200, workspace.Obj{
		{Key: "name", Value: skill.Name}, {Key: "content", Value: string(content)},
		{Key: "meta", Value: skill.Metadata}, {Key: "enabled", Value: skill.Enabled()},
	})
}

// parseSubmitted reads the editor's document and vets its command template,
// answering 400 itself when it is not acceptable.
func parseSubmitted(w http.ResponseWriter, b body) (Document, bool) {
	doc, problem := ParseDocument(b.text("content"))
	if problem != "" {
		httpx.Error(w, 400, problem)
		return doc, false
	}
	if command := doc.Metadata.Value("command"); jsrules.Truthy(command) && !IsValidCommandTemplate(jsrules.String(command)) {
		httpx.Error(w, 400, "Skill command template contains invalid characters")
		return doc, false
	}
	return doc, true
}

func (a *API) create(w http.ResponseWriter, r *http.Request, userID int64) {
	b, err := readBody(r)
	if err != nil {
		httpx.Error(w, 400, err.Error())
		return
	}
	doc, ok := parseSubmitted(w, b)
	if !ok {
		return
	}
	filename := jsrules.OrDefault(b["filename"], doc.Name)
	saved, err := a.runner.Create(r.Context(), userID, jsrules.String(filename), doc.Description, doc.Instructions, doc.Metadata)
	if err != nil {
		a.refused(w, err, 400)
		return
	}
	httpx.WriteJSON(w, 201, saved)
}

func (a *API) update(w http.ResponseWriter, r *http.Request, userID int64) {
	b, err := readBody(r)
	if err != nil {
		httpx.Error(w, 400, err.Error())
		return
	}
	name := r.PathValue("name")
	if enabled, isBool := b["enabled"].(bool); isBool && !jsrules.Truthy(b["content"]) {
		saved, err := a.runner.SetEnabled(r.Context(), userID, name, enabled)
		if err != nil {
			a.refused(w, err, 404)
			return
		}
		httpx.WriteJSON(w, 200, saved)
		return
	}
	doc, ok := parseSubmitted(w, b)
	if !ok {
		return
	}
	current, _ := a.runner.GetSkill(name, userID)
	metadata := a.markLearningUserEdited(current.Metadata, doc.Metadata)
	saved, err := a.runner.Update(r.Context(), userID, name, Edit{
		Description: &doc.Description, Instructions: &doc.Instructions, Metadata: &metadata,
	})
	if err != nil {
		a.refused(w, err, 404)
		return
	}
	httpx.WriteJSON(w, 200, saved)
}

// markLearningUserEdited takes a learned skill out of automatic management once
// the user edits it by hand.
func (a *API) markLearningUserEdited(current, submitted Meta) Meta {
	learning, ok := current.Value("learning").(Meta)
	if !ok || learning.Value("managed") != true {
		return submitted
	}
	edited := learning.With("managed", false).With("userEditedAt", a.now().UTC().Format("2006-01-02T15:04:05.000Z"))
	return submitted.With("learning", edited)
}

func (a *API) remove(w http.ResponseWriter, r *http.Request, userID int64) {
	deleted, err := a.runner.Delete(r.Context(), userID, r.PathValue("name"))
	if err != nil {
		a.refused(w, err, 404)
		return
	}
	httpx.WriteJSON(w, 200, deleted)
}
