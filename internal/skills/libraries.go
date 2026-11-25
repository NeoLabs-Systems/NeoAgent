package skills

import (
	"embed"
	"io/fs"
)

// The skill libraries shipped with NeoAgent, one folder per library with its
// library.json manifest.
//
//go:embed all:libraries
var librariesFS embed.FS

func builtinLibraries() fs.FS {
	sub, err := fs.Sub(librariesFS, "libraries")
	if err != nil {
		panic(err)
	}
	return sub
}
