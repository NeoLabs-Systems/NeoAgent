package voice

import (
	"bytes"
	"context"
	"encoding/binary"
	"fmt"
	"io"
	"log/slog"
	"math"
	"os/exec"
	"sort"
	"strconv"
	"time"

	"github.com/NeoLabs-Systems/neolabs-go/livevoice"
)

// Inbound chat audio (WhatsApp PTT/audio, Discord voice messages/audio files)
// goes through one path: VAD first, then either dictation (the transcript is
// the user's message) or audio_context (the clip itself is the payload and no
// transcript is invented as a request).
const (
	IntentDictation    = "dictation"
	IntentAudioContext = "audio_context"
)

const (
	vadSampleRate       = 16000
	vadFrameSamples     = 320 // 20 ms
	vadFramesPerWindow  = 50  // 1 s
	vadMaxSeconds       = 180
	vadTimeout          = 8 * time.Second
	voiceNoteSTTTimeout = 20 * time.Second
	dictationMaxSeconds = 180

	// Energy thresholds are on normalized RMS (1.0 = full scale).
	silenceRMS     = 0.004
	minActiveRatio = 0.08
	// Speech alternates syllables and short pauses, so a large share of frames
	// in each second sit well below that second's mean energy. Music, hum and
	// steady noise stay close to their mean. Between the two bounds VAD is
	// uncertain.
	speechLowEnergyRatio    = 0.3
	nonSpeechLowEnergyRatio = 0.18
	// minVoicedRatio is the share of active frames that must carry a pitch in
	// the human voice range (70-400 Hz). It rejects beats, rumble and hiss that
	// pulse like syllables.
	minVoicedRatio  = 0.2
	voicedThreshold = 0.5
	pitchMinLag     = vadSampleRate / 2 / 400
	pitchMaxLag     = (vadSampleRate/2 + 69) / 70 // ceil(8000/70)
)

var voiceNoteSources = map[string]bool{"whatsapp_ptt": true, "discord_voice_message": true}

// SpeechActivity classifies 16 kHz mono s16le PCM.
type SpeechActivity struct {
	// Speech is true, false, or nil when uncertain.
	Speech         *bool
	DurationSec    float64
	ActiveRatio    float64
	VoicedRatio    float64
	LowEnergyRatio float64
}

func frameRMS(pcm []byte) []float64 {
	frames := len(pcm) / 2 / vadFrameSamples
	values := make([]float64, frames)
	for frame := range values {
		sum := 0.0
		start := frame * vadFrameSamples
		for i := 0; i < vadFrameSamples; i++ {
			sample := float64(int16(binary.LittleEndian.Uint16(pcm[(start+i)*2:]))) / 32768
			sum += sample * sample
		}
		values[frame] = math.Sqrt(sum / vadFrameSamples)
	}
	return values
}

// isVoicedFrame is the normalized autocorrelation peak over pitch lags, on
// every second sample to keep the cost small.
func isVoicedFrame(pcm []byte, frame int) bool {
	start := frame * vadFrameSamples
	length := vadFrameSamples / 2
	samples := make([]float64, length)
	energy := 0.0
	for i := 0; i < length; i++ {
		sample := float64(int16(binary.LittleEndian.Uint16(pcm[(start+i*2)*2:])))
		samples[i] = sample
		energy += sample * sample
	}
	if energy == 0 {
		return false
	}
	bestLag := 0
	best := math.Inf(-1)
	for lag := pitchMinLag; lag <= pitchMaxLag; lag++ {
		sum := 0.0
		for i := 0; i+lag < length; i++ {
			sum += samples[i] * samples[i+lag]
		}
		if sum > best {
			best, bestLag = sum, lag
		}
	}
	// A peak on the edge of the range means the period lies outside the voice
	// range (rumble below 70 Hz, hiss above 400 Hz).
	return best/energy >= voicedThreshold && bestLag > pitchMinLag && bestLag < pitchMaxLag
}

func percentile(values []float64, fraction float64) float64 {
	sorted := append([]float64(nil), values...)
	sort.Float64s(sorted)
	index := min(len(sorted)-1, int(math.Floor(float64(len(sorted))*fraction)))
	if index < 0 {
		return 0
	}
	return sorted[index]
}

