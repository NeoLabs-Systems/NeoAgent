package socialvideo

// captionLanguages are the caption languages tried first, per platform.
func captionLanguages(platform string) []string {
	if platform == "youtube" {
		return []string{"en", "en-us", "en-gb"}
	}
	return []string{"en", "en-us"}
}
