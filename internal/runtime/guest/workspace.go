package guest

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"unicode"

	"github.com/NeoLabs-Systems/neoagent/internal/runtime/guestproto"
	"github.com/NeoLabs-Systems/neolabs-go/vm"
)

func readAllLimited(r io.Reader, limit int64) ([]byte, error) {
	data, err := io.ReadAll(io.LimitReader(r, limit+1))
	if err == nil && int64(len(data)) > limit {
		return nil, errors.New("Workspace file is too large.")
	}
	return data, err
}

func (s *Server) assertDiskSafety(requiredBytes float64) error {
	available, _ := vm.DiskCapacity(s.ws.root)
	if float64(available)-requiredBytes < float64(s.cfg.MinFreeDiskBytes) {
		return &diskLimitError{}
	}
	return nil
}

type diskLimitError struct{}

func (*diskLimitError) Error() string { return diskLimitMessage }

func query(r *http.Request, key, fallback string) string {
	if v := r.URL.Query().Get(key); v != "" {
		return v
	}
	return fallback
}

type listEntry struct {
	Name       string `json:"name"`
	Path       string `json:"path"`
	Type       string `json:"type"`
	Size       any    `json:"size"`
	ModifiedAt string `json:"modifiedAt"`
}

func (s *Server) workspaceList(w http.ResponseWriter, r *http.Request) {
	work(w, func() (any, error) {
		directory, err := s.ws.resolve(query(r, "path", "."), true)
		if err != nil {
			return nil, err
		}
		real, err := filepath.EvalSymlinks(directory)
		if err != nil {
			return nil, err
		}
		entries := []listEntry{}
		err = s.ws.open(real, func(root *os.Root, rel string) error {
			dir, err := root.Open(rel)
			if err != nil {
				return err
			}
			defer dir.Close()
			info, err := dir.Stat()
			if err != nil {
				return err
			}
			if !info.IsDir() {
				return errors.New("Workspace path is not a directory.")
			}
			names, err := dir.ReadDir(-1)
			if err != nil && err != io.EOF {
				return err
			}
			// Directory order is the file system's; a stable name order keeps
			// the listing, and the 1000 entries kept, the same between calls.
			sort.Slice(names, func(i, j int) bool { return names[i].Name() < names[j].Name() })
			if len(names) > 1000 {
				names = names[:1000]
			}
			for _, name := range names {
				stat, err := root.Lstat(filepath.Join(rel, name.Name()))
				if err != nil {
					return err
				}
				kind := "file"
				switch {
				case name.IsDir():
					kind = "directory"
				case name.Type()&os.ModeSymlink != 0:
					kind = "symlink"
				}
				entry := listEntry{Name: name.Name(), Path: s.ws.relative(filepath.Join(directory, name.Name())), Type: kind, ModifiedAt: isoTime(stat.ModTime())}
				if stat.Mode().IsRegular() {
					entry.Size = stat.Size()
				}
				entries = append(entries, entry)
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
		insertionSort(entries, compareEntries)
		return obj("path", s.ws.relative(directory), "entries", entries), nil
	})
}

// compareEntries is the order the Node agent asked for. Directories come
// first; every other pair of unlike types answers "after", which is not a
// consistent order, so the sort below must be the insertion sort V8 uses for
// lists this size to give the same listing.
func compareEntries(left, right listEntry) int {
	if left.Type != right.Type {
		if left.Type == "directory" {
			return -1
		}
		return 1
	}
	return localeCompare(left.Name, right.Name)
}

// insertionSort is a stable binary insertion sort, V8's choice for short arrays.
func insertionSort[T any](items []T, compare func(a, b T) int) {
	for start := 1; start < len(items); start++ {
		pivot := items[start]
		left, right := 0, start
		for left < right {
			mid := left + (right-left)/2
			if compare(pivot, items[mid]) < 0 {
				right = mid
			} else {
				left = mid + 1
			}
		}
		copy(items[left+1:start+1], items[left:start])
		items[left] = pivot
	}
}

// localeCompare approximates String.localeCompare for file names: punctuation
// sorts before digits before letters, letters ignore case, and lower case wins
// a tie.
func localeCompare(a, b string) int {
	ra, rb := []rune(a), []rune(b)
	for i := 0; i < len(ra) && i < len(rb); i++ {
		if ca, cb := collationKey(ra[i]), collationKey(rb[i]); ca != cb {
			if ca < cb {
				return -1
			}
			return 1
		}
	}
	if len(ra) != len(rb) {
		if len(ra) < len(rb) {
			return -1
		}
		return 1
	}
	for i := range ra {
		if ra[i] != rb[i] {
			if unicode.IsLower(ra[i]) {
				return -1
			}
			return 1
		}
	}
	return 0
}

func collationKey(r rune) float64 {
	folded := unicode.ToLower(r)
	switch {
	case unicode.IsLetter(r):
		return 2e6 + float64(folded)
	case unicode.IsDigit(r):
		return 1e6 + float64(folded)
	}
	return float64(folded)
}

func (s *Server) workspaceRead(w http.ResponseWriter, r *http.Request) {
	work(w, func() (any, error) {
		abs, err := s.ws.resolve(query(r, "path", ""), true)
		if err != nil {
			return nil, err
		}
		info, data, err := s.ws.readFile(abs)
		if err != nil {
			return nil, err
		}
		return obj("path", s.ws.relative(abs), "content", string(data), "size", info.Size(), "modifiedAt", isoTime(info.ModTime())), nil
	})
}

func (s *Server) workspaceDownload(w http.ResponseWriter, r *http.Request) {
	work(w, func() (any, error) {
		abs, err := s.ws.resolve(query(r, "path", ""), true)
		if err != nil {
			return nil, err
		}
		info, data, err := s.ws.readFile(abs)
		if err != nil {
			return nil, err
		}
		return obj("path", s.ws.relative(abs), "filename", filepath.Base(abs), "contentType", "application/octet-stream",
			"encoding", "base64", "content", base64.StdEncoding.EncodeToString(data), "size", info.Size()), nil
	})
}

// lenientBase64 decodes like Node's Buffer.from(text, 'base64'): it accepts
// both alphabets, ignores everything else and tolerates missing padding.
func lenientBase64(in string) []byte {
	var clean strings.Builder
	for _, c := range in {
		switch {
		case c == '-':
			clean.WriteByte('+')
		case c == '_':
			clean.WriteByte('/')
		case c == '=':
			// padding ends the data
			out, _ := base64.RawStdEncoding.DecodeString(trimBadTail(clean.String()))
			return out
		case c >= 'A' && c <= 'Z', c >= 'a' && c <= 'z', c >= '0' && c <= '9', c == '+', c == '/':
			clean.WriteRune(c)
		}
	}
	out, _ := base64.RawStdEncoding.DecodeString(trimBadTail(clean.String()))
	return out
}

func trimBadTail(s string) string {
	if len(s)%4 == 1 {
		return s[:len(s)-1]
	}
	return s
}

func (s *Server) workspaceWrite(w http.ResponseWriter, r *http.Request) {
	body, err := readBody(r)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, errorBody(err.Error()))
		return
	}
	work(w, func() (any, error) {
		var content []byte
		if strings.EqualFold(text(body, "encoding"), "base64") {
			content = lenientBase64(text(body, "content"))
		} else {
			content = []byte(guestproto.CoerceWritableText(body["content"]))
		}
		if len(content) > maxWorkspaceFileBytes {
			return nil, errors.New("Workspace file is too large to edit.")
		}
		if err := s.assertDiskSafety(float64(len(content))); err != nil {
			return nil, err
		}
		abs, err := s.ws.resolve(text(body, "path"), false)
		if err != nil {
			return nil, err
		}
		if err := s.writeFile(abs, content); err != nil {
			return nil, err
		}
		return obj("success", true, "path", s.ws.relative(abs)), nil
	})
}

// writeFile replaces a file atomically without changing what kind of file it
// is: a script stays executable, and a link stays a link with its target
// getting the new content.
func (s *Server) writeFile(abs string, content []byte) error {
	if err := s.ws.assertReal(abs); err != nil {
		return err
	}
	target := abs
	mode := os.FileMode(0o644)
	if _, err := os.Stat(abs); err == nil {
		if target, err = filepath.EvalSymlinks(abs); err != nil {
			return err
		}
		info, _ := os.Stat(target)
		mode = info.Mode().Perm()
	}
	if err := s.ws.assertReal(target); err != nil {
		return err
	}
	real, err := s.ws.locate(target)
	if err != nil {
		return err
	}
	return s.ws.open(real, func(root *os.Root, rel string) error {
		dir := filepath.Dir(rel)
		if err := root.MkdirAll(dir, 0o777); err != nil {
			return err
		}
		var suffix [8]byte
		if _, err := rand.Read(suffix[:]); err != nil {
			return err
		}
		temp := filepath.Join(dir, fmt.Sprintf(".%s.%d.%s.tmp", filepath.Base(rel), os.Getpid(), hex.EncodeToString(suffix[:])))
		f, err := root.OpenFile(temp, os.O_WRONLY|os.O_CREATE|os.O_EXCL, mode)
		if err != nil {
			return err
		}
		defer root.Remove(temp)
		_, werr := f.Write(content)
		if werr == nil {
			werr = f.Chmod(mode)
		}
		if werr == nil {
			werr = f.Sync()
		}
		if cerr := f.Close(); werr == nil {
			werr = cerr
		}
		if werr != nil {
			return werr
		}
		return root.Rename(temp, rel)
	})
}

var errTooLarge = errors.New("File is too large to read.")
