package whatsapp

import (
	"mime"
	"path/filepath"
	"strings"

	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"google.golang.org/protobuf/reflect/protoreflect"
)

// What an inbound WhatsApp message says and carries, read from the protobuf.

// unwrap peels the wrappers WhatsApp puts around a message (disappearing-chat,
// view-once, document with caption) to reach the content, like Baileys'
// normalizeMessageContent.
func unwrap(m *waE2E.Message) *waE2E.Message {
	for m != nil {
		switch {
		case m.GetEphemeralMessage().GetMessage() != nil:
			m = m.GetEphemeralMessage().GetMessage()
		case m.GetViewOnceMessage().GetMessage() != nil:
			m = m.GetViewOnceMessage().GetMessage()
		case m.GetViewOnceMessageV2().GetMessage() != nil:
			m = m.GetViewOnceMessageV2().GetMessage()
		case m.GetViewOnceMessageV2Extension().GetMessage() != nil:
			m = m.GetViewOnceMessageV2Extension().GetMessage()
		case m.GetDocumentWithCaptionMessage().GetMessage() != nil:
			m = m.GetDocumentWithCaptionMessage().GetMessage()
		default:
			return m
		}
	}
	return m
}

// contextInfo is the quote and mention data of whichever part carries it.
func contextInfo(m *waE2E.Message) *waE2E.ContextInfo {
	for _, ci := range []*waE2E.ContextInfo{
		m.GetExtendedTextMessage().GetContextInfo(),
		m.GetImageMessage().GetContextInfo(),
		m.GetVideoMessage().GetContextInfo(),
		m.GetDocumentMessage().GetContextInfo(),
		m.GetAudioMessage().GetContextInfo(),
	} {
		if ci != nil {
			return ci
		}
	}
	return nil
}

// quotedText is what a quoted message says as far as the quote carries it:
// text and captions come along, media only as its kind.
func quotedText(q *waE2E.Message) string {
	if q == nil {
		return ""
	}
	for _, text := range []string{
		q.GetConversation(),
		q.GetExtendedTextMessage().GetText(),
		q.GetImageMessage().GetCaption(),
		q.GetVideoMessage().GetCaption(),
		q.GetDocumentMessage().GetCaption(),
	} {
		if text != "" {
			return text
		}
	}
	switch {
	case q.GetImageMessage() != nil:
		return "[Image]"
	case q.GetVideoMessage() != nil:
		return "[Video]"
	case q.GetAudioMessage() != nil:
		if q.GetAudioMessage().GetPTT() {
			return "[Voice message]"
		}
		return "[Audio]"
	case q.GetDocumentMessage() != nil:
		if name := q.GetDocumentMessage().GetFileName(); name != "" {
			return "[Document: " + name + "]"
		}
		return "[Document]"
	case q.GetStickerMessage() != nil:
		return "[Sticker]"
	}
	return ""
}

// body is the sendable part of a message.
type body struct {
	content       string
	mediaType     string // image, video, audio, document, sticker or ""
	mediaFileName string
	audioMime     string
	voiceNote     map[string]any
	media         whatsmeow.DownloadableMessage
}

