// Package desktop connects user devices as computers: the NeoAgent desktop
// app (the "local" computer) dials in over a WebSocket and runs commands sent
// to it, and with TERMINAL_ENV=host this server registers itself the same way
// so one command path serves both.
package desktop

import (
	"encoding/binary"
	"encoding/json"
)

// WebSocketPath is where desktop companions connect.
const WebSocketPath = "/api/computer/local/ws"

// Commands a companion understands.
const (
	CmdGetStatus     = "getStatus"
	CmdCaptureFrame  = "captureFrame"
	CmdStreamStart   = "startStream"
	CmdStreamStop    = "stopStream"
	CmdObserve       = "observe"
	CmdClick         = "click"
	CmdDrag          = "drag"
	CmdScroll        = "scroll"
	CmdTypeText      = "typeText"
	CmdPressKey      = "pressKey"
	CmdLaunchApp     = "launchApp"
	CmdListDisplays  = "listDisplays"
	CmdSelectDisplay = "selectDisplay"
	CmdGetTree       = "getTree"
	CmdPauseControl  = "pauseControl"
	CmdExecute       = "executeCommand"
	CmdCancel        = "cancelCommand"
	CmdPing          = "ping"
	CmdMouseMove     = "mouseMove"
	CmdOpenURI       = "openUri"
	CmdListFiles     = "listFiles"
	CmdReadFile      = "readFile"
	CmdWriteFile     = "writeFile"
	CmdSearchFiles   = "searchFiles"
)

const (
	frameTypeVideo = 0x01
	// MaxFrameBytes bounds one WebSocket message from a companion.
	MaxFrameBytes = 8 * 1024 * 1024
)

// Error is a companion failure with its code and HTTP status.
type Error struct {
	Message string
	Code    string
	Status  int
	Details any
}

func (e *Error) Error() string { return e.Message }

// Unavailable is DesktopCompanionUnavailableError.
func Unavailable(message string) *Error {
	if message == "" {
		message = "Desktop companion is not connected."
	}
	return &Error{Message: message, Code: "DESKTOP_COMPANION_NOT_CONNECTED"}
}

func commandMessage(id, command string, payload any) []byte {
	raw, _ := json.Marshal(struct {
		Type    string `json:"type"`
		ID      string `json:"id"`
		Command string `json:"command"`
		Payload any    `json:"payload"`
	}{"command", id, command, payload})
	return raw
}

// message is any JSON message from a companion.
type message struct {
	Type    string          `json:"type"`
	ID      string          `json:"id"`
	OK      *bool           `json:"ok"`
	Payload json.RawMessage `json:"payload"`
	Error   any             `json:"error"`
	Code    any             `json:"code"`
	Event   string          `json:"event"`
	Device  json.RawMessage `json:"device"`
}

func parseMessage(data []byte) *message {
	if len(data) == 0 {
		return nil
	}
	var m message
	if json.Unmarshal(data, &m) != nil {
		return nil
	}
	return &m
}

// Frame is one JPEG frame of a desktop stream.
type Frame struct {
	Seq, TS uint32
	Flags   byte
	JPEG    []byte
}

// ParseFrame reads a binary stream frame: type, sequence, timestamp, flags, JPEG.
func ParseFrame(b []byte) *Frame {
	if len(b) <= 10 || len(b) > MaxFrameBytes || b[0] != frameTypeVideo {
		return nil
	}
	jpeg := b[10:]
	if len(jpeg) < 4 || jpeg[0] != 0xff || jpeg[1] != 0xd8 || jpeg[len(jpeg)-2] != 0xff || jpeg[len(jpeg)-1] != 0xd9 {
		return nil
	}
	return &Frame{Seq: binary.BigEndian.Uint32(b[1:5]), TS: binary.BigEndian.Uint32(b[5:9]), Flags: b[9], JPEG: jpeg}
}
