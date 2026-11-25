package memory

import (
	"crypto/sha256"
	"encoding/hex"
	"regexp"
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/memory/jsx"
)

const (
	chunkTargetChars   = 1400
	chunkMaxChars      = 2200
	targetSegmentWords = 260
)

var segmentTypes = map[string]bool{
	"Caption": true, "Footnote": true, "Formula": true, "ListItem": true, "Page": true, "PageFooter": true,
	"PageHeader": true, "Picture": true, "SectionHeader": true, "Table": true, "Text": true, "Title": true,
}

var segmentAliases = map[string]string{
	"caption": "Caption", "footnote": "Footnote", "formula": "Formula",
	"listitem": "ListItem", "list_item": "ListItem", "list item": "ListItem",
	"page": "Page", "pagefooter": "PageFooter", "page_footer": "PageFooter", "page footer": "PageFooter",
	"pageheader": "PageHeader", "page_header": "PageHeader", "page header": "PageHeader",
	"picture": "Picture", "image": "Picture", "figure": "Picture",
	"sectionheader": "SectionHeader", "section_header": "SectionHeader", "section header": "SectionHeader",
	"table": "Table", "text": "Text", "title": "Title",
}

// Chunk is a slice of a document. Offsets count UTF-16 units, as Node stored them.
type Chunk struct {
	ChunkIndex  int
	CharStart   int
	CharEnd     int
	Content     string
	ContentHash string
	Metadata    *jsx.Obj
}

func contentHash(content string) string {
	sum := sha256.Sum256([]byte(content))
	return hex.EncodeToString(sum[:])
}

func normalizeNewlines(text string) string {
	return strings.ReplaceAll(strings.ReplaceAll(text, "\r\n", "\n"), "\r", "\n")
}

func trimmedBlocks(parts []string) []string {
	var blocks []string
	for _, p := range parts {
		if t := jsx.Trim(p); t != "" {
			blocks = append(blocks, t)
		}
	}
	return blocks
}

// lineStartsAt is the multiline ^: the start of the text, or after a line terminator.
func lineStartsAt(text string, i int) bool {
	if i == 0 {
		return true
	}
	if text[i-1] == '\n' {
		return true
	}
	return i >= 3 && (text[i-3:i] == " " || text[i-3:i] == " ")
}

// headingAt is (?=^#{1,6}\s) at i.
func headingAt(text string, i int) bool {
	if !lineStartsAt(text, i) {
		return false
	}
	n := 0
	for i+n < len(text) && text[i+n] == '#' {
		n++
	}
	if n < 1 || n > 6 || i+n >= len(text) {
		return false
	}
	r := []rune(text[i+n:])[0]
	return jsx.IsSpace(r)
}

// rawStructuralBlocks splits on blank lines and before markdown headings:
// text.split(/\n{2,}|(?=^#{1,6}\s)/gm).
func rawStructuralBlocks(text string) []string {
	text = normalizeNewlines(text)
	var parts []string
	p := 0
	for q := 0; q < len(text); {
		if text[q] == '\n' {
			e := q
			for e < len(text) && text[e] == '\n' {
				e++
			}
			if e-q >= 2 {
				parts = append(parts, text[p:q])
				p, q = e, e
				continue
			}
		}
		if q != p && headingAt(text, q) {
			parts = append(parts, text[p:q])
			p = q
			// An empty match advances one character before the next try.
		}
		q++
	}
	parts = append(parts, text[p:])
	return trimmedBlocks(parts)
}

var (
	emailSplitLook = regexp.MustCompile(`^(?:On[` + jsx.SpaceClass + `][^\n\r\x{2028}\x{2029}]*wrote:|[` + jsx.SpaceClass + `]*>[` + jsx.SpaceClass + `]|-----Original Message-----|________________________________)`)
	codeSplitLook  = regexp.MustCompile(`^(?:export[` + jsx.SpaceClass + `]+)?(?:class|function|const|let|var|import)[` + jsx.SpaceClass + `]`)
)

// splitBeforeNewline splits text at each "\n" whose following text matches look.
func splitBeforeNewline(text string, look *regexp.Regexp) []string {
	var parts []string
	p := 0
	for q := 0; q < len(text); q++ {
		if text[q] == '\n' && look.MatchString(text[q+1:]) {
			parts = append(parts, text[p:q])
			p = q + 1
		}
	}
	return append(parts, text[p:])
}

func rawEmailBlocks(text string) []string {
	return trimmedBlocks(splitBeforeNewline(normalizeNewlines(text), emailSplitLook))
}

func rawCodeBlocks(text string) []string {
	return trimmedBlocks(splitBeforeNewline(normalizeNewlines(text), codeSplitLook))
}

type positioned struct {
	content   string
	charStart int
	charEnd   int
}

