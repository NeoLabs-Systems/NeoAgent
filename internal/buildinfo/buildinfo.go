// Package buildinfo carries the release version, set at link time:
//
//	go build -ldflags "-X github.com/NeoLabs-Systems/neoagent/internal/buildinfo.Version=$(cat internal/buildinfo/VERSION)"
package buildinfo

// Version is the NeoAgent release version ("dev" in development builds).
var Version = "dev"
