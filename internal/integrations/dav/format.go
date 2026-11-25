package dav

import (
	"errors"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
	"github.com/google/uuid"
)

// Clock and NewUUID are what new events and contacts are stamped with; tests
// replace them.
var (
	Clock   = time.Now
	NewUUID = uuid.NewString
)

var (
	cdata      = regexp.MustCompile(`<!\[CDATA\[([\s\S]*?)\]\]>`)
	xmlEntity  = strings.NewReplacer("&lt;", "<", "&gt;", ">", "&quot;", `"`, "&apos;", "'")
	cacheMu    sync.Mutex
	blockCache = map[string]*regexp.Regexp{}
	hasCache   = map[string]*regexp.Regexp{}
	status200  = regexp.MustCompile(`\b200\b`)
)

func decodeXML(value string) string {
	v := cdata.ReplaceAllString(value, "$1")
	v = xmlEntity.Replace(v)
	return strings.TrimSpace(strings.ReplaceAll(v, "&amp;", "&"))
}

func blockPattern(local string) *regexp.Regexp {
	cacheMu.Lock()
	defer cacheMu.Unlock()
	if re, ok := blockCache[local]; ok {
		return re
	}
	re := regexp.MustCompile(`(?i)<(?:[\w-]+:)?` + regexp.QuoteMeta(local) + `(?:\s[^>]*)?>([\s\S]*?)</(?:[\w-]+:)?` + regexp.QuoteMeta(local) + `>`)
	blockCache[local] = re
	return re
}

func xmlBlocks(xml, local string) []string {
	var out []string
	for _, m := range blockPattern(local).FindAllStringSubmatch(xml, -1) {
		out = append(out, m[1])
	}
	return out
}

// XMLText is the decoded text of the first element with that local name.
func XMLText(xml, local string) string {
	blocks := xmlBlocks(xml, local)
	if len(blocks) == 0 {
		return ""
	}
	return decodeXML(blocks[0])
}

func xmlHas(xml, local string) bool {
	cacheMu.Lock()
	re, ok := hasCache[local]
	if !ok {
		re = regexp.MustCompile(`(?i)<(?:[\w-]+:)?` + regexp.QuoteMeta(local) + `(?:\s[^>]*)?/?>`)
		hasCache[local] = re
	}
	cacheMu.Unlock()
	return re.MatchString(xml)
}

// Entry is one <d:response> of a multistatus answer.
type Entry struct {
	Href, Status                            string
	OK                                      bool
	DisplayName, ContentType, ContentLength string
	LastModified, ETag, FileID              string
	CalendarData, AddressData               string
	IsCollection, IsCalendar, IsAddressbook bool
	TrashDeletedAt, TrashOriginalPath       string
}

// ParseResponses reads a multistatus document.
func ParseResponses(xml string) []Entry {
	var out []Entry
	for _, block := range xmlBlocks(xml, "response") {
		href := decodeXML(XMLText(block, "href"))
		if href == "" {
			continue
		}
		status := XMLText(block, "status")
		original := XMLText(block, "trashbin-original-filename")
		if original == "" {
			original = XMLText(block, "trashbin-original-location")
		}
		out = append(out, Entry{
			Href: href, Status: status, OK: status == "" || status200.MatchString(status),
			DisplayName: XMLText(block, "displayname"), ContentType: XMLText(block, "getcontenttype"),
			ContentLength: XMLText(block, "getcontentlength"), LastModified: XMLText(block, "getlastmodified"),
			ETag: XMLText(block, "getetag"), FileID: XMLText(block, "fileid"),
			CalendarData: XMLText(block, "calendar-data"), AddressData: XMLText(block, "address-data"),
			IsCollection: xmlHas(block, "collection"), IsCalendar: xmlHas(block, "calendar"), IsAddressbook: xmlHas(block, "addressbook"),
			TrashDeletedAt: XMLText(block, "trashbin-deletion-time"), TrashOriginalPath: original,
		})
	}
	return out
}

var unfoldPattern = regexp.MustCompile(`\n[ \t]`)

func unfold(value string) string {
	return unfoldPattern.ReplaceAllString(strings.ReplaceAll(value, "\r\n", "\n"), "")
}

func icsBlocks(value, name string) []string {
	re := regexp.MustCompile(`BEGIN:` + name + `\n([\s\S]*?)\nEND:` + name)
	var out []string
	for _, m := range re.FindAllStringSubmatch(unfold(value), -1) {
		out = append(out, m[1])
	}
	return out
}