func findBlockPositions(original string, blocks []string) []positioned {
	searchFrom := 0
	out := make([]positioned, len(blocks))
	for i, block := range blocks {
		pos := jsx.IndexFrom(original, block, searchFrom)
		start := searchFrom
		if pos >= 0 {
			start = pos
		}
		end := start + jsx.Len(block)
		searchFrom = end
		out[i] = positioned{block, start, end}
	}
	return out
}

func splitOversized(p positioned) []positioned {
	length := jsx.Len(p.content)
	if length <= chunkMaxChars {
		return []positioned{{p.content, p.charStart, p.charStart + length}}
	}
	var parts []positioned
	for offset := 0; offset < length; offset += chunkMaxChars {
		slice := jsx.Slice(p.content, offset, offset+chunkMaxChars)
		n := jsx.Len(slice)
		parts = append(parts, positioned{slice, p.charStart + offset, p.charStart + offset + n})
	}
	return parts
}

func packBlocks(blocks []positioned) []positioned {
	var groups [][]positioned
	var group []positioned
	groupLen := 0
	for _, block := range blocks {
		for _, piece := range splitOversized(block) {
			add := jsx.Len(piece.content)
			if groupLen > 0 {
				add += 2
			}
			if len(group) > 0 && groupLen+add > chunkTargetChars {
				groups = append(groups, group)
				group = []positioned{piece}
				groupLen = jsx.Len(piece.content)
			} else {
				group = append(group, piece)
				groupLen += add
			}
		}
	}
	if len(group) > 0 {
		groups = append(groups, group)
	}
	chunks := make([]positioned, len(groups))
	for i, g := range groups {
		contents := make([]string, len(g))
		for j, b := range g {
			contents[j] = b.content
		}
		chunks[i] = positioned{strings.Join(contents, "\n\n"), g[0].charStart, g[len(g)-1].charEnd}
	}
	return chunks
}

// messageBlock is one message of a chat payload.
type messageBlock struct {
	content   string
	rendered  string
	messageID any
}

func firstString(o *jsx.Obj, keys ...string) string {
	values := make([]any, len(keys))
	for i, k := range keys {
		values[i] = o.Lookup(k)
	}
	return jsx.Trim(jsx.StrOr(jsx.Or(append(values, "")...)))
}

func messageBlocks(document Document) []messageBlock {
	messages, _ := document.Payload.Value("messages").([]any)
	var blocks []messageBlock
	for _, raw := range messages {
		m, ok := raw.(*jsx.Obj)
		if !ok {
			continue
		}
		speaker := firstString(m, "speaker", "role", "author")
		timestamp := firstString(m, "timestamp", "createdAt")
		content := firstString(m, "content", "text", "body")
		if content == "" {
			continue
		}
		rendered := content
		if prefix := strings.Join(nonEmpty(timestamp, speaker), " "); prefix != "" {
			rendered = prefix + "\n" + content
		}
		var id any
		if s := firstString(m, "id", "messageId"); s != "" {
			id = s
		}
		blocks = append(blocks, messageBlock{content, rendered, id})
	}
	return blocks
}

func nonEmpty(values ...string) []string {
	var out []string
	for _, v := range values {
		if v != "" {
			out = append(out, v)
		}
	}
	return out
}

func wordCount(text string) int { return len(jsx.Fields(text)) }

func normalizeSegmentType(value any) string {
	raw := jsx.Trim(jsx.StrOr(value))
	if segmentTypes[raw] {
		return raw
	}
	if alias, ok := segmentAliases[jsx.Lower(raw)]; ok {
		return alias
	}
	return "Text"
}

// normalizeNumber is Number(value) when finite, else null.
func normalizeNumber(value any) any {
	n := jsx.ToNumber(value)
	if !jsx.IsFinite(n) {
		return nil
	}
	return n
}

func numberOf(v any) (float64, bool) {
	f, ok := v.(float64)
	return f, ok
}

func normalizeBoundingBox(value any) any {
	box, ok := value.(*jsx.Obj)
	if !ok {
		return nil
	}
	left := normalizeNumber(jsx.Coalesce(box.Lookup("left"), box.Lookup("x"), box.Lookup("x1")))
	top := normalizeNumber(jsx.Coalesce(box.Lookup("top"), box.Lookup("y"), box.Lookup("y1")))

	var widthFallback any
	if x2 := box.Lookup("x2"); !jsx.Nullish(x2) && left != nil {
		l, _ := numberOf(left)
		widthFallback = jsx.ToNumber(x2) - l
	}
	width := normalizeNumber(jsx.Coalesce(box.Lookup("width"), widthFallback))
	var heightFallback any
	if y2 := box.Lookup("y2"); !jsx.Nullish(y2) && top != nil {
		t, _ := numberOf(top)
		heightFallback = jsx.ToNumber(y2) - t
	}
	height := normalizeNumber(jsx.Coalesce(box.Lookup("height"), heightFallback))
	if left == nil || top == nil || width == nil || height == nil {
		return nil
	}
	return jsx.O("left", left, "top", top, "width", width, "height", height)
}