// AnalyzeSpeechActivity classifies 16 kHz mono s16le PCM.
func AnalyzeSpeechActivity(pcm []byte) SpeechActivity {
	rms := frameRMS(pcm)
	durationSec := float64(len(pcm)) / 2 / vadSampleRate
	if len(rms) < vadFramesPerWindow/2 {
		no := false
		return SpeechActivity{Speech: &no, DurationSec: durationSec}
	}
	activeThreshold := math.Max(silenceRMS, percentile(rms, 0.1)*2.5)
	active, voiced := 0, 0
	for frame, value := range rms {
		if value <= activeThreshold {
			continue
		}
		active++
		if isVoicedFrame(pcm, frame) {
			voiced++
		}
	}
	activeRatio := float64(active) / float64(len(rms))
	voicedRatio := 0.0
	if active > 0 {
		voicedRatio = float64(voiced) / float64(active)
	}

	lowFrames, countedFrames := 0, 0
	for start := 0; start < len(rms); start += vadFramesPerWindow {
		window := rms[start:min(len(rms), start+vadFramesPerWindow)]
		mean := 0.0
		for _, value := range window {
			mean += value
		}
		mean /= float64(len(window))
		if mean <= silenceRMS {
			continue
		}
		for _, value := range window {
			if value < mean*0.5 {
				lowFrames++
			}
		}
		countedFrames += len(window)
	}
	lowEnergyRatio := 0.0
	if countedFrames > 0 {
		lowEnergyRatio = float64(lowFrames) / float64(countedFrames)
	}

	var speech *bool
	switch {
	case activeRatio < minActiveRatio || voicedRatio < minVoicedRatio || lowEnergyRatio < nonSpeechLowEnergyRatio:
		no := false
		speech = &no
	case lowEnergyRatio >= speechLowEnergyRatio:
		yes := true
		speech = &yes
	}
	return SpeechActivity{Speech: speech, DurationSec: durationSec, ActiveRatio: activeRatio, VoicedRatio: voicedRatio, LowEnergyRatio: lowEnergyRatio}
}

// VoiceNote is what the channel knows about an inbound clip, and what the
// pipeline adds to it.
type VoiceNote struct {
	Source      string
	DurationSec float64 // 0 when unknown
	Forwarded   bool
	// Intent is empty until the clip has been classified.
	Intent string
	// Speech is the VAD verdict once classified: true, false, nil (uncertain)
	// or "unavailable" (VAD could not run).
	Speech any
	// STTError says why a dictation could not be transcribed.
	STTError string
}

// ClassifyVoiceNote decides how a clip is used. A caption is the real request;
// the clip is what it is about.
func ClassifyVoiceNote(vad *SpeechActivity, source string, durationSec float64, caption string, forwarded bool) string {
	isVoiceNote := voiceNoteSources[source] && !forwarded
	switch {
	case livevoice.TrimJS(caption) != "":
		return IntentAudioContext
	case vad == nil:
		if isVoiceNote {
			return IntentDictation
		}
		return IntentAudioContext
	case vad.Speech == nil || !*vad.Speech:
		return IntentAudioContext
	case !isVoiceNote:
		return IntentAudioContext
	case durationSec > dictationMaxSeconds:
		return IntentAudioContext
	}
	return IntentDictation
}

// NoteProcessor runs the voice note pipeline.
type NoteProcessor struct {
	Transcriber *Transcriber
	Log         *slog.Logger
	// FFmpeg is the ffmpeg binary (FFMPEG_BIN); empty means "ffmpeg".
	FFmpeg string
}

