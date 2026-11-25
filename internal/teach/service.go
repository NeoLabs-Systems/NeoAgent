package teach

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/apperr"
)

const (
	maxEvents      = 1000
	maxScreenshots = 40
	sessionTTL     = 30 * time.Minute
	maxFrameChars  = 6 * 1024 * 1024
)

// Runtime is the agent's computer as Teach Mode uses it.
type Runtime interface {
	// AcquireControl marks the computer as in use by the session; ReleaseControl frees it.
	AcquireControl(userKey, purpose, sessionID string)
	ReleaseControl(userKey, sessionID string)
	// RequestComputer calls the guest agent. body is JSON-encoded when not nil.
	RequestComputer(ctx context.Context, userKey, method, path string, body any, opts RequestOptions) (map[string]any, error)
	// Browser returns the browser of the user's computer.
	Browser(ctx context.Context, userKey string) (Browser, error)
}

// RequestOptions bounds a guest request.
type RequestOptions struct {
	Timeout          time.Duration
	MaxResponseBytes int64
}

// Browser is the page automation Teach Mode reads from.
type Browser interface {
	PageInfo(ctx context.Context) (any, error)
	// ExtractContent returns the text of the page (keys text, content or result).
	ExtractContent(ctx context.Context, maxChars int) (map[string]any, error)
	Evaluate(ctx context.Context, script string) (any, error)
}

// DemoEvidence is what the learner gets to write a skill from.
type DemoEvidence struct {
	Recorder         string          `json:"recorder"`
	Timeline         []TimelineEntry `json:"timeline"`
	ActiveWindow     *string         `json:"activeWindow"`
	Browser          *BrowserContext `json:"browser"`
	VisualFrames     []VisualFrame   `json:"visualFrames"`
	SourceEventCount int             `json:"sourceEventCount"`
}

// VisualFrame is the description of a screenshot.
type VisualFrame struct {
	Type        string `json:"type"`
	AtMs        int64  `json:"atMs"`
	Description string `json:"description"`
}

// Demonstration is the learner's input.
type Demonstration struct {
	UserKey  string
	AgentID  string
	Goal     string
	Evidence DemoEvidence
}

// Learned is the learner's answer.
type Learned struct {
	Success     bool
	Ignored     bool
	Name        string
	Description string
	Error       string
}

// Learner turns a demonstration into a skill.
type Learner interface {
	LearnFromComputerDemonstration(ctx context.Context, d Demonstration) (Learned, error)
}

// ImageAnalyzer describes a screenshot.
type ImageAnalyzer interface {
	Describe(ctx context.Context, userKey, agentID, imageBase64, mimeType, question string) (string, error)
}

// Emitter sends realtime events to a room.
type Emitter interface {
	EmitToRoom(room, event string, payload any)
}

// Config wires the service.
type Config struct {
	// Dir holds the encrypted session files; it is emptied on Start.
	Dir     string
	Runtime Runtime
	Learner Learner
	Images  ImageAnalyzer
	Emitter Emitter
	Log     *slog.Logger
}

type session struct {
	mu             sync.Mutex
	id             string
	userKey        string
	agentID        string
	goal           string
	status         string
	startedAt      time.Time
	updatedAt      time.Time
	events         []*Event
	screenshots    int
	lastScreenshot time.Time
	key            []byte
	ctx            context.Context
	cancel         context.CancelCauseFunc
	lastFileState  map[string]string
	lastShellAt    float64
	filePath       string
}

// Service records and synthesizes Teach Mode sessions.
type Service struct {
	cfg      Config
	mu       sync.Mutex
	sessions map[string]*session
	stop     chan struct{}
	wg       sync.WaitGroup
}

// New builds the service. Call Start before use.
func New(cfg Config) *Service {
	return &Service{cfg: cfg, sessions: map[string]*session{}}
}

// Start empties the session directory (recordings never survive a restart) and
// starts expiring idle sessions.
func (s *Service) Start(ctx context.Context) error {
	if err := os.MkdirAll(s.cfg.Dir, 0o700); err != nil {
		return err
	}
	if err := os.Chmod(s.cfg.Dir, 0o700); err != nil {
		return err
	}
	entries, err := os.ReadDir(s.cfg.Dir)
	if err != nil {
		return err
	}
	for _, e := range entries {
		if err := os.RemoveAll(filepath.Join(s.cfg.Dir, e.Name())); err != nil {
			return err
		}
	}
	s.stop = make(chan struct{})
	s.wg.Add(1)
	go func() {
		defer s.wg.Done()
		ticker := time.NewTicker(time.Minute)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				s.expire(time.Now())
			case <-s.stop:
				return
			case <-ctx.Done():
				return
			}
		}
	}()
	return nil
}

