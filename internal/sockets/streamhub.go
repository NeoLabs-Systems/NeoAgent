package sockets

import (
	"log/slog"
	"math"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/realtime"
)

// MaxStreamFrameBytes is the largest JPEG the hub relays.
const MaxStreamFrameBytes = 8 * 1024 * 1024

// Broadcaster addresses sockets of the default namespace; *realtime.Hub is one.
type Broadcaster interface {
	To(rooms ...string) realtime.Broadcast
}

// Frame is one captured screen image of a remote-control stream.
type Frame struct {
	Platform string // "desktop", "android" or "browser"; empty means desktop
	JPEG     []byte
	Seq      uint32
	TS       uint32
	Flags    int
}

func normalizePlatform(platform string) string {
	p := strings.ToLower(strings.TrimFunc(platform, jsSpace))
	if p == "" {
		return "desktop"
	}
	return p
}

func streamKey(userID int64, platform, deviceID string) string {
	return strconv.FormatInt(userID, 10) + ":" + normalizePlatform(platform) + ":" + strings.TrimFunc(deviceID, jsSpace)
}

type streamStats struct {
	frameCount, bytesTotal int64
	lastFrameAt            int64
	windowFrames           int64
	windowBytes            int64
	windowStart            time.Time
	actualFps              float64
	bytesPerSec            int64
}

type activeStream struct {
	userID   int64
	deviceID string
	platform string
	fps      int
	quality  int
	stop     func(reason string) error
	timer    *time.Timer
}

// StreamHub fans the frames of a remote-control stream out to the sockets
// that subscribed to it, and keeps each stream's start/stop bookkeeping
// (services/streaming/stream-hub.js).
type StreamHub struct {
	out   Broadcaster
	grace time.Duration
	log   *slog.Logger
	now   func() time.Time

	mu          sync.Mutex
	subscribers map[string]map[string]struct{} // stream key -> socket ids
	stats       map[string]*streamStats
	active      map[string]*activeStream
	activeOrder []string
}

// NewStreamHub creates a hub. noSubscriberGrace is how long a started stream
// may run without any subscriber before it is stopped; 0 disables that.
func NewStreamHub(out Broadcaster, noSubscriberGrace time.Duration, log *slog.Logger) *StreamHub {
	return &StreamHub{
		out: out, grace: noSubscriberGrace, log: log, now: time.Now,
		subscribers: map[string]map[string]struct{}{},
		stats:       map[string]*streamStats{},
		active:      map[string]*activeStream{},
	}
}

func (s *StreamHub) newStats(now time.Time) *streamStats {
	return &streamStats{windowStart: now}
}

// HandleFrame relays a frame to the stream's subscribers. Frames nobody
// listens to, empty frames and oversized frames are dropped.
func (s *StreamHub) HandleFrame(userID int64, deviceID string, f Frame) {
	platform := normalizePlatform(f.Platform)
	key := streamKey(userID, platform, deviceID)
	s.mu.Lock()
	subs := s.subscribers[key]
	if len(subs) == 0 || len(f.JPEG) == 0 || len(f.JPEG) > MaxStreamFrameBytes {
		s.mu.Unlock()
		return
	}
	now := s.now()
	st := s.stats[key]
	if st == nil {
		st = s.newStats(now)
		s.stats[key] = st
	}
	st.frameCount++
	st.bytesTotal += int64(len(f.JPEG))
	st.lastFrameAt = now.UnixMilli()
	st.windowFrames++
	st.windowBytes += int64(len(f.JPEG))
	if windowMs := max(1, now.Sub(st.windowStart).Milliseconds()); windowMs >= 1000 {
		st.actualFps = math.Round(float64(st.windowFrames)*1000/float64(windowMs)*10) / 10
		st.bytesPerSec = int64(math.Round(float64(st.windowBytes) * 1000 / float64(windowMs)))
		st.windowStart, st.windowFrames, st.windowBytes = now, 0, 0
	}
	framePlatform := platform
	if a := s.active[key]; a != nil {
		framePlatform = a.platform
	}
	ids := make([]string, 0, len(subs))
	for id := range subs {
		ids = append(ids, id)
	}
	s.mu.Unlock()

	meta := map[string]any{
		"deviceId":   deviceID,
		"platform":   framePlatform,
		"seq":        f.Seq,
		"ts":         f.TS,
		"flags":      f.Flags,
		"capturedAt": now.UnixMilli(),
	}
	for _, id := range ids {
		_ = s.out.To(id).Volatile().Emit("stream:frame", meta, f.JPEG)
	}
}

