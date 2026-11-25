package whatsapp

import "context"

// ConvertBaileysLogin moves a Baileys login in authDir into the whatsmeow
// store at storePath when that store does not exist yet; other WhatsApp
// clients (the personal WhatsApp integration) share the conversion. A login
// that cannot be moved is an error only the user can fix by linking again.
func ConvertBaileysLogin(ctx context.Context, authDir, storePath string) error {
	return convertBaileysLogin(ctx, authDir, storePath)
}
