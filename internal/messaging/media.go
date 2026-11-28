package messaging

import (
	"context"
	"errors"
)

// MediaResolver maps the attachment a user or agent named (an owned artifact
// id or URL, or a workspace path) to the real host file a platform may read,
// refusing anything else.
type MediaResolver func(ctx context.Context, userID int64, reference string) (string, error)

// resolveMedia is the one gate between a named attachment and a platform:
// every send resolves here, so adapters only ever see the user's own files.
func (m *Manager) resolveMedia(ctx context.Context, userID int64, reference string) (string, error) {
	if reference == "" {
		return "", nil
	}
	if m.cfg.ResolveMedia == nil {
		return "", errors.New("Message attachments are unavailable.")
	}
	return m.cfg.ResolveMedia(ctx, userID, reference)
}
