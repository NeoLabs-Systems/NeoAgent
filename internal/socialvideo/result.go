package socialvideo

// ResultError is one failure noted in a result.
type ResultError struct {
	Code    string `json:"code,omitempty"`
	Message string `json:"message"`
}

// Result is what extracting a video link returns. Field order is the order
// the Node server wrote its keys in.
type Result struct {
	SourceURL        string        `json:"sourceUrl"`
	ResolvedURL      string        `json:"resolvedUrl"`
	CanonicalURL     *string       `json:"canonicalUrl"`
	Platform         string        `json:"platform"`
	Title            string        `json:"title"`
	Description      string        `json:"description"`
	Transcript       string        `json:"transcript"`
	TranscriptSource string        `json:"transcriptSource"`
	FrameImage       *FrameImage   `json:"frameImage"`
	Metadata         any           `json:"metadata"`
	Setup            *Health       `json:"setup"`
	Warnings         []string      `json:"warnings"`
	Errors           []ResultError `json:"errors"`
	Partial          bool          `json:"partial"`
}

// Metadata describes the extractor run.
type Metadata struct {
	Provider        string   `json:"provider"`
	DurationSeconds *float64 `json:"durationSeconds"`
	VideoID         *string  `json:"videoId"`
}

// shape trims and defaults the way the Node result shaper did.
func shape(r Result) Result {
	r.SourceURL = jsTrim(r.SourceURL)
	r.ResolvedURL = jsTrim(r.ResolvedURL)
	if r.CanonicalURL != nil {
		c := jsTrim(*r.CanonicalURL)
		if c == "" {
			r.CanonicalURL = nil
		} else {
			r.CanonicalURL = &c
		}
	}
	if r.Platform = jsTrim(r.Platform); r.Platform == "" {
		r.Platform = "unknown"
	}
	r.Title, r.Description, r.Transcript = jsTrim(r.Title), jsTrim(r.Description), jsTrim(r.Transcript)
	if r.TranscriptSource = jsTrim(r.TranscriptSource); r.TranscriptSource == "" {
		r.TranscriptSource = "unavailable"
	}
	if r.FrameImage != nil && (r.FrameImage.URL == nil || *r.FrameImage.URL == "") {
		// Node dropped a frame reference without a url.
		r.FrameImage = nil
	}
	if r.Metadata == nil {
		r.Metadata = map[string]any{}
	}
	warnings := []string{}
	for _, w := range r.Warnings {
		if w = jsTrim(w); w != "" {
			warnings = append(warnings, w)
		}
	}
	errs := []ResultError{}
	for _, e := range r.Errors {
		if e.Message = jsTrim(e.Message); e.Message != "" {
			errs = append(errs, e)
		}
	}
	r.Warnings, r.Errors = warnings, errs
	r.Partial = len(warnings) > 0 || len(errs) > 0
	return r
}