// Stop ends the timer and purges every session.
func (s *Service) Stop() {
	if s.stop != nil {
		close(s.stop)
		s.wg.Wait()
		s.stop = nil
	}
	s.mu.Lock()
	var all []*session
	for _, sess := range s.sessions {
		all = append(all, sess)
	}
	s.mu.Unlock()
	for _, sess := range all {
		sess.cancel(errors.New("Teach Mode service stopped."))
		s.purge(sess)
	}
}

// Summary is the public state of a session.
type Summary struct {
	ID              string          `json:"id"`
	Goal            string          `json:"goal"`
	Status          string          `json:"status"`
	StartedAt       string          `json:"startedAt"`
	EventCount      int             `json:"eventCount"`
	ScreenshotCount int             `json:"screenshotCount"`
	Timeline        []TimelineBrief `json:"timeline"`
}

// TimelineBrief is the short form of an event shown while recording.
type TimelineBrief struct {
	Sequence int    `json:"sequence"`
	Type     string `json:"type"`
	AtMs     int64  `json:"atMs"`
}

type statusPayload struct {
	Summary
	Skill string `json:"skill,omitempty"`
	Error string `json:"error,omitempty"`
}

func newID() string {
	var b [16]byte
	_, _ = rand.Read(b[:])
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func failure(status int, message, code string) error { return apperr.New(status, message, code) }

func isoTime(t time.Time) string { return t.UTC().Format("2006-01-02T15:04:05.000Z") }

func (s *Service) log() *slog.Logger {
	if s.cfg.Log != nil {
		return s.cfg.Log
	}
	return slog.Default()
}

// StartInput is what the client sends to begin recording.
type StartInput struct {
	Goal    string
	AgentID string
}

// StartSession begins recording a demonstration on the user's computer.
func (s *Service) StartSession(ctx context.Context, userKey string, in StartInput) (Summary, error) {
	key := normalize(userKey, 1<<30)
	goal := normalize(in.Goal, 1000)
	if key == "" || goal == "" {
		return Summary{}, failure(400, "A short Teach Mode goal is required.", "")
	}
	if s.active(key) != nil {
		return Summary{}, failure(409, "Teach Mode is already recording for this computer.", "TEACH_ALREADY_RECORDING")
	}
	id := newID()
	s.cfg.Runtime.AcquireControl(key, "teach", id)
	secret := make([]byte, 32)
	if _, err := rand.Read(secret); err != nil {
		s.cfg.Runtime.ReleaseControl(key, id)
		return Summary{}, err
	}
	sctx, cancel := context.WithCancelCause(context.Background())
	sess := &session{
		id: id, userKey: key, agentID: normalize(in.AgentID, 128), goal: goal, status: "recording",
		startedAt: time.Now(), updatedAt: time.Now(), key: secret, ctx: sctx, cancel: cancel,
		lastFileState: map[string]string{}, filePath: filepath.Join(s.cfg.Dir, id+".teach"),
	}
	s.mu.Lock()
	s.sessions[id] = sess
	s.mu.Unlock()
	if err := s.persist(sess); err != nil {
		s.purge(sess)
		return Summary{}, err
	}

	var shot string
	var shotErr error
	done := make(chan struct{})
	go func() {
		defer close(done)
		shot, shotErr = s.captureScreenshot(ctx, sess)
	}()
	sc := s.captureContext(ctx, sess)
	<-done
	if shotErr != nil {
		s.log().Warn("Unable to capture the initial Teach Mode state.", "error", shotErr)
	} else {
		sess.mu.Lock()
		sess.events = append(sess.events, &Event{Sequence: 1, Type: "initial-state", Screenshot: shot, Context: s.compact(sess, sc, true)})
		if shot != "" {
			sess.screenshots = 1
		}
		sess.mu.Unlock()
		if err := s.persist(sess); err != nil {
			s.log().Warn("Unable to store the Teach Mode state.", "error", err)
		}
	}
	s.emit(sess, "", "")
	return s.summary(sess), nil
}

// active returns the user's recording or synthesizing session, if any.
func (s *Service) active(userKey string) *session {
	key := normalize(userKey, 1<<30)
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, sess := range s.sessions {
		sess.mu.Lock()
		active := sess.userKey == key && (sess.status == "recording" || sess.status == "synthesizing")
		sess.mu.Unlock()
		if active {
			return sess
		}
	}
	return nil
}

// ActiveSummary reports the user's recording or synthesizing session, if any.
func (s *Service) ActiveSummary(userKey string) (Summary, bool) {
	sess := s.active(userKey)
	if sess == nil {
		return Summary{}, false
	}
	return s.summary(sess), true
}

func (s *Service) summary(sess *session) Summary {
	sess.mu.Lock()
	defer sess.mu.Unlock()
	return s.summaryLocked(sess)
}

func (s *Service) summaryLocked(sess *session) Summary {
	tail := sess.events[max(0, len(sess.events)-12):]
	brief := make([]TimelineBrief, 0, len(tail))
	for _, e := range tail {
		brief = append(brief, TimelineBrief{e.Sequence, e.Type, e.AtMs})
	}
	return Summary{
		ID: sess.id, Goal: sess.goal, Status: sess.status, StartedAt: isoTime(sess.startedAt),
		EventCount: len(sess.events), ScreenshotCount: sess.screenshots, Timeline: brief,
	}
}

func (s *Service) emit(sess *session, skill, errText string) {
	if s.cfg.Emitter == nil {
		return
	}
	sess.mu.Lock()
	payload := statusPayload{Summary: s.summaryLocked(sess), Skill: skill, Error: errText}
	sess.mu.Unlock()
	s.cfg.Emitter.EmitToRoom("user:"+sess.userKey, "teach:status", payload)
}

func (s *Service) persist(sess *session) error {
	sess.mu.Lock()
	doc := map[string]any{
		"id": sess.id, "userId": sess.userKey, "agentId": nilIfEmpty(sess.agentID), "goal": sess.goal,
		"status": sess.status, "startedAt": sess.startedAt.UnixMilli(), "updatedAt": sess.updatedAt.UnixMilli(),
		"events": sess.events,
	}
	content, err := encryptJSON(sess.key, doc)
	sess.mu.Unlock()
	if err != nil {
		return err
	}
	tmp := fmt.Sprintf("%s.%d.tmp", sess.filePath, os.Getpid())
	if err := os.WriteFile(tmp, content, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, sess.filePath)
}

func nilIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func (s *Service) purge(sess *session) {
	s.cfg.Runtime.ReleaseControl(sess.userKey, sess.id)
	_ = os.Remove(sess.filePath)
	sess.mu.Lock()
	sess.events = nil
	clear(sess.key)
	sess.mu.Unlock()
	s.mu.Lock()
	delete(s.sessions, sess.id)
	s.mu.Unlock()
}

func (s *Service) expire(now time.Time) {
	s.mu.Lock()
	var stale []*session
	for _, sess := range s.sessions {
		sess.mu.Lock()
		if now.Sub(sess.updatedAt) > sessionTTL {
			sess.status = "expired"
			stale = append(stale, sess)
		}
		sess.mu.Unlock()
	}
	s.mu.Unlock()
	for _, sess := range stale {
		sess.cancel(errors.New("Teach Mode recording expired."))
		s.emit(sess, "", "")
		s.purge(sess)
	}
}

// Cancel abandons a session of the user; false when there is none.
func (s *Service) Cancel(userKey, sessionID string) bool {
	s.mu.Lock()
	sess := s.sessions[sessionID]
	s.mu.Unlock()
	if sess == nil || sess.userKey != normalize(userKey, 1<<30) {
		return false
	}
	sess.mu.Lock()
	sess.status = "cancelled"
	sess.mu.Unlock()
	sess.cancel(errors.New("Teach Mode was cancelled."))
	s.emit(sess, "", "")
	s.purge(sess)
	return true
}

// RecordResult answers a recorded event.
type RecordResult struct {
	Recording  bool `json:"recording"`
	Truncated  bool `json:"truncated,omitempty"`
	Ignored    bool `json:"ignored,omitempty"`
	EventCount *int `json:"eventCount,omitempty"`
}

var recordable = map[string]bool{"pointer": true, "key": true, "text-input": true, "navigation": true, "window": true, "command": true, "file": true}

// finite reads event[key] as JS Number() would and reports whether it is a
// finite number (an absent member is NaN, null is 0).
func finite(event map[string]any, key string) (float64, bool) {
	v, present := event[key]
	if !present {
		return 0, false
	}
	switch x := v.(type) {
	case nil:
		return 0, true
	case float64:
		return x, !math.IsNaN(x) && !math.IsInf(x, 0)
	case bool:
		if x {
			return 1, true
		}
		return 0, true
	case string:
		var f float64
		if _, err := fmt.Sscanf(x, "%g", &f); err == nil && !math.IsInf(f, 0) {
			return f, true
		}
		if x == "" {
			return 0, true
		}
	}
	return 0, false
}

func roundHalfUp(f float64) int { return int(math.Floor(f + 0.5)) }

// Record adds a client event to the user's recording.
func (s *Service) Record(ctx context.Context, userKey string, event map[string]any) (RecordResult, error) {
	sess := s.active(userKey)
	if sess == nil {
		return RecordResult{}, nil
	}
	sess.mu.Lock()
	recording := sess.status == "recording"
	sess.mu.Unlock()
	if !recording {
		return RecordResult{}, nil
	}
	s.cfg.Runtime.AcquireControl(sess.userKey, "teach", sess.id)
	count := func() *int {
		sess.mu.Lock()
		defer sess.mu.Unlock()
		n := len(sess.events)
		return &n
	}
	sess.mu.Lock()
	full := len(sess.events) >= maxEvents
	sess.mu.Unlock()
	if full {
		return RecordResult{Recording: true, Truncated: true, EventCount: count()}, nil
	}
	typ := normalize(event["type"], 64)
	if !recordable[typ] {
		return RecordResult{Recording: true, Ignored: true, EventCount: count()}, nil
	}

	sess.mu.Lock()
	e := &Event{Sequence: len(sess.events) + 1, Type: typ, AtMs: time.Since(sess.startedAt).Milliseconds()}
	switch typ {
	case "pointer":
		pos := &Position{}
		if x, ok := finite(event, "x"); ok {
			v := roundHalfUp(x)
			pos.X = &v
		}
		if y, ok := finite(event, "y"); ok {
			v := roundHalfUp(y)
			pos.Y = &v
		}
		button := 0.0
		if b, ok := finite(event, "button"); ok {
			button = b
		}
		e.Position, e.Button = pos, &button
	case "key":
		e.Key = normalize(event["key"], 64)
		mods, _ := event["modifiers"].(map[string]any)
		e.Modifiers = &Modifiers{Alt: mods["alt"] == true, Ctrl: mods["ctrl"] == true, Meta: mods["meta"] == true, Shift: mods["shift"] == true}
	case "text-input":
		e.Value = "[runtime input]"
	default:
		e.Detail = normalize(event["detail"], 500)
	}
	sess.events = append(sess.events, e)
	sess.updatedAt = time.Now()
	wantShot := (typ == "pointer" || typ == "key") && sess.screenshots < maxScreenshots && time.Since(sess.lastScreenshot) >= time.Second
	if wantShot {
		sess.lastScreenshot = time.Now()
	}
	sess.mu.Unlock()

	if wantShot {
		select {
		case <-time.After(250 * time.Millisecond):
		case <-ctx.Done():
		}
		if shot, err := s.captureScreenshot(ctx, sess); err != nil {
			s.log().Warn("Unable to capture a Teach Mode frame.", "error", err)
		} else if shot != "" {
			sess.mu.Lock()
			e.Screenshot = shot
			sess.screenshots++
			sess.mu.Unlock()
		}
	}
	if typ != "text-input" {
		sc := s.captureContext(ctx, sess)
		sess.mu.Lock()
		e.Context = s.compact(sess, sc, false)
		sess.mu.Unlock()
	}
	if err := s.persist(sess); err != nil {
		return RecordResult{}, err
	}
	s.emit(sess, "", "")
	return RecordResult{Recording: true, EventCount: count()}, nil
}

// StopResult is what a finished demonstration produced.
type StopResult struct {
	Success     bool   `json:"success"`
	Skill       string `json:"skill"`
	Description string `json:"description"`
}

// StopSession ends the recording and learns a skill from it.
func (s *Service) StopSession(ctx context.Context, userKey, sessionID string) (StopResult, error) {
	s.mu.Lock()
	sess := s.sessions[sessionID]
	s.mu.Unlock()
	if sess == nil || sess.userKey != normalize(userKey, 1<<30) {
		return StopResult{}, failure(404, "Teach Mode session was not found.", "")
	}
	sess.mu.Lock()
	if sess.status != "recording" {
		sess.mu.Unlock()
		return StopResult{}, failure(409, "Teach Mode session is not recording.", "")
	}
	sess.status = "synthesizing"
	sess.updatedAt = time.Now()
	sess.mu.Unlock()
	s.cfg.Runtime.AcquireControl(sess.userKey, "teach", sess.id)
	_ = s.persist(sess)
	s.emit(sess, "", "")
	defer s.purge(sess)

	result, err := s.synthesize(ctx, sess)
	if err != nil {
		sess.mu.Lock()
		keep := sess.status == "cancelled" || sess.status == "expired"
		if !keep {
			sess.status = "error"
		}
		sess.mu.Unlock()
		if !keep {
			s.emit(sess, "", normalize(err.Error(), 500))
		}
		return StopResult{}, err
	}
	sess.mu.Lock()
	sess.status = "completed"
	sess.mu.Unlock()
	s.emit(sess, result.Skill, "")
	return result, nil
}

func (s *Service) synthesize(ctx context.Context, sess *session) (StopResult, error) {
	sc := s.captureContext(ctx, sess)
	final, shotErr := s.captureScreenshot(ctx, sess)
	if shotErr != nil {
		return StopResult{}, shotErr
	}
	sess.mu.Lock()
	sess.events = append(sess.events, &Event{
		Sequence: len(sess.events) + 1, Type: "final-state", AtMs: time.Since(sess.startedAt).Milliseconds(),
		Screenshot: final, Context: s.compact(sess, sc, false),
	})
	if final != "" {
		sess.screenshots++
	}
	sess.mu.Unlock()
	_ = s.persist(sess)

	frames, err := s.describeScreenshots(sess)
	if err != nil {
		return StopResult{}, err
	}
	if err := context.Cause(sess.ctx); err != nil {
		return StopResult{}, err
	}
	sess.mu.Lock()
	evidence := DemoEvidence{
		Recorder: "semantic-v1", Timeline: BuildTimeline(sess.events), ActiveWindow: sc.ActiveWindow,
		Browser: sc.Browser, VisualFrames: frames, SourceEventCount: len(sess.events),
	}
	sess.mu.Unlock()
	if evidence.VisualFrames == nil {
		evidence.VisualFrames = []VisualFrame{}
	}
	learned, err := s.cfg.Learner.LearnFromComputerDemonstration(sess.ctx, Demonstration{
		UserKey: sess.userKey, AgentID: sess.agentID, Goal: sess.goal, Evidence: evidence,
	})
	if err != nil {
		return StopResult{}, err
	}
	if !learned.Success {
		message := learned.Error
		if message == "" {
			message = "The demonstration did not produce a reusable skill."
		}
		if learned.Ignored {
			return StopResult{}, failure(422, message, "TEACH_SKILL_NOT_CREATED")
		}
		return StopResult{}, errors.New(message)
	}
	return StopResult{Success: true, Skill: learned.Name, Description: learned.Description}, nil
}

func (s *Service) describeScreenshots(sess *session) ([]VisualFrame, error) {
	sess.mu.Lock()
	var frames []*Event
	for _, e := range sess.events {
		if e.Screenshot != "" {
			frames = append(frames, e)
		}
	}
	sess.mu.Unlock()
	if len(frames) == 0 || s.cfg.Images == nil {
		return nil, nil
	}
	var indexes []int
	for _, i := range []int{0, (len(frames) - 1) / 2, len(frames) - 1} {
		if len(indexes) == 0 || !contains(indexes, i) {
			indexes = append(indexes, i)
		}
	}
	var out []VisualFrame
	for _, i := range indexes {
		frame := frames[i]
		description, err := s.cfg.Images.Describe(sess.ctx, sess.userKey, sess.agentID, frame.Screenshot, "image/png", frameQuestion)
		if err != nil {
			if cause := context.Cause(sess.ctx); cause != nil {
				return nil, cause
			}
			s.log().Warn("Teach Mode visual frame analysis was unavailable.", "error", err)
			break
		}
		if d := normalize(description, 2000); d != "" {
			out = append(out, VisualFrame{Type: frame.Type, AtMs: frame.AtMs, Description: d})
		}
	}
	return out, nil
}

func contains(list []int, v int) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

const frameQuestion = "Describe this Linux desktop workflow frame for adaptive skill synthesis. " +
	"Identify the visible application, semantic UI state, relevant controls, and evidence of progress or success. " +
	"Do not infer or transcribe passwords, credentials, clipboard contents, or other secrets."