// Subscribe adds a socket to a stream and returns the subscriber count.
func (s *StreamHub) Subscribe(userID int64, deviceID, platform, socketID string) int {
	key := streamKey(userID, platform, deviceID)
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.subscribers[key] == nil {
		s.subscribers[key] = map[string]struct{}{}
	}
	s.subscribers[key][socketID] = struct{}{}
	if a := s.active[key]; a != nil {
		a.platform = normalizePlatform(platform)
		if a.timer != nil {
			a.timer.Stop()
			a.timer = nil
		}
	}
	return len(s.subscribers[key])
}

// Unsubscribe removes a socket; the stream stops when it was the last one.
func (s *StreamHub) Unsubscribe(userID int64, platform, deviceID, socketID string) int {
	key := streamKey(userID, platform, deviceID)
	s.mu.Lock()
	subs := s.subscribers[key]
	if subs == nil {
		s.mu.Unlock()
		return 0
	}
	delete(subs, socketID)
	count := len(subs)
	if count == 0 {
		delete(s.subscribers, key)
	}
	s.mu.Unlock()
	if count == 0 {
		s.StopStream(userID, platform, deviceID, "no_subscribers")
	}
	return count
}

// UnsubscribeAll drops a disconnected socket from every stream and stops the
// streams that lost their last subscriber.
func (s *StreamHub) UnsubscribeAll(socketID string) {
	type stopped struct {
		userID             int64
		platform, deviceID string
	}
	var orphans []stopped
	s.mu.Lock()
	for key, subs := range s.subscribers {
		delete(subs, socketID)
		if len(subs) == 0 {
			delete(s.subscribers, key)
			if a := s.active[key]; a != nil {
				orphans = append(orphans, stopped{a.userID, a.platform, a.deviceID})
			}
		}
	}
	s.mu.Unlock()
	for _, o := range orphans {
		s.StopStream(o.userID, o.platform, o.deviceID, "socket_disconnected")
	}
}

// SubscriberCount is how many sockets watch the stream.
func (s *StreamHub) SubscriberCount(userID int64, platform, deviceID string) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.subscribers[streamKey(userID, platform, deviceID)])
}

// MarkStarted records a running stream. stop is called once when the stream
// ends, with the reason. A stream that nobody subscribes to within the grace
// period is stopped.
func (s *StreamHub) MarkStarted(userID int64, deviceID, platform string, fps, quality int, stop func(reason string) error) {
	platform = normalizePlatform(platform)
	key := streamKey(userID, platform, deviceID)
	a := &activeStream{userID: userID, deviceID: deviceID, platform: platform, fps: fps, quality: quality, stop: stop}
	s.mu.Lock()
	if _, exists := s.active[key]; !exists {
		s.activeOrder = append(s.activeOrder, key)
	}
	s.active[key] = a
	if s.grace > 0 && len(s.subscribers[key]) == 0 {
		a.timer = time.AfterFunc(s.grace, func() {
			s.StopStream(userID, platform, deviceID, "no_subscribers_initial")
		})
	}
	if s.stats[key] == nil {
		s.stats[key] = s.newStats(s.now())
	}
	s.mu.Unlock()
}

