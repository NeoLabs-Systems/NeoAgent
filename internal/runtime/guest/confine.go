package guest

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// workspace confines file access to one directory. A path is first resolved
// and its real location checked, as the Node agent did; the open itself then
// goes through os.Root, so a link swapped in between cannot lead out.
type workspace struct{ root string }

func escapes(rel string) bool {
	return rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) || filepath.IsAbs(rel)
}

func (w workspace) realRoot() (string, error) { return filepath.EvalSymlinks(w.root) }

// resolve turns a request path into an absolute one inside the workspace.
func (w workspace) resolve(value string, mustExist bool) (string, error) {
	requested := strings.TrimSpace(value)
	if requested == "" {
		requested = "."
	}
	if strings.ContainsRune(requested, 0) {
		return "", errors.New("Workspace path contains invalid characters.")
	}
	candidate := filepath.Join(w.root, requested)
	if filepath.IsAbs(requested) {
		candidate = filepath.Clean(requested)
	}
	rel, err := filepath.Rel(w.root, candidate)
	if err != nil || escapes(rel) {
		return "", errors.New(workspacePathOutside)
	}
	if mustExist {
		if _, err := os.Stat(candidate); err != nil {
			return "", errors.New(workspacePathNotExists)
		}
	}
	if err := w.assertReal(candidate); err != nil {
		return "", err
	}
	return candidate, nil
}

// assertReal checks that the deepest existing part of target really lies in
// the workspace, so a link in a cloned repository cannot lead out.
func (w workspace) assertReal(target string) error {
	existing := target
	for {
		if _, err := os.Stat(existing); err == nil {
			break
		}
		parent := filepath.Dir(existing)
		if parent == existing {
			break
		}
		existing = parent
	}
	realRoot, err := w.realRoot()
	if err != nil {
		return err
	}
	realExisting, err := filepath.EvalSymlinks(existing)
	if err != nil {
		return err
	}
	rel, err := filepath.Rel(realRoot, realExisting)
	if err != nil || escapes(rel) {
		return errors.New(workspacePathOutside)
	}
	return nil
}

// relative is a workspace path as clients see it: slash separated, empty for
// the workspace itself.
func (w workspace) relative(abs string) string {
	rel, err := filepath.Rel(w.root, abs)
	if err != nil || rel == "." || rel == "" {
		return ""
	}
	return filepath.ToSlash(rel)
}

// open runs fn with a root over the real workspace and the path of real
// (already resolved) inside it.
func (w workspace) open(real string, fn func(root *os.Root, rel string) error) error {
	realRoot, err := w.realRoot()
	if err != nil {
		return err
	}
	rel, err := filepath.Rel(realRoot, real)
	if err != nil || escapes(rel) {
		return errors.New(workspacePathOutside)
	}
	root, err := os.OpenRoot(realRoot)
	if err != nil {
		return err
	}
	defer root.Close()
	return fn(root, rel)
}

// locate maps a path that may not exist yet to the same place under the real
// workspace: the real path of its deepest existing ancestor plus the rest.
func (w workspace) locate(abs string) (string, error) {
	existing, rest := abs, ""
	for {
		if _, err := os.Stat(existing); err == nil {
			break
		}
		parent := filepath.Dir(existing)
		if parent == existing {
			break
		}
		rest = filepath.Join(filepath.Base(existing), rest)
		existing = parent
	}
	real, err := filepath.EvalSymlinks(existing)
	if err != nil {
		return "", err
	}
	return filepath.Join(real, rest), nil
}

// readFile returns the bytes of a regular workspace file within the size limit.
func (w workspace) readFile(abs string) (fs.FileInfo, []byte, error) {
	real, err := filepath.EvalSymlinks(abs)
	if err != nil {
		return nil, nil, err
	}
	if err := w.assertReal(real); err != nil {
		return nil, nil, err
	}
	var info fs.FileInfo
	var data []byte
	err = w.open(real, func(root *os.Root, rel string) error {
		// A FIFO would block the open, so the kind is checked first.
		pre, err := root.Stat(rel)
		if err != nil {
			return err
		}
		if !pre.Mode().IsRegular() {
			return errors.New("Workspace path is not a file.")
		}
		f, err := root.Open(rel)
		if err != nil {
			return err
		}
		defer f.Close()
		if info, err = f.Stat(); err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return errors.New("Workspace path is not a file.")
		}
		if info.Size() > maxWorkspaceFileBytes {
			return errors.New("Workspace file is too large.")
		}
		data, err = readAllLimited(f, maxWorkspaceFileBytes)
		return err
	})
	return info, data, err
}
