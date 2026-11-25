package memory

import (
	"os"
	"regexp"
	"strings"
)

var (
	modulesPath   = regexp.MustCompile("(?:^|[\\s'\"(\\[])\\S*?[\\\\/]node_modules(?:[\\\\/]\\S*)?")
	modulesPrefix = regexp.MustCompile("^[\\s'\"(\\[]")
	unixPath      = regexp.MustCompile("(^|[\\s'\"(\\[])/(?:[^\\s'\"\\])]+/){2,}[^\\s'\"\\])]+")
	windowsPath   = regexp.MustCompile("(^|[\\s'\"(\\[])(?:[A-Za-z]:[\\\\/](?:[^\\s'\"\\])]+[\\\\/])+[^\\s'\"\\])]+|[\\\\/]{2}[^\\s'\"\\\\/\\])]+[\\\\/][^\\s'\"\\])]+(?:[\\\\/][^\\s'\"\\])]+)+)")
)

// sanitizeError is the message of an error with file system paths removed, as
// the Node routes show it to the client.
func sanitizeError(err error) string {
	const fallback = "An unexpected error occurred"
	if err == nil {
		return fallback
	}
	msg := err.Error()
	if msg == "" || msg == "[object Object]" {
		msg = fallback
	}
	if home, herr := os.UserHomeDir(); herr == nil && home != "" {
		msg = strings.ReplaceAll(msg, home, "~")
	}
	msg = modulesPath.ReplaceAllStringFunc(msg, func(match string) string {
		return modulesPrefix.FindString(match) + "[module]"
	})
	msg = unixPath.ReplaceAllString(msg, "${1}[path]")
	msg = windowsPath.ReplaceAllString(msg, "${1}[path]")
	if msg = strings.TrimSpace(msg); msg != "" {
		return msg
	}
	return fallback
}
