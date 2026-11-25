// Package gitproxy is the proxy that guest computers reach GitHub through.
//
// Guests never hold a GitHub token. Every command an agent runs gets a
// short-lived capability bound to that user, agent and run; git in the guest
// rewrites github.com URLs to /api/git-proxy/github.com/ and sends the
// capability as a header, and the proxy swaps it for that agent's own GitHub
// connection. Pushes are checked first: branch and tag deletions and updates
// to the default branch are refused before any pack data reaches GitHub.
package gitproxy
