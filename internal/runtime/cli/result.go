package cli

import (
	"bytes"
	"encoding/json"
)

// Result describes how a command ended. It marshals to the same JSON object,
// with the same key order, as the Node executor produced; the variants differ
// in which keys they carry.
type Result struct {
	ExitCode *int
	outputResult
	Killed      bool
	TimedOut    bool
	Aborted     bool
	Signal      string
	DurationMs  int64
	PID         *int
	Command     string
	Cwd         string
	Interactive bool
	// Error is set when the command could not run at all.
	Error string

	variant resultVariant
}

type resultVariant int

const (
	variantNormal resultVariant = iota
	variantStartFailed
	variantAborted
)

type field struct {
	key   string
	value any
}

// MarshalJSON writes the keys in the order Node's object literals had.
func (r Result) MarshalJSON() ([]byte, error) {
	var exit any
	if r.ExitCode != nil {
		exit = *r.ExitCode
	}
	var pid any
	if r.PID != nil {
		pid = *r.PID
	}
	var signal any
	if r.Signal != "" {
		signal = r.Signal
	}
	fields := []field{{"exitCode", exit}, {"stdout", r.Stdout}, {"stderr", r.Stderr}, {"stdoutBytes", r.StdoutBytes}, {"stderrBytes", r.StderrBytes}, {"truncated", r.Truncated}}
	switch r.variant {
	case variantNormal:
		var path any
		if r.FilePath != "" {
			path = r.FilePath
		}
		fields = append(fields, field{"outputFilePath", path}, field{"outputFileByteSize", r.FileByteSize}, field{"outputFileComplete", r.FileComplete},
			field{"killed", r.Killed}, field{"timedOut", r.TimedOut}, field{"aborted", r.Aborted})
	case variantAborted:
		fields = append(fields, field{"killed", r.Killed}, field{"timedOut", r.TimedOut}, field{"aborted", r.Aborted})
	case variantStartFailed:
		fields = append(fields, field{"killed", r.Killed}, field{"timedOut", r.TimedOut})
	}
	if r.variant != variantStartFailed || !r.Interactive {
		fields = append(fields, field{"signal", signal})
	}
	fields = append(fields, field{"durationMs", r.DurationMs})
	if r.variant != variantStartFailed || r.PID != nil {
		fields = append(fields, field{"pid", pid})
	}
	fields = append(fields, field{"command", r.Command}, field{"cwd", r.Cwd})
	if r.Interactive {
		fields = append(fields, field{"interactive", true})
	}
	if r.variant == variantStartFailed {
		fields = append(fields, field{"error", r.Error})
	}
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, f := range fields {
		if i > 0 {
			buf.WriteByte(',')
		}
		key, _ := json.Marshal(f.key)
		buf.Write(key)
		buf.WriteByte(':')
		enc := json.NewEncoder(&buf)
		enc.SetEscapeHTML(false)
		if err := enc.Encode(f.value); err != nil {
			return nil, err
		}
		buf.Truncate(buf.Len() - 1) // Encode appends a newline
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}
