package dav

import (
	"context"
	"regexp"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
	"github.com/NeoLabs-Systems/neoagent/internal/integrations"
)

// Request is one authenticated DAV request against a store.
type Request struct {
	Method  string
	Headers map[string]string
	Body    string
	// Accept replaces the default Accept header.
	Accept string
}

// Store is a calendar or address book home: Home is its path ending in "/",
// Do performs a request and returns the response text (or the error the
// integration reports for a failed one).
type Store struct {
	Home string
	Do   func(ctx context.Context, path string, r Request) (string, error)
}

const day = 24 * time.Hour

func (s Store) pathIn(relative any) (string, error) {
	enc, err := EncodePathSegments(relative)
	return s.Home + enc, err
}

// itemHref is the href of an event or contact: a bare name lives inside the
// collection, a path with a slash is relative to the home.
func (s Store) itemHref(collection, item any) (string, error) {
	relative, err := NormalizeRemotePath(item)
	if err != nil {
		return "", err
	}
	if !strings.Contains(relative, "/") {
		coll, err := NormalizeRemotePath(collection)
		if err != nil {
			return "", err
		}
		relative = coll + "/" + relative
	}
	return s.pathIn(relative)
}

func pathUID(path, ext string) string {
	normalized, _ := NormalizeRemotePath(path)
	parts := strings.Split(normalized, "/")
	name := parts[len(parts)-1]
	return regexp.MustCompile(`(?i)\`+ext+`$`).ReplaceAllString(name, "")
}

func collections(xml, home string, pick func(Entry) bool) []dyn.Ordered {
	out := []dyn.Ordered{}
	for _, e := range ParseResponses(xml) {
		if !e.OK || !pick(e) {
			continue
		}
		path := HrefToRemotePath(e.Href, home)
		if path == "" {
			continue
		}
		name := strings.TrimSpace(e.DisplayName)
		if name == "" {
			name = path
		}
		out = append(out, dyn.Ordered{{Key: "path", Value: path}, {Key: "name", Value: name}})
	}
	return out
}

func etag(e Entry) any {
	if t := strings.TrimSpace(e.ETag); t != "" {
		return t
	}
	return nil
}

// Calendar runs the <prefix>_*calendar tools; ok is false for other tools.
func Calendar(ctx context.Context, prefix, name string, args map[string]any, s Store) (result any, ok bool, err error) {
	op, found := strings.CutPrefix(name, prefix+"_")
	if !found {
		return nil, false, nil
	}
	put := func(href, ics string) error {
		_, err := s.Do(ctx, href, Request{Method: "PUT", Headers: map[string]string{"Content-Type": "text/calendar; charset=utf-8"}, Body: ics})
		return err
	}
	switch op {
	case "list_calendars":
		xml, err := s.Do(ctx, s.Home, Request{Method: "PROPFIND", Headers: map[string]string{"Depth": "1", "Content-Type": "application/xml; charset=utf-8"},
			Body: "<?xml version=\"1.0\"?>\n<d:propfind xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">\n  <d:prop><d:displayname/><d:resourcetype/></d:prop>\n</d:propfind>"})
		if err != nil {
			return nil, true, err
		}
		return collections(xml, s.Home, func(e Entry) bool { return e.IsCalendar }), true, nil
	case "list_events":
		startArg, endArg := args["start"], args["end"]
		if !dyn.Truthy(startArg) {
			startArg = Clock().UTC().Format("2006-01-02T15:04:05.000Z")
		}
		if !dyn.Truthy(endArg) {
			endArg = Clock().Add(30 * day).UTC().Format("2006-01-02T15:04:05.000Z")
		}
		start, err := utc(startArg)
		if err != nil {
			return nil, true, err
		}
		end, err := utc(endArg)
		if err != nil {
			return nil, true, err
		}
		target, err := s.pathIn(args["calendar"])
		if err != nil {
			return nil, true, err
		}
		xml, err := s.Do(ctx, target, Request{Method: "REPORT", Headers: map[string]string{"Depth": "1", "Content-Type": "application/xml; charset=utf-8"},
			Body: `<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data><c:expand start="` + start + `" end="` + end + `"/></c:calendar-data></d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VEVENT">
        <c:time-range start="` + start + `" end="` + end + `"/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>`})
		if err != nil {
			return nil, true, err
		}
		events := []dyn.Ordered{}
		for _, e := range ParseResponses(xml) {
			if !e.OK || e.CalendarData == "" {
				continue
			}
			for _, ev := range ParseEvents(e.CalendarData) {
				row := dyn.Ordered{{Key: "path", Value: HrefToRemotePath(e.Href, s.Home)}, {Key: "etag", Value: etag(e)}}
				events = append(events, merge(row, ev))
			}
		}
		return events, true, nil
	case "get_event":
		href, err := s.itemHref(args["calendar"], args["event_path"])
		if err != nil {
			return nil, true, err
		}
		ics, err := s.Do(ctx, href, Request{Method: "GET", Accept: "text/calendar, */*"})
		if err != nil {
			return nil, true, err
		}
		return merge(dyn.Ordered{{Key: "path", Value: HrefToRemotePath(href, s.Home)}}, ParseEvent(ics)), true, nil
	case "create_event":
		summary, err := integrations.RequireText(args["summary"], "summary")
		if err != nil {
			return nil, true, err
		}
		ics, err := BuildEventIcs(Event{Summary: summary, Start: args["start"], End: args["end"], Description: args["description"], Location: args["location"]})
		if err != nil {
			return nil, true, err
		}
		uid := ParseEvent(ics).Get("uid").(string)
		coll, err := NormalizeRemotePath(args["calendar"])
		if err != nil {
			return nil, true, err
		}
		eventPath := coll + "/" + uid + ".ics"
		target, err := s.pathIn(eventPath)
		if err != nil {
			return nil, true, err
		}
		if err := put(target, ics); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "path", Value: eventPath}, {Key: "uid", Value: uid}, {Key: "summary", Value: text(args["summary"])}}, true, nil
	case "update_event":
		href, err := s.itemHref(args["calendar"], args["event_path"])
		if err != nil {
			return nil, true, err
		}
		current := HrefToRemotePath(href, s.Home)
		uid := text(args["uid"])
		if uid == "" {
			uid = pathUID(current, ".ics")
		}
		summary, err := integrations.RequireText(args["summary"], "summary")
		if err != nil {
			return nil, true, err
		}
		ics, err := BuildEventIcs(Event{UID: uid, Summary: summary, Start: args["start"], End: args["end"], Description: args["description"], Location: args["location"]})
		if err != nil {
			return nil, true, err
		}
		if err := put(href, ics); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "path", Value: current}, {Key: "uid", Value: uid}, {Key: "summary", Value: text(args["summary"])}}, true, nil
	case "delete_event":
		href, err := s.itemHref(args["calendar"], args["event_path"])
		if err != nil {
			return nil, true, err
		}
		if _, err := s.Do(ctx, href, Request{Method: "DELETE"}); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "deleted", Value: true}, {Key: "path", Value: HrefToRemotePath(href, s.Home)}}, true, nil
	}
	return nil, false, nil
}

// merge is {...a, ...b}: later members replace earlier ones in place.
func merge(a, b dyn.Ordered) dyn.Ordered {
	out := append(dyn.Ordered{}, a...)
	for _, kv := range b {
		out = out.Set(kv.Key, kv.Value)
	}
	return out
}

func matchesQuery(contact dyn.Ordered, query any) bool {
	needle := strings.ToLower(text(query))
	if needle == "" {
		return true
	}
	for _, k := range []string{"fullName", "email", "phone", "organization"} {
		if strings.Contains(strings.ToLower(text(contact.Get(k))), needle) {
			return true
		}
	}
	return false
}

func contactFromArgs(args map[string]any, uid string) (Contact, error) {
	full, err := integrations.RequireText(args["full_name"], "full_name")
	if err != nil {
		return Contact{}, err
	}
	return Contact{UID: uid, FullName: full, Email: args["email"], Phone: args["phone"], Organization: args["organization"]}, nil
}

// Contacts runs the <prefix>_*contact tools; ok is false for other tools.
func Contacts(ctx context.Context, prefix, name string, args map[string]any, s Store) (result any, ok bool, err error) {
	op, found := strings.CutPrefix(name, prefix+"_")
	if !found {
		return nil, false, nil
	}
	put := func(href, vcard string) error {
		_, err := s.Do(ctx, href, Request{Method: "PUT", Headers: map[string]string{"Content-Type": "text/vcard; charset=utf-8"}, Body: vcard})
		return err
	}
	switch op {
	case "list_addressbooks":
		xml, err := s.Do(ctx, s.Home, Request{Method: "PROPFIND", Headers: map[string]string{"Depth": "1", "Content-Type": "application/xml; charset=utf-8"},
			Body: "<?xml version=\"1.0\"?>\n<d:propfind xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:carddav\">\n  <d:prop><d:displayname/><d:resourcetype/></d:prop>\n</d:propfind>"})
		if err != nil {
			return nil, true, err
		}
		return collections(xml, s.Home, func(e Entry) bool { return e.IsAddressbook }), true, nil
	case "list_contacts":
		target, err := s.pathIn(args["addressbook"])
		if err != nil {
			return nil, true, err
		}
		xml, err := s.Do(ctx, target, Request{Method: "REPORT", Headers: map[string]string{"Depth": "1", "Content-Type": "application/xml; charset=utf-8"},
			Body: "<?xml version=\"1.0\"?>\n<c:addressbook-query xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:carddav\">\n  <d:prop><d:getetag/><c:address-data/></d:prop>\n</c:addressbook-query>"})
		if err != nil {
			return nil, true, err
		}
		contacts := []dyn.Ordered{}
		for _, e := range ParseResponses(xml) {
			if !e.OK || e.AddressData == "" {
				continue
			}
			c := merge(dyn.Ordered{{Key: "path", Value: HrefToRemotePath(e.Href, s.Home)}, {Key: "etag", Value: etag(e)}}, ParseContact(e.AddressData))
			if matchesQuery(c, args["query"]) {
				contacts = append(contacts, c)
			}
		}
		return contacts, true, nil
	case "get_contact":
		href, err := s.itemHref(args["addressbook"], args["contact_path"])
		if err != nil {
			return nil, true, err
		}
		vcard, err := s.Do(ctx, href, Request{Method: "GET", Accept: "text/vcard, */*"})
		if err != nil {
			return nil, true, err
		}
		return merge(dyn.Ordered{{Key: "path", Value: HrefToRemotePath(href, s.Home)}}, ParseContact(vcard)), true, nil
	case "create_contact":
		c, err := contactFromArgs(args, "")
		if err != nil {
			return nil, true, err
		}
		vcard := BuildContactVcard(c)
		uid := ParseContact(vcard).Get("uid").(string)
		book, err := NormalizeRemotePath(args["addressbook"])
		if err != nil {
			return nil, true, err
		}
		contactPath := book + "/" + uid + ".vcf"
		target, err := s.pathIn(contactPath)
		if err != nil {
			return nil, true, err
		}
		if err := put(target, vcard); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "path", Value: contactPath}, {Key: "uid", Value: uid}, {Key: "fullName", Value: text(args["full_name"])}}, true, nil
	case "update_contact":
		href, err := s.itemHref(args["addressbook"], args["contact_path"])
		if err != nil {
			return nil, true, err
		}
		current := HrefToRemotePath(href, s.Home)
		uid := text(args["uid"])
		if uid == "" {
			uid = pathUID(current, ".vcf")
		}
		c, err := contactFromArgs(args, uid)
		if err != nil {
			return nil, true, err
		}
		if err := put(href, BuildContactVcard(c)); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "path", Value: current}, {Key: "uid", Value: uid}, {Key: "fullName", Value: text(args["full_name"])}}, true, nil
	case "delete_contact":
		href, err := s.itemHref(args["addressbook"], args["contact_path"])
		if err != nil {
			return nil, true, err
		}
		if _, err := s.Do(ctx, href, Request{Method: "DELETE"}); err != nil {
			return nil, true, err
		}
		return dyn.Ordered{{Key: "deleted", Value: true}, {Key: "path", Value: HrefToRemotePath(href, s.Home)}}, true, nil
	}
	return nil, false, nil
}
