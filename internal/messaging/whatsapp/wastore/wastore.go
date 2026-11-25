// Package wastore opens the whatsmeow device store: one SQLite file inside an
// agent's WhatsApp auth directory, on the pure-Go modernc driver.
package wastore

import (
	"context"
	"database/sql"
	"fmt"
	"net/url"
	"os"
	"path/filepath"

	"go.mau.fi/whatsmeow/store/sqlstore"
	_ "modernc.org/sqlite" // registers the "sqlite" driver
)

// FileName is the store's file name inside the auth directory.
const FileName = "whatsmeow.db"

// Store is an opened device store. DB is the underlying handle, for the few
// rows (pre-keys) the whatsmeow API cannot insert by id.
type Store struct {
	Container *sqlstore.Container
	DB        *sql.DB
}

// Close releases the database.
func (s *Store) Close() error { return s.Container.Close() }

// Open creates the file (mode 0600, directory 0700) when needed, upgrades the
// schema and returns the store.
func Open(ctx context.Context, path string) (*Store, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	if err := f.Close(); err != nil {
		return nil, err
	}
	query := url.Values{}
	for _, pragma := range []string{"foreign_keys(1)", "journal_mode(WAL)", "busy_timeout(5000)"} {
		query.Add("_pragma", pragma)
	}
	db, err := sql.Open("sqlite", "file:"+path+"?"+query.Encode())
	if err != nil {
		return nil, err
	}
	container := sqlstore.NewWithDB(db, "sqlite3", nil)
	if err := container.Upgrade(ctx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("upgrade whatsapp store: %w", err)
	}
	return &Store{Container: container, DB: db}, nil
}
