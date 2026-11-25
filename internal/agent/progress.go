package agent

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai"
	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/runledger"
	"github.com/NeoLabs-Systems/neolabs-go/llm"
)

const (
	progressTick = 15 * time.Second
	// Each update waits twice as long as the one before, up to this many
	// doublings: a long task reports early and then less often, as people do.
	maxGapDoublings = 4
)

type progressDelta struct {
	Completed []string `json:"completed_since_last_update"`
	Evidence  string   `json:"evidence"`
	Through   int      `json:"through"`
}

func (d progressDelta) real() bool { return len(d.Completed) > 0 || d.Evidence != "" }

type liveness struct {
	Status       string `json:"status"`
	Phase        string `json:"phase"`
	RunningTools int    `json:"runningTools"`
	SilentForMs  int64  `json:"silentForMs"`
	SinceStartMs int64  `json:"sinceAcceptedMs"`
}

// progressBroker owns a run's heartbeat on every channel, so a run that spends
// minutes inside one tool or model call still reports in. Liveness comes only
// from observed activity; narration may only phrase a delta the runtime already
// saw, and there is no canned status text.
type progressBroker struct {
	e *Engine
	r *Run

	maxSilence, firstUpdate, repeatUpdate time.Duration
	collect                               func(since int) progressDelta

	mu              sync.Mutex
	lastUpdateAt    time.Time
	lastNarration   time.Time
	lastHash        string
	lastText        string
	updatesSent     int
	reportedThrough int
	lastActivityAt  time.Time
	acceptedAt      time.Time
	phase           string
	runningTools    int
	stop            chan struct{}
	ticking         bool
}

func (e *Engine) broker(r *Run) *progressBroker {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.broker
}

func newProgressBroker(e *Engine, r *Run, collect func(int) progressDelta) *progressBroker {
	interactive := r.LatencyPriority == "interactive"
	maxSilence := time.Duration(r.Options.MaxSilenceSeconds) * time.Second
	if maxSilence <= 0 {
		maxSilence = 90 * time.Second
		if interactive {
			maxSilence = 45 * time.Second
		}
	}
	first, repeat := 25*time.Second, 90*time.Second
	if interactive {
		first, repeat = 15*time.Second, 45*time.Second
	}
	now := time.Now()
	return &progressBroker{e: e, r: r, maxSilence: maxSilence, firstUpdate: first, repeatUpdate: repeat, collect: collect,
		lastActivityAt: now, acceptedAt: now, phase: "idle"}
}

func (b *progressBroker) noteActivity(kind string) {
	b.mu.Lock()
	b.lastActivityAt, b.phase = time.Now(), kind
	b.mu.Unlock()
}

func (b *progressBroker) noteToolStarted() {
	b.mu.Lock()
	b.runningTools++
	b.lastActivityAt, b.phase = time.Now(), "tool_started"
	b.mu.Unlock()
}

func (b *progressBroker) noteToolFinished() {
	b.mu.Lock()
	b.runningTools = max(0, b.runningTools-1)
	b.lastActivityAt, b.phase = time.Now(), "tool_completed"
	b.mu.Unlock()
}

func (b *progressBroker) markAccepted() {
	b.mu.Lock()
	b.acceptedAt = time.Now()
	b.lastActivityAt = b.acceptedAt
	b.mu.Unlock()
}

func (b *progressBroker) liveness() liveness {
	b.mu.Lock()
	defer b.mu.Unlock()
	now := time.Now()
	l := liveness{Phase: b.phase, RunningTools: b.runningTools, SilentForMs: now.Sub(b.lastActivityAt).Milliseconds(), SinceStartMs: now.Sub(b.acceptedAt).Milliseconds()}
	switch silent := now.Sub(b.lastActivityAt); {
	case b.runningTools > 0:
		l.Status = "working"
	case silent > b.maxSilence:
		l.Status = "stalled"
	case silent > b.maxSilence/2:
		l.Status = "quiet"
	default:
		l.Status = "alive"
	}
	return l
}

// suppressed: a run that already delivered, was cancelled, decided to stay
// silent or asked the user something must never emit another visible update.
func (b *progressBroker) suppressed() bool {
	r := b.r
	if _, ok := b.e.RunInfo(r.ID); !ok || r.Aborted() || r.Status() == "paused" || !r.allowsProgress() {
		return true
	}
	d := r.Delivery
	d.Lock()
	defer d.Unlock()
	return d.FinalDelivered || d.NoResponse || d.AwaitingReply != nil || d.LastWordSent
}

func hashProgress(d progressDelta) string {
	sum := sha256.Sum256([]byte(dyn.Stringify(map[string]any{"completed": d.Completed})))
	return hex.EncodeToString(sum[:])
}