func segmentEmbedContent(segment *jsx.Obj) string {
	for _, key := range []string{"llm", "markdown", "html", "text", "content"} {
		if text := jsx.Trim(jsx.StrOr(segment.Lookup(key))); text != "" {
			return text
		}
	}
	return ""
}

type layoutSegment struct {
	id         any
	typ        string
	content    string
	words      int
	pageNumber any
	pageWidth  any
	pageHeight any
	bbox       any
	confidence any
}

func nilIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func normalizeLayoutSegments(document Document) []layoutSegment {
	raw, _ := document.Payload.Value("segments").([]any)
	var out []layoutSegment
	for _, item := range raw {
		segment, ok := item.(*jsx.Obj)
		if !ok {
			continue
		}
		content := segmentEmbedContent(segment)
		if content == "" {
			continue
		}
		out = append(out, layoutSegment{
			id:         nilIfEmpty(jsx.Trim(jsx.StrOr(jsx.Or(segment.Lookup("id"), segment.Lookup("segmentId"), segment.Lookup("segment_id"))))),
			typ:        normalizeSegmentType(jsx.Or(segment.Lookup("type"), segment.Lookup("segmentType"), segment.Lookup("segment_type"))),
			content:    content,
			words:      wordCount(content),
			pageNumber: normalizeNumber(jsx.Coalesce(segment.Lookup("pageNumber"), segment.Lookup("page_number"))),
			pageWidth:  normalizeNumber(jsx.Coalesce(segment.Lookup("pageWidth"), segment.Lookup("page_width"))),
			pageHeight: normalizeNumber(jsx.Coalesce(segment.Lookup("pageHeight"), segment.Lookup("page_height"))),
			bbox:       normalizeBoundingBox(jsx.Or(segment.Lookup("bbox"), segment.Lookup("boundingBox"), segment.Lookup("bounding_box"))),
			confidence: normalizeNumber(segment.Lookup("confidence")),
		})
	}
	return out
}

func segmentHierarchyLevel(t string) int {
	switch t {
	case "Title":
		return 3
	case "SectionHeader":
		return 2
	}
	return 1
}

func isAssetType(t string) bool { return t == "Picture" || t == "Table" }

func hasAdjacentAssetCaptionPair(segments []layoutSegment) bool {
	for i, s := range segments {
		next := ""
		if i+1 < len(segments) {
			next = segments[i+1].typ
		}
		if (isAssetType(s.typ) && next == "Caption") || (s.typ == "Caption" && isAssetType(next)) {
			return true
		}
	}
	return false
}

func collapsedSpaces(s string) string { return jsx.ReplaceSpaceRuns(s) }

func findSegmentPosition(content, rendered string, searchOffset int) (start, end int) {
	if pos := jsx.IndexFrom(content, rendered, searchOffset); pos >= 0 {
		return pos, pos + jsx.Len(rendered)
	}
	contentLen := jsx.Len(content)
	if compact := jsx.Trim(collapsedSpaces(rendered)); compact != "" && jsx.Len(compact) <= 160 {
		if pos := jsx.IndexFrom(collapsedSpaces(content), compact, 0); pos >= 0 {
			return min(pos, contentLen), min(pos+jsx.Len(compact), contentLen)
		}
	}
	return min(searchOffset, contentLen), min(searchOffset+jsx.Len(rendered), contentLen)
}

func uniqueValues(values []any) []any {
	seen := map[any]bool{}
	out := []any{}
	for _, v := range values {
		if !seen[v] {
			seen[v] = true
			out = append(out, v)
		}
	}
	return out
}

func metadataForSegments(segments []layoutSegment, boundary string) *jsx.Obj {
	var pageNumbers, types, ids, details, boxes []any
	for _, s := range segments {
		if s.pageNumber != nil {
			pageNumbers = append(pageNumbers, s.pageNumber)
		}
		types = append(types, s.typ)
		if s.id != nil {
			ids = append(ids, s.id)
		}
		details = append(details, jsx.O("id", s.id, "type", s.typ, "pageNumber", s.pageNumber,
			"pageWidth", s.pageWidth, "pageHeight", s.pageHeight, "confidence", s.confidence))
		if s.bbox != nil {
			boxes = append(boxes, jsx.O("segmentId", s.id, "type", s.typ, "pageNumber", s.pageNumber, "bbox", s.bbox))
		}
	}
	if boundary == "layout_segments" && hasAdjacentAssetCaptionPair(segments) {
		boundary = "asset_caption_pair"
	}
	pages := uniqueValues(pageNumbers)
	return jsx.O(
		"boundary", boundary,
		"segmentTypes", uniqueValues(types),
		"segmentIds", nonNilList(ids),
		"segments", nonNilList(details),
		"pageNumbers", pages,
		"pages", pages,
		"bboxes", nonNilList(boxes),
	)
}

