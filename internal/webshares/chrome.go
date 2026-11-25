package webshares

import (
	"regexp"
	"strings"
)

// What the server adds around a shared page (page_chrome.js): the notice that
// a NeoAgent user made it, and the page shown while it cannot be reached.
// Both work without JavaScript.

const (
	noticeCookie   = "neoagent_share_notice"
	hideNoticePath = "/.neoagent/hide-notice"
)

var htmlEscaper = strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;", "'", "&#39;")

func escapeHTML(s string) string { return htmlEscaper.Replace(s) }

func noticeHidden(cookieHeader string) bool {
	for _, part := range strings.Split(cookieHeader, ";") {
		if strings.TrimSpace(part) == noticeCookie+"=hidden" {
			return true
		}
	}
	return false
}

func noticeMarkup(username, prefix, returnPath string) string {
	href := prefix + hideNoticePath + "?back=" + encodeComponent(returnPath)
	return strings.NewReplacer("@@USER@@", escapeHTML(username), "@@HREF@@", escapeHTML(href)).Replace(noticeTemplate)
}

var bodyTag = regexp.MustCompile(`(?i)<body\b[^>]*>`)

// injectNotice puts the notice right after <body>, or first.
func injectNotice(html, notice string) string {
	if loc := bodyTag.FindStringIndex(html); loc != nil {
		return html[:loc[1]] + notice + html[loc[1]:]
	}
	return notice + html
}

func offlinePage(username, title string) string {
	return strings.NewReplacer("@@USER@@", escapeHTML(username), "@@TITLE@@", escapeHTML(title)).Replace(offlineTemplate)
}