func icsField(block, name string) string {
	re := regexp.MustCompile(`(?mi)^` + regexp.QuoteMeta(name) + `(;[^:\n]*)?:([^\n]*)`)
	m := re.FindStringSubmatch(block)
	if m == nil {
		return ""
	}
	// The replacements run one after another like the Node chain.
	v := strings.ReplaceAll(m[2], `\n`, "\n")
	v = strings.ReplaceAll(v, `\,`, ",")
	v = strings.ReplaceAll(v, `\;`, ";")
	v = strings.ReplaceAll(v, `\\`, `\`)
	return strings.TrimSpace(v)
}

var (
	icsDateOnly = regexp.MustCompile(`^\d{8}$`)
	icsDateTime = regexp.MustCompile(`^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$`)
)

func parseIcsDate(value string) any {
	raw := strings.TrimSpace(value)
	if raw == "" {
		return nil
	}
	if icsDateOnly.MatchString(raw) {
		return raw[0:4] + "-" + raw[4:6] + "-" + raw[6:8]
	}
	m := icsDateTime.FindStringSubmatch(raw)
	if m == nil {
		return raw
	}
	iso := m[1] + "-" + m[2] + "-" + m[3] + "T" + m[4] + ":" + m[5] + ":" + m[6]
	if m[7] != "" {
		iso += "Z"
	}
	return iso
}

func eventFromBlock(block string) dyn.Ordered {
	return dyn.Ordered{
		{Key: "uid", Value: icsField(block, "UID")},
		{Key: "recurrenceId", Value: parseIcsDate(icsField(block, "RECURRENCE-ID"))},
		{Key: "summary", Value: icsField(block, "SUMMARY")},
		{Key: "description", Value: icsField(block, "DESCRIPTION")},
		{Key: "location", Value: icsField(block, "LOCATION")},
		{Key: "start", Value: parseIcsDate(icsField(block, "DTSTART"))},
		{Key: "end", Value: parseIcsDate(icsField(block, "DTEND"))},
	}
}

// ParseEvent reads the first VEVENT of a calendar object.
func ParseEvent(ics string) dyn.Ordered {
	blocks := icsBlocks(ics, "VEVENT")
	if len(blocks) == 0 {
		return eventFromBlock(unfold(ics))
	}
	return eventFromBlock(blocks[0])
}

// ParseEvents reads every VEVENT (an expanded recurring event has one per
// occurrence).
func ParseEvents(ics string) []dyn.Ordered {
	var out []dyn.Ordered
	for _, b := range icsBlocks(ics, "VEVENT") {
		out = append(out, eventFromBlock(b))
	}
	return out
}

// ParseContact reads a vCard.
func ParseContact(vcard string) dyn.Ordered {
	block := unfold(vcard)
	if blocks := icsBlocks(vcard, "VCARD"); len(blocks) > 0 {
		block = blocks[0]
	}
	return dyn.Ordered{
		{Key: "uid", Value: icsField(block, "UID")},
		{Key: "fullName", Value: icsField(block, "FN")},
		{Key: "email", Value: icsField(block, "EMAIL")},
		{Key: "phone", Value: icsField(block, "TEL")},
		{Key: "organization", Value: icsField(block, "ORG")},
	}
}

func escapeIcs(value any) string {
	v := ""
	if s, ok := value.(string); ok {
		v = s
	} else if truthy(value) {
		v = dyn.String(value)
	}
	v = strings.ReplaceAll(v, `\`, `\\`)
	v = strings.ReplaceAll(v, "\n", `\n`)
	v = strings.ReplaceAll(v, ",", `\,`)
	return strings.ReplaceAll(v, ";", `\;`)
}

var isoDateOnly = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)

const utcStamp = "20060102T150405Z"

// utc is new Date(value).toISOString() without separators and milliseconds.
func utc(value any) (string, error) {
	ms, ok := jsx.ParseDate(text(value), time.Local)
	if !ok {
		return "", errors.New("Datetime must be an ISO-8601 value.")
	}
	return time.UnixMilli(ms).UTC().Format(utcStamp), nil
}

func formatIcsDate(value any) (param, stamp string, err error) {
	raw := text(value)
	if isoDateOnly.MatchString(raw) {
		return ";VALUE=DATE", strings.ReplaceAll(raw, "-", ""), nil
	}
	stamp, err = utc(raw)
	return "", stamp, err
}

// Event is what a new or replaced calendar event holds.
type Event struct {
	UID, Summary          string
	Start, End            any
	Description, Location any
}

// BuildEventIcs writes a calendar object for one event.
func BuildEventIcs(e Event) (string, error) {
	uid := strings.TrimSpace(e.UID)
	if uid == "" {
		uid = NewUUID() + "@neoagent"
	}
	sp, ss, err := formatIcsDate(e.Start)
	if err != nil {
		return "", err
	}
	ep, es, err := formatIcsDate(e.End)
	if err != nil {
		return "", err
	}
	lines := []string{
		"BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//NeoAgent//EN", "CALSCALE:GREGORIAN", "BEGIN:VEVENT",
		"UID:" + uid,
		"DTSTAMP:" + Clock().UTC().Format(utcStamp),
		"DTSTART" + sp + ":" + ss,
		"DTEND" + ep + ":" + es,
		"SUMMARY:" + escapeIcs(e.Summary),
	}
	if truthy(e.Description) {
		lines = append(lines, "DESCRIPTION:"+escapeIcs(e.Description))
	}
	if truthy(e.Location) {
		lines = append(lines, "LOCATION:"+escapeIcs(e.Location))
	}
	lines = append(lines, "END:VEVENT", "END:VCALENDAR", "")
	return strings.Join(lines, "\r\n"), nil
}

// Contact is what a new or replaced contact holds.
type Contact struct {
	UID, FullName              string
	Email, Phone, Organization any
}

// BuildContactVcard writes a vCard 3.0.
func BuildContactVcard(c Contact) string {
	uid := strings.TrimSpace(c.UID)
	if uid == "" {
		uid = NewUUID()
	}
	lines := []string{"BEGIN:VCARD", "VERSION:3.0", "UID:" + uid, "FN:" + escapeIcs(c.FullName)}
	if truthy(c.Email) {
		lines = append(lines, "EMAIL:"+escapeIcs(c.Email))
	}
	if truthy(c.Phone) {
		lines = append(lines, "TEL:"+escapeIcs(c.Phone))
	}
	if truthy(c.Organization) {
		lines = append(lines, "ORG:"+escapeIcs(c.Organization))
	}
	lines = append(lines, "END:VCARD", "")
	return strings.Join(lines, "\r\n")
}

func truthy(v any) bool { return dyn.Truthy(v) }