// readBody extracts text and attachment from a message in the order Node did:
// plain text, extended text, image, video, audio, audio sent as a document,
// document, sticker.
func readBody(m *waE2E.Message) body {
	var b body
	switch {
	case m.GetConversation() != "":
		b.content = m.GetConversation()
	case m.GetExtendedTextMessage().GetText() != "":
		b.content = m.GetExtendedTextMessage().GetText()
	case m.GetImageMessage() != nil:
		b.content = firstNonEmpty(m.GetImageMessage().GetCaption(), "[Image]")
		b.mediaType, b.media = "image", m.GetImageMessage()
	case m.GetVideoMessage() != nil:
		b.content = firstNonEmpty(m.GetVideoMessage().GetCaption(), "[Video]")
		b.mediaType, b.media = "video", m.GetVideoMessage()
	case m.GetAudioMessage() != nil:
		a := m.GetAudioMessage()
		b.mediaType, b.media = "audio", a
		b.audioMime = a.GetMimetype()
		source := "whatsapp_audio"
		if a.GetPTT() {
			source = "whatsapp_ptt"
		}
		var duration any
		if a.GetSeconds() != 0 {
			duration = float64(a.GetSeconds())
		}
		b.voiceNote = map[string]any{"source": source, "durationSec": duration, "forwarded": a.GetContextInfo().GetIsForwarded()}
	case strings.HasPrefix(m.GetDocumentMessage().GetMimetype(), "audio/"):
		d := m.GetDocumentMessage()
		b.content = d.GetCaption()
		b.mediaType, b.media = "audio", d
		b.audioMime = d.GetMimetype()
		b.voiceNote = map[string]any{"source": "whatsapp_audio", "durationSec": nil}
	case m.GetDocumentMessage() != nil:
		d := m.GetDocumentMessage()
		b.mediaFileName = d.GetFileName()
		// The caption carries the sender's instruction; the file name is only a
		// fallback so the agent still sees what was attached.
		b.content = firstNonEmpty(d.GetCaption(), d.GetFileName(), "[Document]")
		b.mediaType, b.media = "document", d
	case m.GetStickerMessage() != nil:
		b.content = "[Sticker]"
		b.mediaType = "sticker"
	}
	return b
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

// kinds lists the populated top-level parts, for the log line about a message
// with nothing readable in it.
func kinds(m *waE2E.Message) string {
	if m == nil {
		return "empty payload"
	}
	var names []string
	m.ProtoReflect().Range(func(fd protoreflect.FieldDescriptor, _ protoreflect.Value) bool {
		names = append(names, fd.JSONName())
		return true
	})
	if len(names) == 0 {
		return "empty payload"
	}
	return strings.Join(names, ", ")
}

// groupText is the text a mention can appear in.
func groupText(m *waE2E.Message) string {
	return firstNonEmpty(m.GetConversation(), m.GetExtendedTextMessage().GetText(),
		m.GetImageMessage().GetCaption(), m.GetVideoMessage().GetCaption())
}

// audioExtension is fileExtensionForMimeType of the voice code.
func audioExtension(mime string) string {
	mime = strings.ToLower(strings.TrimSpace(mime))
	switch {
	case strings.HasPrefix(mime, "audio/mpeg") || strings.Contains(mime, "mp3"):
		return "mp3"
	case strings.HasPrefix(mime, "audio/webm"):
		return "webm"
	case strings.HasPrefix(mime, "audio/ogg"):
		return "ogg"
	case strings.HasPrefix(mime, "audio/wav"):
		return "wav"
	case strings.HasPrefix(mime, "audio/mp4") || strings.Contains(mime, "m4a"):
		return "m4a"
	}
	return "wav"
}

// mediaExtension is the file extension an inbound attachment is stored under.
func mediaExtension(mediaType, fileName, audioMime string) string {
	if mediaType == "audio" {
		return audioExtension(firstNonEmpty(audioMime, "audio/ogg"))
	}
	if mediaType == "document" {
		if ext := cleanExtension(fileName); ext != "" {
			return ext
		}
	}
	switch mediaType {
	case "image":
		return "jpg"
	case "video":
		return "mp4"
	}
	return "bin"
}

func cleanExtension(name string) string {
	i := strings.LastIndex(name, ".")
	if i <= 0 {
		return ""
	}
	var out []rune
	for _, r := range strings.ToLower(name[i+1:]) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			out = append(out, r)
		}
	}
	return string(out)
}

// mediaContentType is the content type recorded with a stored attachment.
func mediaContentType(mediaType, audioMime string) string {
	switch mediaType {
	case "audio":
		mime, _, _ := strings.Cut(firstNonEmpty(audioMime, "audio/ogg"), ";")
		return mime
	case "image":
		return "image/jpeg"
	case "video":
		return "video/mp4"
	}
	return "application/octet-stream"
}

// documentMime is the content type of a file sent as a document.
func documentMime(path string) string {
	if t := mime.TypeByExtension(filepath.Ext(path)); t != "" {
		return t
	}
	return "application/octet-stream"
}