func nonNilList(l []any) []any {
	if l == nil {
		return []any{}
	}
	return l
}

type rawChunk struct {
	content   string
	charStart int
	charEnd   int
	metadata  *jsx.Obj
}

func chunkLayoutSegments(document Document, content string) []Chunk {
	segments := normalizeLayoutSegments(document)
	if len(segments) == 0 {
		return nil
	}
	var chunks []rawChunk
	var group []layoutSegment
	groupWords := 0
	previousLevel := 1
	searchOffset := 0

	finalize := func(boundary string) {
		if len(group) == 0 {
			return
		}
		parts := make([]string, len(group))
		for i, s := range group {
			parts[i] = s.content
		}
		rendered := strings.Join(parts, "\n\n")
		start, end := findSegmentPosition(content, rendered, searchOffset)
		searchOffset = max(searchOffset, end)
		metadata := metadataForSegments(group, boundary)
		for _, part := range splitOversized(positioned{rendered, start, 0}) {
			chunks = append(chunks, rawChunk{part.content, part.charStart, min(part.charEnd, end), metadata})
		}
		group, groupWords = nil, 0
	}

	for i, segment := range segments {
		if segment.typ == "PageHeader" || segment.typ == "PageFooter" {
			continue
		}
		level := segmentHierarchyLevel(segment.typ)
		if segment.typ == "Title" || segment.typ == "SectionHeader" {
			if len(group) > 0 && level > previousLevel {
				finalize("section")
			}
			group = append(group, segment)
			groupWords += segment.words
			previousLevel = level
			continue
		}

		nextType := ""
		if i+1 < len(segments) {
			nextType = segments[i+1].typ
		}
		keepWithNext := false
		if isAssetType(segment.typ) {
			keepWithNext = nextType == "Caption"
		} else if segment.typ == "Caption" {
			keepWithNext = isAssetType(nextType)
		}
		pairedWords := segment.words
		if keepWithNext {
			pairedWords += segments[i+1].words
		}
		if len(group) > 0 && groupWords+pairedWords > targetSegmentWords {
			finalize("layout_segments")
		}
		group = append(group, segment)
		groupWords += segment.words
		if groupWords > targetSegmentWords && !keepWithNext {
			finalize("layout_segments")
		}
		previousLevel = level
	}
	finalize("layout_segments")

	out := make([]Chunk, len(chunks))
	for i, c := range chunks {
		out[i] = Chunk{i, c.charStart, c.charEnd, c.content, contentHash(c.content), c.metadata}
	}
	return out
}

// ChunkDocument splits a document into chunks that keep their source
// structure: layout segments, chat messages, mail quotes, code blocks, or
// paragraphs.
func ChunkDocument(document Document) []Chunk {
	content := jsx.Trim(document.Content)
	if content == "" {
		return nil
	}
	if chunks := chunkLayoutSegments(document, content); chunks != nil {
		return chunks
	}

	if messages := messageBlocks(document); len(messages) > 0 {
		searchOffset := 0
		contentLen := jsx.Len(content)
		chunks := make([]Chunk, len(messages))
		for i, m := range messages {
			start := jsx.IndexFrom(content, m.content, searchOffset)
			if start < 0 {
				start = searchOffset
			}
			end := min(contentLen, start+jsx.Len(m.content))
			searchOffset = end
			chunks[i] = Chunk{i, start, end, m.rendered, contentHash(m.rendered),
				jsx.O("boundary", "message", "messageId", m.messageID)}
		}
		return chunks
	}

	sourceType := jsx.Lower(jsx.StrOr(jsx.Or(document.SourceType, document.NormalizedType)))
	title := jsx.Lower(document.Title)

	var blocks []string
	var boundary string
	switch {
	case strings.Contains(sourceType, "email") || strings.HasSuffix(title, ".eml") || strings.Contains(title, "message"):
		blocks, boundary = rawEmailBlocks(content), "email_thread"
	case strings.Contains(sourceType, "code") || strings.HasSuffix(title, ".js") || strings.HasSuffix(title, ".ts") ||
		strings.HasSuffix(title, ".py") || strings.HasSuffix(title, ".java"):
		blocks, boundary = rawCodeBlocks(content), "code_structure"
	default:
		blocks, boundary = rawStructuralBlocks(content), "structural"
	}

	packed := packBlocks(findBlockPositions(content, blocks))
	chunks := make([]Chunk, len(packed))
	for i, c := range packed {
		chunks[i] = Chunk{i, c.charStart, c.charEnd, c.content, contentHash(c.content), jsx.O("boundary", boundary)}
	}
	return chunks
}
