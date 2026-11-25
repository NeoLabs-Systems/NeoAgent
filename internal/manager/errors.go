package manager

import (
	"errors"
	"fmt"
	"strings"

	"github.com/NeoLabs-Systems/neolabs-go/cli"
)

type guidance struct{ title, next string }

// What a failed command means to the person who ran it, by error code. The
// error's own message says what happened; this adds the headline and the
// next thing to try.
var errorGuidance = map[string]guidance{
	"SETUP_PORT_IN_USE":        {"NeoAgent couldn't start", "neoagent start"},
	"SETUP_PORT_UNAVAILABLE":   {"NeoAgent couldn't find a free address", "neoagent doctor"},
	"SETUP_SERVER_NOT_READY":   {"NeoAgent started but isn't answering", "neoagent logs"},
	"SETUP_RUNTIME_INCOMPLETE": {"Some of NeoAgent's files are missing", "neoagent repair"},
	"SETUP_RESUME_NOT_FOUND":   {"There is no setup to continue", "neoagent setup"},
	"SETUP_CANCELLED":          {"Setup cancelled — nothing was changed", ""},
	"SETUP_NOT_INSTALLED":      {"NeoAgent isn't installed yet", "neoagent"},
	"SETUP_PROFILE_REQUIRED":   {"Setup needs to know how to install", "neoagent setup --quick"},
	"UPDATE_ROLLED_BACK":       {"The update didn't work, so NeoAgent went back", "neoagent logs"},
	"UPDATE_ROLLBACK_FAILED":   {"The update didn't work and NeoAgent couldn't go back", "neoagent repair"},
}

// printError writes a failed command to stderr: a headline, what happened and
// what to try next.
func printError(u *cli.UI, err error, details bool) {
	write := func(line string) { fmt.Fprintln(u.Err, line) }
	if errors.Is(err, cli.ErrCancelled) {
		write("\n  " + u.Muted("Cancelled."))
		return
	}
	code := cli.CodeOf(err, "")
	g, ok := errorGuidance[code]
	if !ok {
		g = guidance{"Something went wrong", "neoagent doctor"}
	}
	write("")
	write("  " + u.Error("✕") + " " + u.Bold(g.title))
	if msg := err.Error(); msg != "" {
		write("    " + msg)
	}
	write("")
	if g.next != "" {
		hint := ""
		if g.next != "neoagent repair" {
			hint = "  ·  still stuck? neoagent repair tries the usual fixes"
		}
		write("  " + u.Muted("Try") + " " + u.Command(g.next) + u.Muted(hint))
	}
	if details {
		write("")
		label := "Technical details:"
		if code != "" {
			label = "Technical details (" + code + "):"
		}
		write("  " + u.Muted(label))
		var lines []string
		for _, l := range strings.Split(fmt.Sprintf("%+v", err), "\n") {
			lines = append(lines, "    "+l)
		}
		write(u.Muted(strings.Join(lines, "\n")))
	} else {
		write("  " + u.Muted("Technical details: add --details"))
	}
	write("")
}
