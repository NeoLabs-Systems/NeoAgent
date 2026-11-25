package files

import (
	"context"
	"fmt"
	"path"
	"strings"
)

// DownloadedFile is a file fetched from the agent's computer.
type DownloadedFile struct {
	Filename string
	Path     string
	Content  []byte
}

// ComputerFiles reads a file from the computer the agent works on (a VM, a
// desktop companion or this host).
type ComputerFiles interface {
	DownloadFile(ctx context.Context, userID int64, reference, deviceTarget string) (DownloadedFile, error)
}

// BufferArtifacts keeps bytes as an artifact the user owns.
type BufferArtifacts interface {
	StoreBufferArtifact(ctx context.Context, userID int64, in BufferArtifact) (storagePath string, err error)
	ArtifactStore
}

// BufferArtifact describes a file to keep as an artifact.
type BufferArtifact struct {
	Kind             string
	FilenameBase     string
	Extension        string
	OriginalFilename string
	Content          []byte
	Metadata         map[string]any
}

func alreadyLocal(userID int64, reference string, store ArtifactStore) bool {
	if schemeRE.MatchString(reference) {
		return true
	}
	if id, err := ArtifactIDFromReference(reference); err != nil || id != "" {
		return true
	}
	_, ok := store.StoragePathByFile(userID, reference)
	return ok
}

// FetchWorkspaceFileArgs replaces each argument named in fileArgs with the
// storage path of an artifact holding that file, fetched from the agent's
// computer. A file that already is an artifact, or a URL, stays as it is. On
// failure the returned error names the argument and the reason; args is
// returned unchanged when there is nothing to do.
func FetchWorkspaceFileArgs(ctx context.Context, userID int64, args map[string]any, fileArgs []string, computer ComputerFiles, store BufferArtifacts, deviceTarget string) (map[string]any, error) {
	if len(fileArgs) == 0 || computer == nil || store == nil {
		return args, nil
	}
	fetched := make(map[string]any, len(args))
	for k, v := range args {
		fetched[k] = v
	}
	for _, name := range fileArgs {
		reference := ""
		if s, ok := fetched[name].(string); ok {
			reference = strings.TrimSpace(s)
		}
		if reference == "" || alreadyLocal(userID, reference, store) {
			continue
		}
		file, err := computer.DownloadFile(ctx, userID, reference, deviceTarget)
		if err != nil {
			return nil, fmt.Errorf("%s \"%s\" could not be read from your workspace: %s", name, reference, err.Error())
		}
		filename := file.Filename
		if filename == "" {
			filename = path.Base(reference)
		}
		ext := path.Ext(filename)
		base := strings.TrimSuffix(path.Base(filename), ext)
		if base == "" {
			base = "file"
		}
		source := file.Path
		if source == "" {
			source = reference
		}
		storagePath, err := store.StoreBufferArtifact(ctx, userID, BufferArtifact{
			Kind: "workspace-file", FilenameBase: base, Extension: strings.TrimPrefix(ext, "."),
			OriginalFilename: filename, Content: file.Content,
			Metadata: map[string]any{"source": "workspace", "workspacePath": source},
		})
		if err != nil {
			return nil, err
		}
		fetched[name] = storagePath
	}
	return fetched, nil
}