// StopStream ends a running stream and reports whether there was one.
func (s *StreamHub) StopStream(userID int64, platform, deviceID, reason string) bool {
	key := streamKey(userID, platform, deviceID)
	s.mu.Lock()
	a := s.active[key]
	if a == nil {
		s.mu.Unlock()
		return false
	}
	s.removeActiveLocked(key)
	s.mu.Unlock()
	if a.timer != nil {
		a.timer.Stop()
	}
	if a.stop != nil {
		if err := a.stop(reason); err != nil {
			s.log.Warn("[StreamHub] stream stop failed", "userId", a.userID, "deviceId", a.deviceID,
				"platform", a.platform, "reason", reason, "error", err)
		}
	}
	return true
}

func (s *StreamHub) removeActiveLocked(key string) {
	delete(s.active, key)
	for i, k := range s.activeOrder {
		if k == key {
			s.activeOrder = append(s.activeOrder[:i], s.activeOrder[i+1:]...)
			break
		}
	}
}

// StreamStatus is the JSON a status request answers with.
type StreamStatus struct {
	Streaming       bool    `json:"streaming"`
	Platform        string  `json:"platform"`
	DeviceID        string  `json:"deviceId"`
	FPS             *int    `json:"fps"`
	Quality         *int    `json:"quality"`
	SubscriberCount int     `json:"subscriberCount"`
	FrameCount      int64   `json:"frameCount"`
	BytesTotal      int64   `json:"bytesTotal"`
	LastFrameAt     *int64  `json:"lastFrameAt"`
	ActualFPS       float64 `json:"actualFps"`
	BytesPerSec     int64   `json:"bytesPerSec"`
}

func nonZero[T int | int64](v T) *T {
	if v == 0 {
		return nil
	}
	return &v
}

// Status describes one stream.
func (s *StreamHub) Status(userID int64, platform, deviceID string) StreamStatus {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.statusLocked(userID, platform, deviceID)
}

func (s *StreamHub) statusLocked(userID int64, platform, deviceID string) StreamStatus {
	key := streamKey(userID, platform, deviceID)
	a := s.active[key]
	st := s.stats[key]
	if st == nil {
		st = &streamStats{}
	}
	normalized := normalizePlatform(platform)
	out := StreamStatus{
		Streaming:       a != nil,
		Platform:        normalized,
		DeviceID:        deviceID,
		SubscriberCount: len(s.subscribers[streamKey(userID, normalized, deviceID)]),
		FrameCount:      st.frameCount,
		BytesTotal:      st.bytesTotal,
		LastFrameAt:     nonZero(st.lastFrameAt),
		ActualFPS:       st.actualFps,
		BytesPerSec:     st.bytesPerSec,
	}
	if a != nil {
		out.Platform, out.DeviceID = a.platform, a.deviceID
		out.FPS, out.Quality = nonZero(a.fps), nonZero(a.quality)
	}
	return out
}

// ListStatus describes the user's running streams, oldest first.
func (s *StreamHub) ListStatus(userID int64) []StreamStatus {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := []StreamStatus{}
	for _, key := range s.activeOrder {
		a := s.active[key]
		if a.userID != userID {
			continue
		}
		st := s.statusLocked(userID, a.platform, a.deviceID)
		if st.DeviceID != "" || st.Streaming || st.SubscriberCount > 0 {
			out = append(out, st)
		}
	}
	return out
}

// Shutdown stops every stream and forgets all subscribers.
func (s *StreamHub) Shutdown() {
	s.mu.Lock()
	streams := make([]*activeStream, 0, len(s.active))
	for _, a := range s.active {
		streams = append(streams, a)
	}
	s.active, s.activeOrder = map[string]*activeStream{}, nil
	s.subscribers = map[string]map[string]struct{}{}
	s.mu.Unlock()
	var wg sync.WaitGroup
	for _, a := range streams {
		if a.timer != nil {
			a.timer.Stop()
		}
		if a.stop != nil {
			wg.Add(1)
			go func() {
				defer wg.Done()
				_ = a.stop("shutdown")
			}()
		}
	}
	wg.Wait()
}
