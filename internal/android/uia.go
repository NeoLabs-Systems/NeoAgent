package android

import (
	"regexp"
	"strconv"
	"strings"
)

// Bounds is a UI element's rectangle in screen pixels.
type Bounds struct {
	Left    int `json:"left"`
	Top     int `json:"top"`
	Right   int `json:"right"`
	Bottom  int `json:"bottom"`
	Width   int `json:"width"`
	Height  int `json:"height"`
	CenterX int `json:"centerX"`
	CenterY int `json:"centerY"`
}

// Node is one element of a uiautomator dump.
type Node struct {
	Text        string
	ResourceID  string
	Description string
	ClassName   string
	PackageName string
	Clickable   bool
	Enabled     bool
	Bounds      Bounds
}

// NodeSummary is the shape sent to clients.
type NodeSummary struct {
	Text        string `json:"text"`
	ResourceID  string `json:"resourceId"`
	Description string `json:"description"`
	ClassName   string `json:"className"`
	PackageName string `json:"packageName"`
	Clickable   bool   `json:"clickable"`
	Enabled     bool   `json:"enabled"`
	Bounds      Bounds `json:"bounds"`
}

// Selector picks UI elements. Empty strings are unset.
type Selector struct {
	Text        string
	ResourceID  string
	Description string
	ClassName   string
	PackageName string
	Clickable   bool
}

func (s Selector) any() bool {
	return strings.TrimSpace(s.Text) != "" || strings.TrimSpace(s.ResourceID) != "" ||
		strings.TrimSpace(s.Description) != "" || strings.TrimSpace(s.ClassName) != "" ||
		strings.TrimSpace(s.PackageName) != "" || s.Clickable
}

var (
	boundsRe = regexp.MustCompile(`\[(\d+),(\d+)\]\[(\d+),(\d+)\]`)
	attrRe   = regexp.MustCompile(`([\w:-]+)="([^"]*)"`)
	nodeRe   = regexp.MustCompile(`<node\b([^>]*)>`)
)

// xmlDecoder reproduces the entity set uiautomator output uses, in the order
// the Node implementation replaced them (&amp; last, so "&amp;lt;" stays text).
var xmlDecoder = strings.NewReplacer(
	"&quot;", `"`, "&apos;", "'", "&lt;", "<", "&gt;", ">",
	"&#10;", "\n", "&#13;", "\r", "&#39;", "'",
)

func decodeXML(s string) string {
	// The replacer does one pass; &amp; must be resolved after the others, so
	// that "&amp;quot;" decodes to "&quot;" and not to a quote.
	return strings.ReplaceAll(xmlDecoder.Replace(s), "&amp;", "&")
}

func parseBounds(raw string) Bounds {
	m := boundsRe.FindStringSubmatch(raw)
	if m == nil {
		return Bounds{}
	}
	left, _ := strconv.Atoi(m[1])
	top, _ := strconv.Atoi(m[2])
	right, _ := strconv.Atoi(m[3])
	bottom, _ := strconv.Atoi(m[4])
	return Bounds{
		Left: left, Top: top, Right: right, Bottom: bottom,
		Width: max(0, right-left), Height: max(0, bottom-top),
		CenterX: roundHalfUp(float64(left+right) / 2), CenterY: roundHalfUp(float64(top+bottom) / 2),
	}
}

// roundHalfUp is JavaScript's Math.round for non-negative values.
func roundHalfUp(v float64) int { return int(v + 0.5) }

// ParseUIDump reads the <node> elements of a uiautomator XML dump.
func ParseUIDump(xml string) []Node {
	var nodes []Node
	for _, m := range nodeRe.FindAllStringSubmatch(xml, -1) {
		attrs := map[string]string{}
		for _, a := range attrRe.FindAllStringSubmatch(m[1], -1) {
			attrs[a[1]] = decodeXML(a[2])
		}
		nodes = append(nodes, Node{
			Text: attrs["text"], ResourceID: attrs["resource-id"], Description: attrs["content-desc"],
			ClassName: attrs["class"], PackageName: attrs["package"],
			Clickable: attrs["clickable"] == "true", Enabled: attrs["enabled"] != "false",
			Bounds: parseBounds(attrs["bounds"]),
		})
	}
	return nodes
}

func needle(s string) string { return strings.ToLower(strings.TrimSpace(s)) }

// scoreNode rates how well a node fits the selector; -1 means it does not.
func scoreNode(n Node, sel Selector) int {
	score := 0
	text, resourceID := needle(n.Text), needle(n.ResourceID)
	description, className, packageName := needle(n.Description), needle(n.ClassName), needle(n.PackageName)

	if sel.ResourceID != "" {
		switch want := needle(sel.ResourceID); {
		case resourceID == want:
			score += 500
		case strings.Contains(resourceID, want):
			score += 220
		default:
			return -1
		}
	}
	if sel.Text != "" {
		switch want := needle(sel.Text); {
		case text == want:
			score += 360
		case strings.Contains(text, want):
			score += 180
		case strings.Contains(description, want):
			score += 120
		default:
			return -1
		}
	}
	if sel.Description != "" {
		switch want := needle(sel.Description); {
		case description == want:
			score += 320
		case strings.Contains(description, want):
			score += 160
		default:
			return -1
		}
	}
	if sel.ClassName != "" {
		if className != needle(sel.ClassName) {
			return -1
		}
		score += 120
	}
	if sel.PackageName != "" {
		if packageName != needle(sel.PackageName) {
			return -1
		}
		score += 80
	}
	if sel.Clickable {
		if !n.Clickable {
			return -1
		}
		score += 40
	}
	if n.Enabled {
		score += 10
	}
	if n.Bounds.Width > 0 && n.Bounds.Height > 0 {
		score += 10
	}
	return score
}

// FindBestNode returns the highest scoring node (the first among equals), or
// nil when none matches.
func FindBestNode(nodes []Node, sel Selector) *Node {
	best, bestScore := -1, -1
	for i, n := range nodes {
		if s := scoreNode(n, sel); s > bestScore {
			best, bestScore = i, s
		}
	}
	if bestScore < 0 {
		return nil
	}
	return &nodes[best]
}

// Summarize drops a node to its client shape.
func (n Node) Summarize() NodeSummary {
	return NodeSummary{
		Text: n.Text, ResourceID: n.ResourceID, Description: n.Description, ClassName: n.ClassName,
		PackageName: n.PackageName, Clickable: n.Clickable, Enabled: n.Enabled, Bounds: n.Bounds,
	}
}
