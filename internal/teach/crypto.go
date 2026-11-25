package teach

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/json"
	"errors"
)

const (
	nonceSize = 12
	tagSize   = 16
)

// encryptJSON seals a value for the session file: nonce, then the GCM tag,
// then the ciphertext, which is the layout the Node server wrote.
func encryptJSON(key []byte, value any) ([]byte, error) {
	plain, err := json.Marshal(value)
	if err != nil {
		return nil, err
	}
	gcm, err := newGCM(key)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, nonceSize)
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}
	sealed := gcm.Seal(nil, nonce, plain, nil) // ciphertext || tag
	body, tag := sealed[:len(sealed)-tagSize], sealed[len(sealed)-tagSize:]
	out := make([]byte, 0, len(sealed)+nonceSize)
	out = append(out, nonce...)
	out = append(out, tag...)
	return append(out, body...), nil
}

// decryptJSON opens a sealed session file into v.
func decryptJSON(key, content []byte, v any) error {
	if len(content) < nonceSize+tagSize {
		return errors.New("teach: sealed session is too short")
	}
	gcm, err := newGCM(key)
	if err != nil {
		return err
	}
	nonce, tag, body := content[:nonceSize], content[nonceSize:nonceSize+tagSize], content[nonceSize+tagSize:]
	plain, err := gcm.Open(nil, nonce, append(append([]byte{}, body...), tag...), nil)
	if err != nil {
		return err
	}
	return json.Unmarshal(plain, v)
}

func newGCM(key []byte) (cipher.AEAD, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	return cipher.NewGCM(block)
}
