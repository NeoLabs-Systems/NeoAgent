package guest

import (
	"archive/tar"
	"compress/gzip"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var sha256Hex = regexp.MustCompile(`^[a-f0-9]{64}$`)

var errImportTooLarge = errors.New("Workspace import exceeds the guest disk safety limit.")

type importFailure struct {
	status  int
	message string
}

func (f importFailure) Error() string { return f.message }

// workspaceImport receives a tar.gz of the user's previous workspace, checks
// its digest, and unpacks it into the workspace.
func (s *Server) workspaceImport(w http.ResponseWriter, r *http.Request) {
	expected := strings.ToLower(strings.TrimSpace(r.Header.Get("x-neoagent-sha256")))
	if !sha256Hex.MatchString(expected) {
		writeJSON(w, http.StatusBadRequest, errorBody("A valid workspace archive checksum is required."))
		return
	}
	declared, _ := strconv.ParseFloat(r.Header.Get("Content-Length"), 64)
	if err := s.assertDiskSafety(declared); err != nil {
		writeJSON(w, http.StatusInsufficientStorage, obj("error", err.Error(), "code", diskLimitCode))
		return
	}
	sum, entries, err := s.importArchive(r.Body, expected)
	if err != nil {
		var failure importFailure
		if errors.As(err, &failure) {
			writeJSON(w, failure.status, errorBody(failure.message))
			return
		}
		writeJSON(w, http.StatusInternalServerError, errorBody(err.Error()))
		return
	}
	writeJSON(w, http.StatusOK, obj("success", true, "sha256", sum, "entries", entries))
}

func (s *Server) importArchive(body io.Reader, expected string) (string, int, error) {
	dir := filepath.Join(s.cfg.HomeDir, ".neoagent", "imports")
	if err := os.MkdirAll(dir, 0o777); err != nil {
		return "", 0, err
	}
	var id [16]byte
	if _, err := rand.Read(id[:]); err != nil {
		return "", 0, err
	}
	archive := filepath.Join(dir, hex.EncodeToString(id[:])+".tar.gz")
	f, err := os.OpenFile(archive, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return "", 0, err
	}
	defer os.Remove(archive)
	hash := sha256.New()
	n, err := io.Copy(io.MultiWriter(f, hash), io.LimitReader(body, s.cfg.MaxImportBytes+1))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return "", 0, err
	}
	if n > s.cfg.MaxImportBytes {
		return "", 0, importFailure{status: http.StatusRequestEntityTooLarge, message: errImportTooLarge.Error()}
	}
	digest := hex.EncodeToString(hash.Sum(nil))
	if digest != expected {
		return "", 0, importFailure{status: http.StatusBadRequest, message: "Workspace import checksum verification failed."}
	}
	entries, err := checkArchive(archive)
	if err != nil {
		return "", 0, importFailure{status: http.StatusBadRequest, message: "Workspace archive contains an unsafe path."}
	}
	realRoot, err := s.ws.realRoot()
	if err != nil {
		return "", 0, err
	}
	root, err := os.OpenRoot(realRoot)
	if err != nil {
		return "", 0, err
	}
	defer root.Close()
	if err := extractArchive(archive, root); err != nil {
		return "", 0, err
	}
	return digest, entries, nil
}

func openTar(archive string) (*tar.Reader, func(), error) {
	f, err := os.Open(archive)
	if err != nil {
		return nil, nil, err
	}
	gz, err := gzip.NewReader(f)
	if err != nil {
		f.Close()
		return nil, nil, err
	}
	return tar.NewReader(gz), func() { gz.Close(); f.Close() }, nil
}

func unsafeName(name string) bool {
	normalized := strings.ReplaceAll(name, `\`, "/")
	if strings.HasPrefix(normalized, "/") {
		return true
	}
	for _, part := range strings.Split(normalized, "/") {
		if part == ".." {
			return true
		}
	}
	return false
}

// linkEscapes reports a link target that leads out of the workspace from the
// directory of its entry.
func linkEscapes(entry, target string) bool {
	if path.IsAbs(target) || strings.HasPrefix(target, `\`) {
		return true
	}
	resolved := path.Join(path.Dir(path.Clean(entry)), target)
	return resolved == ".." || strings.HasPrefix(resolved, "../")
}

// checkArchive lists the archive before anything is written: it must be a
// readable tar.gz without absolute or parent-relative names and without links
// that lead out. It returns the number of entries.
func checkArchive(archive string) (int, error) {
	reader, closeAll, err := openTar(archive)
	if err != nil {
		return 0, err
	}
	defer closeAll()
	count := 0
	for {
		header, err := reader.Next()
		if err == io.EOF {
			return count, nil
		}
		if err != nil {
			return 0, err
		}
		count++
		if unsafeName(header.Name) {
			return 0, errors.New("unsafe path")
		}
		if (header.Typeflag == tar.TypeSymlink && linkEscapes(header.Name, header.Linkname)) ||
			(header.Typeflag == tar.TypeLink && (unsafeName(header.Linkname))) {
			return 0, errors.New("unsafe link")
		}
	}
}

// extractArchive unpacks into root without owners or special permissions, and
// only as regular files, directories and links. Devices and pipes are skipped.
func extractArchive(archive string, root *os.Root) error {
	reader, closeAll, err := openTar(archive)
	if err != nil {
		return err
	}
	defer closeAll()
	for {
		header, err := reader.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		name := path.Clean(strings.ReplaceAll(header.Name, `\`, "/"))
		if name == "." {
			continue
		}
		perm := os.FileMode(header.Mode).Perm() &^ 0o022
		switch header.Typeflag {
		case tar.TypeDir:
			if err := root.MkdirAll(name, 0o777); err != nil {
				return err
			}
			_ = root.Chmod(name, perm|0o700)
		case tar.TypeReg:
			if err := root.MkdirAll(path.Dir(name), 0o777); err != nil {
				return err
			}
			_ = root.Remove(name)
			out, err := root.OpenFile(name, os.O_WRONLY|os.O_CREATE|os.O_EXCL, perm|0o600)
			if err != nil {
				return err
			}
			_, err = io.Copy(out, reader)
			if cerr := out.Close(); err == nil {
				err = cerr
			}
			if err != nil {
				return err
			}
			_ = root.Chmod(name, perm|0o600)
		case tar.TypeSymlink:
			if err := root.MkdirAll(path.Dir(name), 0o777); err != nil {
				return err
			}
			_ = root.Remove(name)
			if err := root.Symlink(header.Linkname, name); err != nil {
				return err
			}
		case tar.TypeLink:
			if err := root.MkdirAll(path.Dir(name), 0o777); err != nil {
				return err
			}
			_ = root.Remove(name)
			if err := root.Link(path.Clean(strings.ReplaceAll(header.Linkname, `\`, "/")), name); err != nil {
				return fmt.Errorf("%s: %w", name, err)
			}
		}
	}
}
