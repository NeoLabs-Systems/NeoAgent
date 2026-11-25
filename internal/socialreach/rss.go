package socialreach

import (
	"context"
	"encoding/xml"
	"io"
	"regexp"
	"strings"
)

type rssChannel struct {
	base
	http fetcher
}

func newRSS(f fetcher) *rssChannel { return &rssChannel{base{platforms["rss"]}, f} }

var feedLike = regexp.MustCompile(`(?:/feed\b|/rss\b|\.xml\b|atom)`)

func (c *rssChannel) canHandleURL(raw string) bool { return feedLike.MatchString(strings.ToLower(raw)) }

func (c *rssChannel) check(context.Context, int64) (obj, error) {
	s := c.baseStatus()
	s.set("activeBackend", "node_xml")
	s.set("message", "Reads RSS and Atom feeds with the built-in Node parser.")
	return s, nil
}

// xmlNode is an element of a leniently parsed feed.
type xmlNode struct {
	name   string
	attrs  map[string]string
	parent *xmlNode
	kids   []*xmlNode
	body   []xmlPiece
}

// xmlPiece is either a text run or a child element, in document order.
type xmlPiece struct {
	text  string
	child *xmlNode
}

func parseXML(raw string) *xmlNode {
	dec := xml.NewDecoder(strings.NewReader(raw))
	dec.Strict = false
	dec.Entity = xml.HTMLEntity
	root := &xmlNode{}
	cur := root
	for {
		tok, err := dec.RawToken()
		if err != nil && err != io.EOF {
			// A broken feed keeps what was read, as the lenient parser did.
			break
		}
		if tok == nil {
			break
		}
		switch t := tok.(type) {
		case xml.StartElement:
			n := &xmlNode{name: qualified(t.Name), attrs: map[string]string{}, parent: cur}
			for _, a := range t.Attr {
				n.attrs[qualified(a.Name)] = a.Value
			}
			cur.kids = append(cur.kids, n)
			cur.body = append(cur.body, xmlPiece{child: n})
			cur = n
		case xml.EndElement:
			for p := cur; p != nil; p = p.parent {
				if p.name == qualified(t.Name) && p.parent != nil {
					cur = p.parent
					break
				}
			}
		case xml.CharData:
			cur.body = append(cur.body, xmlPiece{text: string(t)})
		}
		if err == io.EOF {
			break
		}
	}
	return root
}

func qualified(n xml.Name) string {
	if n.Space != "" {
		return n.Space + ":" + n.Local
	}
	return n.Local
}

func (n *xmlNode) text() string {
	var b strings.Builder
	for _, p := range n.body {
		if p.child != nil {
			b.WriteString(p.child.text())
		} else {
			b.WriteString(p.text)
		}
	}
	return b.String()
}

// descendants lists elements below n in document order.
func (n *xmlNode) descendants(visit func(*xmlNode)) {
	for _, k := range n.kids {
		visit(k)
		k.descendants(visit)
	}
}

// find returns the first descendant with the name; a path "a b" means a `b`
// inside an `a`.
func (n *xmlNode) find(selector string) *xmlNode {
	names := strings.Fields(selector)
	var found *xmlNode
	n.descendants(func(d *xmlNode) {
		if found != nil || d.name != names[len(names)-1] {
			return
		}
		if len(names) == 2 {
			ok := false
			for p := d.parent; p != nil && p != n.parent; p = p.parent {
				if p.name == names[0] {
					ok = true
				}
			}
			if !ok {
				return
			}
		}
		found = d
	})
	return found
}

func (n *xmlNode) firstText(names ...string) string {
	for _, name := range names {
		if d := n.find(name); d != nil {
			if t := jsTrim(d.text()); t != "" {
				return t
			}
		}
	}
	return ""
}

func (c *rssChannel) read(ctx context.Context, a readArgs) (any, error) {
	u, err := assertHTTPURL(a.get("url"))
	if err != nil {
		return nil, err
	}
	if u.Path == "" {
		u.Path = "/"
	}
	body, err := c.http.text(ctx, u.String(), fetchOptions{strict: true})
	if err != nil {
		return nil, err
	}
	doc := parseXML(body)
	var entries []*xmlNode
	var title any
	doc.descendants(func(d *xmlNode) {
		switch {
		case d.name == "item" || d.name == "entry":
			entries = append(entries, d)
		case d.name == "title" && title == nil && d.parent != nil && (d.parent.name == "channel" || d.parent.name == "feed"):
			if t := jsTrim(d.text()); t != "" {
				title = t
			}
		}
	})
	if limit := normalizeLimit(a.get("limit"), 20, 100); len(entries) > limit {
		entries = entries[:limit]
	}
	items := []any{}
	for _, e := range entries {
		link := e.firstText("link")
		if link == "" {
			if l := e.find("link"); l != nil {
				link = l.attrs["href"]
			}
		}
		items = append(items, obj{
			{"title", e.firstText("title")}, {"url", link},
			{"summary", compactText(e.firstText("description", "summary", "content"), 1200)},
			{"author", e.firstText("author name", "author", "dc:creator")},
			{"publishedAt", e.firstText("pubDate", "published", "updated")},
		})
	}
	return obj{{"platform", c.ID}, {"url", u.String()}, {"title", title}, {"items", items}, {"source", "rss"}}, nil
}
