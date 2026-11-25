// Package files finds the files tools may read for a user: owned artifacts
// and workspace files, and fetches files the agent made on its own computer
// into artifacts before a tool uses them.
package files

import (
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var (
	artifactPathRE = regexp.MustCompile(`^/api/artifacts/([^/?#]+)/content(?:[?#].*)?$`)
	artifactIDRE   = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)
	schemeRE       = regexp.MustCompile(`(?i)^[a-z][a-z0-9+.-]*://`)
)

// ArtifactStore is what reference resolution needs from the artifact domain.
type ArtifactStore interface {
	// StoragePath returns the file of an artifact the user owns.
	StoragePath(userID int64, artifactID string) (path string, ok bool)
	// StoragePathByFile returns the artifact file the user owns whose stored
	// path is reference.
	StoragePathByFile(userID int64, reference string) (path string, ok bool)
}

// Workspace resolves a path inside a user's workspace to an absolute file name.
type Workspace interface {
	ResolvePath(userKey, candidate, label string) (string, error)
}

// ArtifactIDFromReference returns the artifact id a reference names, either as
// a bare id or as the /api/artifacts/<id>/content URL path; "" when it names
// none. A malformed percent escape is an error.
func ArtifactIDFromReference(reference string) (string, error) {
	if m := artifactPathRE.FindStringSubmatch(reference); m != nil {
		id, err := url.PathUnescape(m[1])
		if err != nil {
			return "", errors.New("The artifact reference is malformed.")
		}
		return id, nil
	}
	if artifactIDRE.MatchString(reference) {
		return reference, nil
	}
	return "", nil
}

func usableFile(path, label string) (string, error) {
	real, err := filepath.EvalSymlinks(path)
	if err != nil {
		return "", fmt.Errorf("%s does not exist.", label)
	}
	info, err := os.Stat(real)
	if err != nil {
		return "", fmt.Errorf("%s does not exist.", label)
	}
	if !info.Mode().IsRegular() {
		return "", fmt.Errorf("%s must reference a regular file.", label)
	}
	return real, nil
}

// ResolveReference returns the real path of the file a user named, which is an
// artifact id or content URL, the stored path of an owned artifact, or a
// workspace path. Anything else (another URL) is refused. Either store or
// workspace may be nil. label names the file in error messages ("File" when
// empty).
func ResolveReference(userID int64, reference string, store ArtifactStore, workspace Workspace, label string) (string, error) {
	if label == "" {
		label = "File"
	}
	ref := strings.TrimSpace(reference)
	if ref == "" {
		return "", fmt.Errorf("%s reference is required.", label)
	}
	if strings.ContainsRune(ref, 0) {
		return "", fmt.Errorf("%s reference is invalid.", label)
	}
	artifactID, err := ArtifactIDFromReference(ref)
	if err != nil {
		return "", err
	}
	if artifactID != "" {
		var path string
		var ok bool
		if store != nil {
			path, ok = store.StoragePath(userID, artifactID)
		}
		if !ok {
			return "", fmt.Errorf("%s artifact was not found for this user.", label)
		}
		return usableFile(path, label)
	}
	if store != nil {
		if path, ok := store.StoragePathByFile(userID, ref); ok {
			return usableFile(path, label)
		}
	}
	if schemeRE.MatchString(ref) {
		return "", fmt.Errorf("%s must be a workspace path or owned artifact.", label)
	}
	if workspace == nil {
		return "", errors.New("Workspace file access is unavailable.")
	}
	path, err := workspace.ResolvePath(fmt.Sprint(userID), ref, label)
	if err != nil {
		return "", err
	}
	return usableFile(path, label)
}