func (p NoteProcessor) decodePCM(ctx context.Context, path string) ([]byte, error) {
	bin := p.FFmpeg
	if bin == "" {
		bin = "ffmpeg"
	}
	ctx, cancel := context.WithTimeout(ctx, vadTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin,
		"-hide_banner", "-loglevel", "error", "-nostdin",
		"-t", strconv.Itoa(vadMaxSeconds), "-i", path,
		"-vn", "-ac", "1", "-ar", strconv.Itoa(vadSampleRate), "-f", "s16le", "pipe:1")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	// vadMaxSeconds of 16 kHz mono 16-bit audio is all ffmpeg may produce.
	pcm, readErr := io.ReadAll(io.LimitReader(out, int64(vadMaxSeconds*vadSampleRate*2)+1))
	waitErr := cmd.Wait()
	if readErr != nil {
		return nil, readErr
	}
	if waitErr != nil {
		text := stderr.String()
		if len(text) > 200 {
			text = text[:200]
		}
		return nil, fmt.Errorf("ffmpeg failed: %v: %s", waitErr, livevoice.TrimJS(text))
	}
	return pcm, nil
}

// DetectSpeech classifies a clip on disk. It returns nil when VAD could not run
// (for example ffmpeg is not installed), and an error only when ctx ended.
func (p NoteProcessor) DetectSpeech(ctx context.Context, path string) (*SpeechActivity, error) {
	pcm, err := p.decodePCM(ctx, path)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		p.log().Warn("VAD unavailable", "error", err.Error())
		return nil, nil
	}
	activity := AnalyzeSpeechActivity(pcm)
	return &activity, nil
}

func (p NoteProcessor) log() *slog.Logger {
	if p.Log != nil {
		return p.Log
	}
	return slog.Default()
}

// Message is an inbound chat message that carries a voice note.
type Message struct {
	// Content is the caption, or the transcript once a dictation was transcribed.
	Content        string
	LocalMediaPath string
	VoiceNote      *VoiceNote
}

// IsPendingVoiceNote: a clip whose use has not been decided yet.
func IsPendingVoiceNote(msg Message) bool {
	return msg.VoiceNote != nil && msg.VoiceNote.Intent == "" && msg.LocalMediaPath != ""
}

// PrepareVoiceNote runs VAD, picks the intent and, only for dictation,
// transcribes the clip. The original audio always stays on the message.
func (p NoteProcessor) PrepareVoiceNote(ctx context.Context, userID int64, agentID string, msg Message) (Message, error) {
	if !IsPendingVoiceNote(msg) {
		return msg, nil
	}
	started := time.Now()
	caption := livevoice.TrimJS(msg.Content)
	vad, err := p.DetectSpeech(ctx, msg.LocalMediaPath)
	if err != nil {
		return msg, err
	}
	note := *msg.VoiceNote
	duration := note.DurationSec
	if duration == 0 && vad != nil {
		duration = vad.DurationSec
	}
	note.Intent = ClassifyVoiceNote(vad, note.Source, duration, caption, note.Forwarded)
	note.DurationSec = duration
	if vad != nil {
		if vad.Speech == nil {
			note.Speech = nil
		} else {
			note.Speech = *vad.Speech
		}
	} else {
		note.Speech = "unavailable"
	}

	content := caption
	if note.Intent == IntentDictation {
		transcript, err := p.Transcriber.TranscribeFile(ctx, userID, agentID, msg.LocalMediaPath, "", voiceNoteSTTTimeout)
		switch {
		case err != nil && ctx.Err() != nil:
			return msg, ctx.Err()
		case err != nil:
			note.STTError = err.Error()
		default:
			content = transcript
			if content == "" {
				note.STTError = "empty transcript"
			}
		}
	}
	p.log().Info("Voice note prepared", "source", note.Source, "speech", fmt.Sprint(note.Speech), "intent", note.Intent,
		"sttError", note.STTError, "tookMs", time.Since(started).Milliseconds())
	msg.Content, msg.VoiceNote = content, &note
	return msg, nil
}

// VoiceNoteHistoryText is what history keeps of a voice note. It keeps only the
// raw message, so the clip reference must live there for a follow-up ("that was
// audio, not a message") to reach the same file.
func VoiceNoteHistoryText(msg Message) string {
	text := livevoice.TrimJS(msg.Content)
	if msg.VoiceNote == nil || msg.VoiceNote.Intent == "" || msg.LocalMediaPath == "" {
		return text
	}
	kind := "audio clip"
	if msg.VoiceNote.Intent == IntentDictation {
		kind = "dictated voice note"
	}
	marker := "[" + kind + ": " + msg.LocalMediaPath + "]"
	if text == "" {
		return marker
	}
	return text + "\n" + marker
}