func (b *progressBroker) maybePublish(ctx context.Context) {
	if b.collect == nil || b.suppressed() {
		return
	}
	b.mu.Lock()
	delta := b.collect(b.reportedThrough)
	b.mu.Unlock()
	live := b.liveness()
	now := time.Now()
	hash := hashProgress(delta)
	visible := time.Time{}
	if t, err := time.Parse("2006-01-02T15:04:05.000Z", b.r.LastUserVisibleAt()); err == nil {
		visible = t
	}
	b.mu.Lock()
	last := b.lastUpdateAt
	for _, t := range []time.Time{visible, b.lastNarration} {
		if t.After(last) {
			last = t
		}
	}
	firstDue := last.IsZero() && now.Sub(b.acceptedAt) >= b.firstUpdate
	gap := time.Duration(float64(b.repeatUpdate) * math.Pow(2, float64(min(max(b.updatesSent-1, 0), maxGapDoublings))))
	repeatDue := !last.IsZero() && now.Sub(last) >= gap
	if !firstDue && !repeatDue {
		b.mu.Unlock()
		return
	}
	grounded := repeatDue && live.RunningTools > 0
	if hash == b.lastHash && !grounded {
		b.mu.Unlock()
		return
	}
	// Nothing finished since the last update: no model call, and the clock keeps
	// running from the last time there was something to say.
	if !delta.real() {
		b.mu.Unlock()
		return
	}
	b.lastNarration = now
	if delta.Through > b.reportedThrough {
		b.reportedThrough = delta.Through
	}
	previous := b.lastText
	sent := b.updatesSent
	b.mu.Unlock()

	text := ""
	// A model turn still streaming has produced nothing to report.
	if !(live.Phase == "model_started" && live.RunningTools == 0 && delta.Evidence == "") {
		text = b.e.narrateProgress(ctx, b.r, delta, live, previous)
	}
	if text == "" {
		b.mu.Lock()
		b.lastHash = hash
		b.mu.Unlock()
		return
	}
	if b.suppressed() {
		return
	}
	metadata := b.r.progressMetadata()
	metadata["progressHash"] = hash
	metadata["liveness"] = live
	result, err := b.e.RequestProgressDelivery(ctx, b.r.ID, b.r.DeliveryScopeID, deliveryChannel(b.r.TriggerSource), b.r.recipient(),
		runledger.KindProgress, fmt.Sprintf("%s:%d", hash, sent), text, metadata)
	if err == nil && result.OK {
		b.mu.Lock()
		b.lastUpdateAt, b.lastHash, b.lastText = now, hash, text
		b.updatesSent++
		b.mu.Unlock()
	}
}

func (b *progressBroker) start() {
	b.mu.Lock()
	if b.stop != nil {
		b.mu.Unlock()
		return
	}
	b.stop = make(chan struct{})
	stop := b.stop
	b.mu.Unlock()
	go func() {
		ticker := time.NewTicker(progressTick)
		defer ticker.Stop()
		for {
			select {
			case <-stop:
				return
			case <-ticker.C:
				b.mu.Lock()
				busy := b.ticking
				b.ticking = true
				b.mu.Unlock()
				if !busy {
					b.maybePublish(b.r.Context())
					b.mu.Lock()
					b.ticking = false
					b.mu.Unlock()
				}
			}
		}
	}()
}

func (b *progressBroker) halt() {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.stop != nil {
		close(b.stop)
		b.stop = nil
	}
}

var lineBreaks = strings.NewReplacer("\r\n", "\n", "\r", "\n")

// narrateProgress phrases an observed progress delta. The run's own system
// prompt supplies voice and formatting; the delta is the only permitted source
// of facts, and an empty answer means "no useful update".
func (e *Engine) narrateProgress(ctx context.Context, r *Run, delta progressDelta, live liveness, previous string) string {
	model := r.Model()
	if model.Provider == nil {
		return ""
	}
	r.mu.Lock()
	system := r.systemPrompt
	r.mu.Unlock()
	var messages []llm.Message
	if system != "" {
		messages = append(messages, llm.Message{Role: "system", Content: system})
	}
	instruction := ai.BuildProgressUpdatePrompt()
	if live.Status == "stalled" {
		instruction += " No verified activity has been recorded for the stall threshold. State that plainly if it matters; do not reassure or imply activity beyond the evidence."
	}
	request := r.Request
	if len([]rune(request)) > 320 {
		request = string([]rune(request)[:320])
	}
	parts := []string{"Original request: " + request}
	if previous != "" {
		p := previous
		if len([]rune(p)) > 400 {
			p = string([]rune(p)[:400])
		}
		parts = append(parts, "Your previous update, which the user already has:\n"+p)
	}
	if delta.Evidence != "" {
		parts = append(parts, "Tool activity since then (newest last) — describe ONLY this:\n"+delta.Evidence)
	}
	messages = append(messages, llm.Message{Role: "system", Content: instruction}, llm.Message{Role: "user", Content: strings.Join(parts, "\n\n")})
	res, err := model.Provider.Chat(ctx, messages, nil, llm.Options{Model: model.Model, MaxTokens: narrationMaxTokens, ReasoningEffort: e.reasoningEffort(r.Options),
		Extra: map[string]any{"phase": "progress_narration"}})
	if err != nil {
		return ""
	}
	text := ai.SanitizeModelOutput(strings.TrimSpace(res.Content), ai.SanitizeOptions{Model: model.Model})
	platform := r.MessagingPlatform
	if e.deps.Messaging != nil && e.deps.Messaging.Normalize(platform, text) == "" {
		return ""
	}
	var lines []string
	for _, line := range strings.Split(lineBreaks.Replace(text), "\n") {
		if line = strings.TrimSpace(line); line != "" {
			lines = append(lines, line)
		}
	}
	out := strings.Join(lines, " ")
	if len([]rune(out)) > 400 {
		out = string([]rune(out)[:400])
	}
	return out
}
