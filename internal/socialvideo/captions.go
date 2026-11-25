package socialvideo

import (
	"encoding/json"

	"fmt"
	"regexp"
	"strings"
)

// MaxVTTBytes bounds a caption file.
const MaxVTTBytes = 2 * 1024 * 1024

// CaptionTrack is one downloadable caption file.
type CaptionTrack struct {
	Language string
	URL      string
	Ext      string
	Name     string
}

// CaptionGroup is the caption files yt-dlp lists for one language, in the
// order yt-dlp listed them (ties are broken by that order).
type CaptionGroup struct {
	Language string
	Items    []CaptionTrack
}

func normalizeLanguageCode(v string) string { return strings.ToLower(jsTrim(v)) }

// decodeCaptionGroups reads yt-dlp's {language: [{url, ext, name}]} object
// keeping the order of its keys.
func decodeCaptionGroups(raw json.RawMessage) []CaptionGroup {
	if len(raw) == 0 {
		return nil
	}
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	if tok, err := dec.Token(); err != nil || tok != json.Delim('{') {
		return nil
	}
	var groups []CaptionGroup
	for dec.More() {
		keyTok, err := dec.Token()
		if err != nil {
			return groups
		}
		var items []json.RawMessage
		var value json.RawMessage
		if err := dec.Decode(&value); err != nil {
			return groups
		}
		if json.Unmarshal(value, &items) != nil {
			continue
		}
		group := CaptionGroup{Language: keyTok.(string)}
		for _, item := range items {
			var fields map[string]any
			if json.Unmarshal(item, &fields) != nil || fields == nil {
				continue
			}
			group.Items = append(group.Items, CaptionTrack{
				URL:  jsTrim(jsText(fields["url"])),
				Ext:  jsText(fields["ext"]),
				Name: jsTrim(jsText(fields["name"])),
			})
		}
		groups = append(groups, group)
	}
	return groups
}

// jsText is String(value || ”).
func jsText(v any) string {
	switch v := v.(type) {
	case nil:
		return ""
	case string:
		return v
	case bool:
		if v {
			return "true"
		}
		return ""
	case float64:
		if v == 0 {
			return ""
		}
		return fmt.Sprint(v)
	}
	return "[object Object]"
}

// PickCaptionTrack chooses the track in the preferred language and format.
func PickCaptionTrack(groups []CaptionGroup, preferred []string) *CaptionTrack {
	var tracks []CaptionTrack
	for _, g := range groups {
		for _, item := range g.Items {
			if item.URL == "" {
				continue
			}
			tracks = append(tracks, CaptionTrack{
				Language: normalizeLanguageCode(g.Language), URL: item.URL,
				Ext: normalizeLanguageCode(item.Ext), Name: item.Name,
			})
		}
	}
	if len(tracks) == 0 {
		return nil
	}
	var order []string
	for _, p := range preferred {
		if c := normalizeLanguageCode(p); c != "" {
			order = append(order, c)
		}
	}
	if len(order) == 0 {
		order = []string{"en", "en-us", "en-gb"}
	}
	exts := []string{"vtt", "webvtt", "srt", "json3", "ttml", "xml", "json"}
	score := func(t CaptionTrack) int {
		lang, ext := 999, 999
		for i, code := range order {
			if t.Language == code || strings.HasPrefix(t.Language, code+"-") {
				lang = i
				break
			}
		}
		for i, e := range exts {
			if t.Ext == e {
				ext = i
				break
			}
		}
		return lang*100 + ext
	}
	best := 0
	for i := range tracks {
		if score(tracks[i]) < score(tracks[best]) {
			best = i
		}
	}
	return &tracks[best]
}

var (
	cueTagRe    = regexp.MustCompile(`\{\\an\d+\}`)
	bracketRe   = regexp.MustCompile(`\[[^\]]+\]`)
	nbspRe      = regexp.MustCompile(`&nbsp;`)
	vttHeaderRe = regexp.MustCompile(`(?i)^WEBVTT`)
	noteRe      = regexp.MustCompile(`(?i)^NOTE\b`)
	cueNumberRe = regexp.MustCompile(`^\d+$`)
	cueTimeRe   = regexp.MustCompile(`^\d{2}:\d{2}:\d{2}[.,]\d{3}[` + jsSpace + `]+-->`)
	cueShortRe  = regexp.MustCompile(`^\d{2}:\d{2}[.,]\d{3}[` + jsSpace + `]+-->`)
	paragraphRe = regexp.MustCompile(`(?is)<p\b[^>]*>(.*?)</p>`)
	ttmlRootRe  = regexp.MustCompile(`(?i)^[` + jsSpace + `]*<tt\b`)
	ttmlNSRe    = regexp.MustCompile(`(?i)xmlns[` + jsSpace + `]*=[` + jsSpace + `]*["'][^"']*ttml`)
	lineBreakRe = regexp.MustCompile(`\r?\n`)
	xmlEntities = []struct {
		re *regexp.Regexp
		to string
	}{
		{regexp.MustCompile(`(?i)&nbsp;`), " "}, {regexp.MustCompile(`(?i)&amp;`), "&"},
		{regexp.MustCompile(`(?i)&lt;`), "<"}, {regexp.MustCompile(`(?i)&gt;`), ">"},
		{regexp.MustCompile(`(?i)&quot;`), `"`}, {regexp.MustCompile(`&#39;`), "'"},
	}
)

