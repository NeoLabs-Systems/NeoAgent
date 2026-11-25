package agentimport

import "golang.org/x/text/unicode/norm"

// nfkd is String.prototype.normalize('NFKD').
func nfkd(s string) string { return norm.NFKD.String(s) }
