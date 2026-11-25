package gitproxy

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"strconv"
	"strings"
)

const (
	maxCommandSectionBytes = 1024 * 1024
	sidebandChunkBytes     = 995
)

// PushCommand is one ref update of a receive-pack request.
type PushCommand struct {
	OldID, NewID, Ref string
}

type parsedPush struct {
	complete           bool
	commands           []PushCommand
	clientCapabilities []string
}

func isNullID(id string) bool { return strings.Trim(id, "0") == "" }

// parsePushCommands reads the pkt-line framed command section at the head of a
// receive-pack request. complete is false while the flush packet is missing.
func parsePushCommands(buf []byte) (parsedPush, error) {
	var out parsedPush
	offset := 0
	for offset+4 <= len(buf) {
		length, err := strconv.ParseUint(string(buf[offset:offset+4]), 16, 32)
		if err != nil || (length > 0 && length < 4) {
			return parsedPush{}, errors.New("Malformed receive-pack request.")
		}
		if length == 0 {
			out.complete = true
			return out, nil
		}
		if offset+int(length) > len(buf) {
			break
		}
		line := strings.TrimSuffix(string(buf[offset+4:offset+int(length)]), "\n")
		offset += int(length)
		if nul := strings.IndexByte(line, 0); nul != -1 {
			out.clientCapabilities = strings.Split(line[nul+1:], " ")
			line = line[:nul]
		}
		if strings.HasPrefix(line, "shallow ") {
			continue
		}
		parts := strings.Split(line, " ")
		if len(parts) < 3 || parts[0] == "" || parts[1] == "" || parts[2] == "" {
			return parsedPush{}, errors.New("Malformed receive-pack command.")
		}
		out.commands = append(out.commands, PushCommand{OldID: parts[0], NewID: parts[1], Ref: parts[2]})
	}
	return parsedPush{}, nil
}

// pushHead is the command section of a push and the bytes read to get it.
type pushHead struct {
	head               []byte
	commands           []PushCommand
	clientCapabilities []string
}

// readPushCommands reads just far enough to see the whole command section.
// head holds everything read, so the caller can replay it upstream and then
// stream the pack that follows.
func readPushCommands(body io.Reader) (pushHead, error) {
	var buffered bytes.Buffer
	chunk := make([]byte, 32*1024)
	for {
		n, err := body.Read(chunk)
		buffered.Write(chunk[:n])
		if n > 0 {
			parsed, perr := parsePushCommands(buffered.Bytes())
			if perr != nil {
				return pushHead{}, perr
			}
			if parsed.complete {
				return pushHead{head: buffered.Bytes(), commands: parsed.commands, clientCapabilities: parsed.clientCapabilities}, nil
			}
			if buffered.Len() > maxCommandSectionBytes {
				return pushHead{}, errors.New("Push command list is too large.")
			}
		}
		if err == io.EOF {
			return pushHead{}, errors.New("Push request ended before its command list.")
		}
		if err != nil {
			return pushHead{}, err
		}
	}
}

// refusal is why a push is not forwarded.
type refusal struct{ ref, reason string }

func pktLine(payload []byte) []byte {
	return append([]byte(fmt.Sprintf("%04x", len(payload)+4)), payload...)
}

// buildPushRefusalReport answers a refused push as a normal report-status, so
// git prints "! [remote rejected] <ref> (<reason>)".
func buildPushRefusalReport(commands []PushCommand, clientCapabilities []string, r refusal) []byte {
	var report []byte
	report = append(report, pktLine([]byte("unpack ok\n"))...)
	for _, c := range commands {
		if c.Ref == r.ref {
			report = append(report, pktLine([]byte("ng "+c.Ref+" "+r.reason+"\n"))...)
		} else {
			report = append(report, pktLine([]byte("ng "+c.Ref+" not pushed because "+r.ref+" was refused\n"))...)
		}
	}
	report = append(report, "0000"...)

	sideband := false
	for _, c := range clientCapabilities {
		if c == "side-band-64k" || c == "side-band" {
			sideband = true
		}
	}
	if !sideband {
		return report
	}
	var packets []byte
	for off := 0; off < len(report); off += sidebandChunkBytes {
		end := min(off+sidebandChunkBytes, len(report))
		packets = append(packets, pktLine(append([]byte{1}, report[off:end]...))...)
	}
	return append(packets, "0000"...)
}
