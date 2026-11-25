package email

import (
	"strings"

	"github.com/NeoLabs-Systems/neoagent/internal/ai/dyn"
)

// server is an IMAP or SMTP endpoint; secure is implicit TLS, otherwise
// STARTTLS is required.
type server struct {
	Host   string `json:"host"`
	Port   int    `json:"port"`
	Secure bool   `json:"secure"`
}

// preset is a mail provider the setup dialog offers.
type preset struct {
	id, label, icon     string
	imap, smtp          server
	savesSentMail       bool
	caldavURL           string
	carddavURL          string
	passwordURL         string
	help                string
	custom, feed        bool
	unsupported         bool
	alternativeProvider string
}

var presets = []preset{
	{id: "gmail", label: "Gmail", icon: "google",
		imap: server{"imap.gmail.com", 993, true}, smtp: server{"smtp.gmail.com", 465, true}, savesSentMail: true,
		passwordURL: "https://myaccount.google.com/apppasswords",
		help:        "Turn on 2-Step Verification for your Google account, then create an app password named NeoAgent. For Google Calendar, add a Calendar link with its secret iCal address."},
	{id: "icloud", label: "iCloud", icon: "apple",
		imap: server{"imap.mail.me.com", 993, true}, smtp: server{"smtp.mail.me.com", 587, false},
		caldavURL: "https://caldav.icloud.com", carddavURL: "https://contacts.icloud.com",
		passwordURL: "https://account.apple.com/account/manage",
		help:        "Under Sign-In and Security, choose App-Specific Passwords and create one named NeoAgent. Use your Apple Account email address."},
	{id: "fastmail", label: "Fastmail", icon: "mail",
		imap: server{"imap.fastmail.com", 993, true}, smtp: server{"smtp.fastmail.com", 465, true},
		caldavURL: "https://caldav.fastmail.com", carddavURL: "https://carddav.fastmail.com",
		passwordURL: "https://www.fastmail.help/hc/en-us/articles/360058752854-App-passwords",
		help:        "Create an app password with access to mail, calendars and contacts."},
	{id: "yahoo", label: "Yahoo Mail", icon: "mail",
		imap: server{"imap.mail.yahoo.com", 993, true}, smtp: server{"smtp.mail.yahoo.com", 465, true},
		passwordURL: "https://login.yahoo.com/account/security",
		help:        "Under Account Security, choose Generate app password and name it NeoAgent."},
	{id: "outlook", label: "Outlook / Microsoft 365", icon: "microsoft", unsupported: true, alternativeProvider: "microsoft_365",
		help: "Microsoft no longer accepts app passwords for mail. Connect it through the Microsoft 365 integration instead, or add your Outlook calendar as a Calendar link."},
	{id: "ical", label: "Calendar link (iCal)", icon: "calendar", feed: true,
		help: "Paste a calendar's iCal address to let the agent read it. Google Calendar: Settings › your calendar › Integrate calendar › Secret address in iCal format. Outlook: Settings › Calendar › Shared calendars › Publish a calendar, then the ICS link. iCloud: share the calendar as a Public Calendar. The agent can read it but not change it."},
	{id: "custom", label: "Other provider", icon: "mail", custom: true,
		help: "Enter the IMAP and SMTP servers from your provider. Calendar and contacts are optional and need CalDAV or CardDAV URLs."},
}

func findPreset(id any) *preset {
	key := strings.TrimSpace(dyn.Str(id))
	for i := range presets {
		if presets[i].id == key {
			return &presets[i]
		}
	}
	return nil
}

func orNull(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// forClient is a preset as the setup dialog lists it.
func (p preset) forClient() dyn.Ordered {
	return dyn.Ordered{
		{Key: "id", Value: p.id}, {Key: "label", Value: p.label}, {Key: "icon", Value: p.icon}, {Key: "help", Value: p.help},
		{Key: "passwordUrl", Value: orNull(p.passwordURL)}, {Key: "custom", Value: p.custom}, {Key: "feed", Value: p.feed},
		{Key: "unsupported", Value: p.unsupported}, {Key: "alternativeProvider", Value: orNull(p.alternativeProvider)},
		{Key: "calendar", Value: p.custom || p.caldavURL != ""}, {Key: "contacts", Value: p.custom || p.carddavURL != ""},
	}
}
