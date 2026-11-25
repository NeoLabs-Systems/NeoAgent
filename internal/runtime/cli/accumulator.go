// Package cli runs shell commands for the computer runtime: the executor the
// guest agent serves, the bounded output capture, and the in-process worker
// pool that replaces one forked Node process per shell.
package cli

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	maxArtifactBytes   = 16 * 1024 * 1024
	stdoutPreviewBytes = 50_000
	stderrPreviewBytes = 10_000
)

// boundedPreview keeps a head and a tail of a stream, so a long output shows
// how it started and how it ended.
type boundedPreview struct {
	limit     int
	headLimit int
	tailLimit int
	head      []byte
	tail      []byte
	full      []byte
	total     int
}

func newBoundedPreview(limit int) *boundedPreview {
	head := max(1, limit*2/10)
	return &boundedPreview{limit: limit, headLimit: head, tailLimit: max(1, limit-head)}
}

func (p *boundedPreview) append(data []byte) {
	p.total += len(data)
	if room := p.limit - len(p.full); room > 0 {
		p.full = append(p.full, data[:min(len(data), room)]...)
	}
	if room := p.headLimit - len(p.head); room > 0 {
		p.head = append(p.head, data[:min(len(data), room)]...)
	}
	p.tail = append(p.tail, data...)
	if len(p.tail) > p.tailLimit {
		p.tail = append([]byte(nil), p.tail[len(p.tail)-p.tailLimit:]...)
	}
}

func (p *boundedPreview) snapshot() string {
	if p.total <= p.limit {
		return strings.TrimSpace(string(p.full))
	}
	parts := []string{
		strings.TrimRight(string(p.head), " \t\r\n"),
		fmt.Sprintf("...[truncated preview, %d bytes total]", p.total),
		strings.TrimLeft(string(p.tail), " \t\r\n"),
	}
	var kept []string
	for _, part := range parts {
		if part != "" {
			kept = append(kept, part)
		}
	}
	return strings.Join(kept, "\n")
}

// outputResult is what finalize reports about a command's output.
type outputResult struct {
	Stdout       string
	Stderr       string
	StdoutBytes  int
	StderrBytes  int
	Truncated    bool
	FilePath     string
	FileByteSize int64
	FileComplete bool
}

// Accumulator captures a command's output: bounded previews of stdout and
// stderr for the model, and a bounded log file with the whole story (head and
// tail kept) for when the preview was not enough.
type Accumulator struct {
	maxBytes int
	stdout   *boundedPreview
	stderr   *boundedPreview

	artifactTail   []byte
	tailLimit      int
	headLimit      int
	fileBytes      int
	totalBytes     int
	lastStream     string
	outputDir      string
	outputFilePath string
	file           *os.File
	finalized      bool
}

// AccumulatorOptions override the default preview sizes.
type AccumulatorOptions struct {
	StderrPreviewBytes int
}

// NewAccumulator creates the output directory and log file.
func NewAccumulator(o AccumulatorOptions) (*Accumulator, error) {
	dir, err := os.MkdirTemp("", "neoagent-command-output-")
	if err != nil {
		return nil, err
	}
	path := filepath.Join(dir, "command.log")
	file, err := os.Create(path)
	if err != nil {
		os.RemoveAll(dir)
		return nil, err
	}
	stderrLimit := stderrPreviewBytes
	if o.StderrPreviewBytes > 0 {
		stderrLimit = o.StderrPreviewBytes
	}
	return &Accumulator{
		maxBytes:       maxArtifactBytes,
		headLimit:      maxArtifactBytes / 2,
		tailLimit:      maxArtifactBytes / 2,
		stdout:         newBoundedPreview(stdoutPreviewBytes),
		stderr:         newBoundedPreview(stderrLimit),
		outputDir:      dir,
		outputFilePath: path,
		file:           file,
	}, nil
}

// Append records a chunk from "stdout" or "stderr".
func (a *Accumulator) Append(stream string, data []byte) {
	if stream == "stderr" {
		a.stderr.append(data)
	} else {
		a.stdout.append(data)
	}
	var marker []byte
	if a.lastStream != stream {
		prefix := ""
		if a.totalBytes > 0 {
			prefix = "\n"
		}
		marker = []byte(fmt.Sprintf("%s[%s]\n", prefix, stream))
	}
	a.lastStream = stream
	a.appendArtifact(append(marker, data...))
}

func (a *Accumulator) appendArtifact(buf []byte) {
	a.totalBytes += len(buf)
	if a.fileBytes < a.maxBytes && a.file != nil {
		writable := buf[:min(len(buf), a.maxBytes-a.fileBytes)]
		if len(writable) > 0 {
			if n, _ := a.file.Write(writable); n > 0 {
				a.fileBytes += n
			}
		}
	}
	a.artifactTail = append(a.artifactTail, buf...)
	if len(a.artifactTail) > a.tailLimit {
		a.artifactTail = append([]byte(nil), a.artifactTail[len(a.artifactTail)-a.tailLimit:]...)
	}
}

// Finalize closes the log. When nothing was truncated the log is deleted and
// the result carries no file; otherwise the file is kept (bounded: head, a
// marker, tail) and described.
func (a *Accumulator) Finalize() (outputResult, error) {
	if a.finalized {
		return outputResult{}, fmt.Errorf("Command output was already finalized.")
	}
	a.finalized = true
	_ = a.file.Close()
	a.file = nil
	truncated := a.stdout.total > a.stdout.limit || a.stderr.total > a.stderr.limit
	result := outputResult{
		Stdout:       a.stdout.snapshot(),
		Stderr:       a.stderr.snapshot(),
		StdoutBytes:  a.stdout.total,
		StderrBytes:  a.stderr.total,
		Truncated:    truncated,
		FileComplete: true,
	}
	if !truncated {
		a.Discard()
		return result, nil
	}
	complete := a.totalBytes <= a.maxBytes
	if !complete {
		if err := a.boundFile(); err != nil {
			return result, err
		}
	}
	info, err := os.Stat(a.outputFilePath)
	if err != nil {
		return result, err
	}
	result.FilePath = a.outputFilePath
	result.FileByteSize = info.Size()
	result.FileComplete = complete
	return result, nil
}

// boundFile rewrites an over-long log as head + marker + tail.
func (a *Accumulator) boundFile() error {
	marker := []byte(fmt.Sprintf("\n...[artifact bounded, %d bytes total]...\n", a.totalBytes))
	headBytes := min(a.headLimit, max(0, a.maxBytes-len(marker)))
	source, err := os.Open(a.outputFilePath)
	if err != nil {
		return err
	}
	head := make([]byte, headBytes)
	n, _ := source.ReadAt(head, 0)
	source.Close()
	tailBytes := max(0, a.maxBytes-n-len(marker))
	tail := a.artifactTail
	if len(tail) > tailBytes {
		tail = tail[len(tail)-tailBytes:]
	}
	return os.WriteFile(a.outputFilePath, bytes.Join([][]byte{head[:n], marker, tail}, nil), 0o600)
}

// Discard closes and removes the log and its directory.
func (a *Accumulator) Discard() {
	if a.file != nil {
		_ = a.file.Close()
		a.file = nil
	}
	_ = os.RemoveAll(a.outputDir)
}