func stripTags(text string) string {
	text = tagRe.ReplaceAllString(text, " ")
	text = cueTagRe.ReplaceAllString(text, " ")
	text = bracketRe.ReplaceAllString(text, " ")
	text = nbspRe.ReplaceAllString(text, " ")
	text = strings.ReplaceAll(text, "&amp;", "&")
	return collapseWhitespace(text)
}

func stripXML(text string) string {
	text = tagRe.ReplaceAllString(text, " ")
	for _, e := range xmlEntities {
		text = e.re.ReplaceAllString(text, e.to)
	}
	return collapseWhitespace(text)
}

func appendDistinct(chunks []string, text string) []string {
	if text == "" || (len(chunks) > 0 && chunks[len(chunks)-1] == text) {
		return chunks
	}
	return append(chunks, text)
}

// ParseWebVTT reduces a WebVTT file to its spoken text.
func ParseWebVTT(vtt string) (string, error) {
	if len(vtt) > MaxVTTBytes {
		return "", fmt.Errorf("parseWebVttToText input exceeds MAX_VTT_BYTES (%d).", MaxVTTBytes)
	}
	var chunks []string
	for _, line := range lineBreakRe.Split(vtt, -1) {
		clean := jsTrim(line)
		switch {
		case clean == "", vttHeaderRe.MatchString(clean), noteRe.MatchString(clean),
			cueNumberRe.MatchString(clean), cueTimeRe.MatchString(clean), cueShortRe.MatchString(clean):
			continue
		}
		chunks = appendDistinct(chunks, stripTags(clean))
	}
	return jsTrim(strings.Join(chunks, " ")), nil
}

func parseSRT(srt string) (string, error) {
	return ParseWebVTT(strings.ReplaceAll(srt, ",", "."))
}

func parseJSON3(raw string) string {
	if len(raw) > MaxVTTBytes {
		return ""
	}
	var payload struct {
		Events []struct {
			Segs []struct {
				UTF8 any `json:"utf8"`
			} `json:"segs"`
		} `json:"events"`
	}
	if json.Unmarshal([]byte(raw), &payload) != nil {
		return ""
	}
	var parts []string
	for _, event := range payload.Events {
		var texts []string
		for _, seg := range event.Segs {
			if t := jsTrim(jsText(seg.UTF8)); t != "" {
				texts = append(texts, t)
			}
		}
		parts = appendDistinct(parts, stripTags(strings.Join(texts, " ")))
	}
	return jsTrim(strings.Join(parts, " "))
}

func parseTTML(raw string) string {
	if len(raw) > MaxVTTBytes {
		return ""
	}
	var parts []string
	for _, m := range paragraphRe.FindAllStringSubmatch(raw, -1) {
		parts = appendDistinct(parts, stripXML(m[1]))
	}
	if len(parts) > 0 {
		return jsTrim(strings.Join(parts, " "))
	}
	return stripXML(raw)
}

// ParseCaptionText reads a caption file of the given extension.
func ParseCaptionText(raw, extension string) (string, error) {
	switch ext := normalizeLanguageCode(extension); ext {
	case "vtt", "webvtt":
		return ParseWebVTT(raw)
	case "ttml", "xml":
		return parseTTML(raw), nil
	case "srt":
		return parseSRT(raw)
	case "json3", "json":
		return parseJSON3(raw), nil
	}
	if ttmlRootRe.MatchString(raw) || ttmlNSRe.MatchString(raw) {
		return parseTTML(raw), nil
	}
	return ParseWebVTT(raw)
}

// TranscriptDecision says where the transcript comes from.
type TranscriptDecision struct{ Mode, Reason string }

func decideTranscriptPath(forceSTT bool, track *CaptionTrack) TranscriptDecision {
	switch {
	case forceSTT:
		return TranscriptDecision{"stt", "forced"}
	case track != nil:
		return TranscriptDecision{"captions", "captions_present"}
	}
	return TranscriptDecision{"stt", "captions_missing"}
}
