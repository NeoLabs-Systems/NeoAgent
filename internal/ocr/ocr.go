// Package ocr reads text from images with the system tesseract binary (the
// Node server used tesseract.js). The result has tesseract.js's shape: the
// text and the mean word confidence.
package ocr

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// Languages is what tesseract.js was asked for in Node: English.
const Languages = "eng"

// Recognize runs tesseract on an image file.
func Recognize(ctx context.Context, binary, imagePath string) (text string, confidence float64, err error) {
	if binary == "" {
		binary = "tesseract"
	}
	dir, err := os.MkdirTemp("", "neoagent-ocr-")
	if err != nil {
		return "", 0, err
	}
	defer os.RemoveAll(dir)
	base := filepath.Join(dir, "out")
	cmd := exec.CommandContext(ctx, binary, imagePath, base, "-l", Languages, "txt", "tsv")
	var stderr strings.Builder
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if ctx.Err() != nil {
			return "", 0, ctx.Err()
		}
		var notFound *exec.Error
		if errors.As(err, &notFound) {
			return "", 0, errors.New("OCR needs the tesseract program, which is not installed on this server.")
		}
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = err.Error()
		}
		return "", 0, fmt.Errorf("OCR failed: %s", msg)
	}
	raw, err := os.ReadFile(base + ".txt")
	if err != nil {
		return "", 0, err
	}
	tsv, err := os.ReadFile(base + ".tsv")
	if err != nil {
		return "", 0, err
	}
	return string(raw), MeanConfidence(string(tsv)), nil
}

// MeanConfidence is the mean confidence of the recognised words in
// tesseract's TSV output, 0 when there are none.
func MeanConfidence(tsv string) float64 {
	sum, n := 0.0, 0
	for i, line := range strings.Split(tsv, "\n") {
		cols := strings.Split(line, "\t")
		if i == 0 || len(cols) < 12 || cols[0] != "5" || strings.TrimSpace(cols[11]) == "" {
			continue
		}
		conf, err := strconv.ParseFloat(cols[10], 64)
		if err != nil || conf < 0 {
			continue
		}
		sum += conf
		n++
	}
	if n == 0 {
		return 0
	}
	return sum / float64(n)
}
