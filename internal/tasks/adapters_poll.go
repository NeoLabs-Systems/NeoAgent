package tasks

import (
	"errors"
	"fmt"
	"math"
	"net/url"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/NeoLabs-Systems/neoagent/internal/tasks/jsv"
)

// The integration triggers look at a connected account every few minutes
// through the integration's own tools and turn what is new into rows.

// newsCategories are the headline categories the news integration serves.
var newsCategories = []string{"general", "world", "nation", "business", "technology", "entertainment", "sports", "science", "health"}

func args(pairs ...any) *jsv.Object {
	o := jsv.NewObject()
	for i := 0; i+1 < len(pairs); i += 2 {
		o.Set(pairs[i].(string), pairs[i+1])
	}
	return o
}

// event wraps a trigger event in the context a run is given.
func event(provider string, pairs ...any) *jsv.Object {
	return jsv.NewObject().Set("triggerEvent", args(append([]any{"provider", provider}, pairs...)...))
}

func stampOrNow(v any, now time.Time) string {
	if jsv.Truthy(v) {
		return jsv.String(v)
	}
	return jsv.ISO(now)
}

// every is a poll that looks each minute.
func every(minutes float64) func(*jsv.Object) float64 {
	return func(*jsv.Object) float64 { return minutes }
}

// ---- email and chat ---------------------------------------------------------

var gmailAdapter = Adapter{
	Type: "gmail_message_received", Label: "Gmail Message Received", ProviderKey: "google_workspace", AppKey: "gmail",
	ConfigHint: "{ connectionId, query?: Gmail search, unreadOnly?: boolean }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "google_workspace", "gmail", func(out *jsv.Object) error {
			out.Set("query", trimText(config.Val("query"), 500)).Set("unreadOnly", normalizeBoolean(coalesce(config, "unreadOnly", "unread_only"), false))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Gmail", config.Val("accountEmail"), when(config.Val("query"), "query: "+str(config.Val("query"))), when(config.Val("unreadOnly"), "unread only"))
	},
	Poll: &Poll{
		IntervalMinutes: every(1), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			var parts []string
			if q := config.Val("query"); jsv.Truthy(q) {
				parts = append(parts, jsv.String(q))
			}
			if config.Val("unreadOnly") == true {
				parts = append(parts, "is:unread")
			}
			var q any
			if text := jsv.Trim(strings.Join(parts, " ")); text != "" {
				q = text
			}
			result, err := tool("google_workspace_gmail_api_request", args("method", "GET", "path", "/gmail/v1/users/me/messages",
				"query", args("maxResults", 20.0, "q", q)))
			if err != nil {
				return nil, err
			}
			var rows []Row
			// The raw API request returns the HTTP response: { status, data }.
			for _, item := range objects(dig(result, "data", "messages")) {
				rows = append(rows, Row{
					Fingerprint: fmt.Sprintf("gmail:%s:%s", idText(config.Val("connectionId")), idText(item.Val("id"))),
					Timestamp:   jsv.ISO(now),
					Context:     event("gmail", "messageId", item.Val("id"), "threadId", orNil(item.Val("threadId"))),
				})
			}
			return sortRows(rows, byFingerprint), nil
		},
	},
}

var outlookEmailAdapter = Adapter{
	Type: "outlook_email_received", Label: "Outlook Email Received", ProviderKey: "microsoft_365", AppKey: "outlook",
	ConfigHint: "{ connectionId, folderId?, query?: search text, unreadOnly?: boolean }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "microsoft_365", "outlook", func(out *jsv.Object) error {
			out.Set("folderId", trimText(pick(config, "folderId", "folder_id"), 160)).Set("query", trimText(config.Val("query"), 500)).
				Set("unreadOnly", normalizeBoolean(coalesce(config, "unreadOnly", "unread_only"), false))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Outlook", config.Val("accountEmail"), when(config.Val("folderId"), "folder: "+str(config.Val("folderId"))),
			when(config.Val("query"), "query: "+str(config.Val("query"))), when(config.Val("unreadOnly"), "unread only"))
	},
	Poll: &Poll{
		IntervalMinutes: every(1), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("microsoft_365_outlook_list_messages", args("folder_id", orNil(config.Val("folderId")),
				"query", orNil(config.Val("query")), "top", 20.0))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, item := range objects(listFrom(result, "value")) {
				if config.Val("unreadOnly") == true && item.Val("isRead") != false {
					continue
				}
				rows = append(rows, Row{
					Fingerprint: fmt.Sprintf("outlook:%s:%s", idText(config.Val("connectionId")), idText(item.Val("id"))),
					Timestamp:   stampOrNow(item.Val("receivedDateTime"), now),
					Context: event("outlook", "messageId", item.Val("id"), "subject", textOrEmpty(item.Val("subject")),
						"from", orNil(dig(item, "from", "emailAddress", "address"))),
				})
			}
			return sortRows(rows, byTimestamp), nil
		},
	},
}

var slackAdapter = Adapter{
	Type: "slack_message_received", Label: "Slack Message Received", ProviderKey: "slack", AppKey: "slack",
	ConfigHint: "{ connectionId, channel: channel ID, sender?: user ID }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "slack", "slack", func(out *jsv.Object) error {
			channel, err := requiredText(config.Val("channel"), 160, "Slack channel is required.")
			if err != nil {
				return err
			}
			out.Set("channel", channel).Set("sender", trimText(config.Val("sender"), 160))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Slack", config.Val("accountEmail"), config.Val("channel"), when(config.Val("sender"), "sender: "+str(config.Val("sender"))))
	},
	Poll: &Poll{
		IntervalMinutes: every(1), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("slack_get_conversation_history", args("channel", config.Val("channel"), "limit", 20.0))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, item := range objects(listFrom(result, "messages")) {
				if sender := config.Val("sender"); jsv.Truthy(sender) && jsv.Text(item.Val("user")) != jsv.String(sender) {
					continue
				}
				messageID := item.Val("client_msg_id")
				if !jsv.Truthy(messageID) {
					messageID = item.Val("ts")
				}
				rows = append(rows, Row{
					Fingerprint: fmt.Sprintf("slack:%s:%s:%s", idText(config.Val("connectionId")), idText(config.Val("channel")), idText(item.Val("ts"))),
					Timestamp:   stampOrNow(item.Val("ts"), now),
					Context: event("slack", "channel", config.Val("channel"), "sender", orNil(item.Val("user")),
						"messageId", messageID, "content", textOrEmpty(item.Val("text"))),
				})
			}
			return sortRows(rows, byTimestamp), nil
		},
	},
}

var teamsAdapter = Adapter{
	Type: "teams_message_received", Label: "Teams Message Received", ProviderKey: "microsoft_365", AppKey: "teams",
	ConfigHint: "{ connectionId, chatId, sender?: user ID }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "microsoft_365", "teams", func(out *jsv.Object) error {
			chat, err := requiredText(pick(config, "chatId", "chat_id"), 200, "Teams chat ID is required.")
			if err != nil {
				return err
			}
			out.Set("chatId", chat).Set("sender", trimText(config.Val("sender"), 200))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Teams", config.Val("accountEmail"), when(config.Val("chatId"), "chat: "+str(config.Val("chatId"))),
			when(config.Val("sender"), "sender: "+str(config.Val("sender"))))
	},
	Poll: &Poll{
		IntervalMinutes: every(1), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("microsoft_365_teams_list_chat_messages", args("chat_id", config.Val("chatId"), "top", 20.0))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, item := range objects(listFrom(result, "value")) {
				who := dig(item, "from", "user", "id")
				if !jsv.Truthy(who) {
					who = dig(item, "from", "application", "id")
				}
				if want := config.Val("sender"); jsv.Truthy(want) && jsv.Text(who) != jsv.String(want) {
					continue
				}
				rows = append(rows, Row{
					Fingerprint: fmt.Sprintf("teams:%s:%s:%s", idText(config.Val("connectionId")), idText(config.Val("chatId")), idText(item.Val("id"))),
					Timestamp:   stampOrNow(item.Val("createdDateTime"), now),
					Context: event("teams", "chatId", config.Val("chatId"), "messageId", item.Val("id"),
						"sender", orNil(dig(item, "from", "user", "id")), "content", textOrEmpty(dig(item, "body", "content"))),
				})
			}
			return sortRows(rows, byTimestamp), nil
		},
	},
}

// ---- calendars ---------------------------------------------------------------

// catchUp is how old a reminder that came due while the server was briefly
// away may be and still go out.
const catchUp = 10 * time.Minute

func minutesBefore(config *jsv.Object) float64 {
	return float64(boundedInteger(coalesce(config, "minutesBefore", "minutes_before"), 10, 0, 1440))
}

// startingPoll is the poll of the calendar triggers: it asks for the events
// whose reminder time falls in the catch-up window up to now. The cursor is
// the reminder time, so each event fires once, in order.
func startingPoll(provider string, fetch func(tool ToolFunc, config *jsv.Object, start, end string) ([]any, error)) *Poll {
	return &Poll{
		IntervalMinutes: every(1), Cursor: "ordered", Baseline: "now",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			lead := time.Duration(jsv.Number(config.Val("minutesBefore"))) * time.Minute
			events, err := fetch(tool, config, jsv.ISO(now.Add(lead-catchUp)), jsv.ISO(now.Add(lead+time.Minute)))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, ev := range objects(events) {
				start := jsv.Text(ev.Val("start"))
				if jsv.Truthy(ev.Val("allDay")) || !strings.Contains(start, "T") {
					continue
				}
				startAt, ok := jsv.ParseDate(start)
				if !ok {
					continue
				}
				remindAt := startAt.Add(-lead)
				if remindAt.After(now) {
					continue
				}
				rows = append(rows, Row{
					Fingerprint: timeCursor(float64(remindAt.UnixMilli()), ev.Val("id")),
					Timestamp:   jsv.ISO(startAt),
					Context: event(provider, "event", "calendar_event_starting", "eventId", ev.Val("id"), "title", textOrEmpty(ev.Val("summary")),
						"start", ev.Val("start"), "end", orNil(ev.Val("end")), "location", orNil(ev.Val("location")),
						"url", orNil(ev.Val("htmlLink")), "minutesBefore", config.Val("minutesBefore")),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	}
}

var googleCalendarStartingAdapter = Adapter{
	Type: "google_calendar_event_starting", Label: "Google Calendar Event Starting", ProviderKey: "google_workspace", AppKey: "calendar",
	ConfigHint: "{ connectionId, minutesBefore?: 0-1440 (default 10), calendarId?: default primary }; all-day events are skipped",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "google_workspace", "calendar", func(out *jsv.Object) error {
			out.Set("calendarId", trimText(pick(config, "calendarId", "calendar_id"), 300)).Set("minutesBefore", minutesBefore(config))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Google Calendar", jsv.String(config.Val("minutesBefore"))+" min before events", config.Val("calendarId"))
	},
	Poll: startingPoll("google_calendar", func(tool ToolFunc, config *jsv.Object, start, end string) ([]any, error) {
		result, err := tool("google_workspace_calendar_list_events", args("calendar_id", orNil(config.Val("calendarId")),
			"time_min", start, "time_max", end, "max_results", 20.0))
		list, _ := dig(result, "upcomingTimedEvents").([]any)
		return list, err
	}),
}

var googleCalendarCreatedAdapter = Adapter{
	Type: "google_calendar_event_created", Label: "Google Calendar Event Created", ProviderKey: "google_workspace", AppKey: "calendar",
	ConfigHint: "{ connectionId, calendarId?: default primary, invitesOnly?: only events someone else organizes }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "google_workspace", "calendar", func(out *jsv.Object) error {
			out.Set("calendarId", trimText(pick(config, "calendarId", "calendar_id"), 300)).
				Set("invitesOnly", normalizeBoolean(coalesce(config, "invitesOnly", "invites_only"), false))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Google Calendar new events", config.Val("calendarId"), when(config.Val("invitesOnly"), "invites only"))
	},
	Poll: &Poll{
		IntervalMinutes: every(5), Cursor: "ordered", Baseline: "now",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			updatedMin := jsv.ISO(now.Add(-60 * time.Minute))
			calendar := jsv.Text(config.Val("calendarId"))
			if calendar == "" {
				calendar = "primary"
			}
			response, err := tool("google_workspace_calendar_api_request", args("method", "GET",
				"path", "/calendar/v3/calendars/"+encodeURIComponent(calendar)+"/events",
				"query", args("updatedMin", updatedMin, "orderBy", "updated", "showDeleted", false, "maxResults", 100.0)))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, item := range objects(dig(response, "data", "items")) {
				// Recently updated includes edits; only events created in the window are new.
				if item.Val("status") == "cancelled" || jsv.Text(item.Val("created")) < updatedMin {
					continue
				}
				if config.Val("invitesOnly") == true && dig(item, "organizer", "self") == true {
					continue
				}
				start := orNil(dig(item, "start", "dateTime"))
				if start == nil {
					start = orNil(dig(item, "start", "date"))
				}
				end := orNil(dig(item, "end", "dateTime"))
				if end == nil {
					end = orNil(dig(item, "end", "date"))
				}
				rows = append(rows, Row{
					Fingerprint: timeCursor(item.Val("created"), item.Val("id")), Timestamp: str(item.Val("created")),
					Context: event("google_calendar", "event", "calendar_event_created", "eventId", item.Val("id"),
						"title", textOrEmpty(item.Val("summary")), "start", start, "end", end, "location", orNil(item.Val("location")),
						"organizer", orNil(dig(item, "organizer", "email")), "url", orNil(item.Val("htmlLink"))),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

var outlookCalendarStartingAdapter = Adapter{
	Type: "outlook_calendar_event_starting", Label: "Outlook Calendar Event Starting", ProviderKey: "microsoft_365", AppKey: "calendar",
	ConfigHint: "{ connectionId, minutesBefore?: 0-1440 (default 10) }; all-day events are skipped",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "microsoft_365", "calendar", func(out *jsv.Object) error {
			out.Set("minutesBefore", minutesBefore(config))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Outlook Calendar", jsv.String(config.Val("minutesBefore"))+" min before events")
	},
	Poll: startingPoll("outlook_calendar", func(tool ToolFunc, config *jsv.Object, start, end string) ([]any, error) {
		result, err := tool("microsoft_365_calendar_list_events", args("start", start, "end", end, "top", 20.0))
		list, _ := dig(result, "upcomingTimedEvents").([]any)
		return list, err
	}),
}

var nextcloudCalendarStartingAdapter = Adapter{
	Type: "nextcloud_calendar_event_starting", Label: "Nextcloud Calendar Event Starting", ProviderKey: "nextcloud", AppKey: "calendar",
	ConfigHint: "{ connectionId, calendar: path from nextcloud_list_calendars, minutesBefore?: 0-1440 (default 10) }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "nextcloud", "calendar", func(out *jsv.Object) error {
			calendar, err := requiredText(config.Val("calendar"), 300, "Nextcloud calendar is required.")
			if err != nil {
				return err
			}
			out.Set("calendar", calendar).Set("minutesBefore", minutesBefore(config))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Nextcloud Calendar", config.Val("calendar"), jsv.String(config.Val("minutesBefore"))+" min before events")
	},
	Poll: startingPoll("nextcloud_calendar", func(tool ToolFunc, config *jsv.Object, start, end string) ([]any, error) {
		result, err := tool("nextcloud_list_events", args("calendar", config.Val("calendar"), "start", start, "end", end))
		if err != nil {
			return nil, err
		}
		var out []any
		for _, ev := range objects(listFrom(result)) {
			// Each occurrence of a recurring event shares its UID.
			id := pick(ev, "uid", "path")
			label := jsv.Text(id)
			if jsv.Truthy(ev.Val("recurrenceId")) {
				label += "@" + jsv.String(ev.Val("recurrenceId"))
			}
			out = append(out, ev.Clone().Set("id", label))
		}
		return out, nil
	}),
}

// ---- files and documents -----------------------------------------------------

var drivePattern = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

var googleDriveAdapter = Adapter{
	Type: "google_drive_file_added", Label: "Google Drive File Added", ProviderKey: "google_workspace", AppKey: "drive",
	ConfigHint: "{ connectionId, folderId?: Drive folder ID, otherwise anywhere in Drive }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		folder := trimText(pick(config, "folderId", "folder_id"), 200)
		if folder != "" && !drivePattern.MatchString(folder) {
			return nil, errors.New("Google Drive folder ID is not valid.")
		}
		return vc.withConnection(config, "google_workspace", "drive", func(out *jsv.Object) error {
			out.Set("folderId", folder)
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Google Drive new files", when(config.Val("folderId"), "folder: "+str(config.Val("folderId"))))
	},
	Poll: &Poll{
		IntervalMinutes: every(5), Cursor: "ordered", Baseline: "now",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, _ time.Time) ([]Row, error) {
			query := "trashed = false"
			if folder := config.Val("folderId"); jsv.Truthy(folder) {
				query = "'" + jsv.String(folder) + "' in parents and trashed = false"
			}
			response, err := tool("google_workspace_drive_api_request", args("method", "GET", "path", "/drive/v3/files",
				"query", args("q", query, "orderBy", "createdTime desc", "pageSize", 20.0, "fields", "files(id,name,mimeType,createdTime,webViewLink)")))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, file := range objects(dig(response, "data", "files")) {
				rows = append(rows, Row{
					Fingerprint: timeCursor(file.Val("createdTime"), file.Val("id")), Timestamp: str(file.Val("createdTime")),
					Context: event("google_drive", "event", "file_added", "fileId", file.Val("id"), "name", textOrEmpty(file.Val("name")),
						"mimeType", orNil(file.Val("mimeType")), "url", orNil(file.Val("webViewLink"))),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

const maxSheetRowsPerRun = 50

func rowCountFingerprint(count int) string { return fmt.Sprintf("sheet_rows:%09d", count) }

var sheetRows = regexp.MustCompile(`^sheet_rows:(\d+)$`)

// The checkpoint is the row count. Fewer rows than before only moves it, so
// rows added after a deletion still count as new.
var googleSheetsAdapter = Adapter{
	Type: "google_sheets_row_added", Label: "Google Sheets Row Added", ProviderKey: "google_workspace", AppKey: "sheets",
	ConfigHint: `{ connectionId, spreadsheetId, range: A1 range of the table, e.g. "Sheet1!A:E" }`,
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "google_workspace", "sheets", func(out *jsv.Object) error {
			id, err := requiredText(pick(config, "spreadsheetId", "spreadsheet_id"), 200, "Spreadsheet ID is required.")
			if err != nil {
				return err
			}
			rng, err := requiredText(config.Val("range"), 200, "Sheet range is required, for example Sheet1!A:E.")
			if err != nil {
				return err
			}
			out.Set("spreadsheetId", id).Set("range", rng)
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string { return summaryParts("Google Sheets new rows", config.Val("range")) },
	Poll: &Poll{
		IntervalMinutes: every(5), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, checkpoint string, now time.Time) ([]Row, error) {
			result, err := tool("google_workspace_sheets_get_values", args("spreadsheet_id", config.Val("spreadsheetId"), "range", config.Val("range")))
			if err != nil {
				return nil, err
			}
			values, _ := dig(result, "values").([]any)
			previous := -1
			if m := sheetRows.FindStringSubmatch(checkpoint); m != nil {
				previous, _ = jsv.ParseInt(m[1])
			}
			fingerprint := rowCountFingerprint(len(values))
			if previous < 0 || len(values) <= previous {
				return []Row{{Fingerprint: fingerprint, Timestamp: jsv.ISO(now), Silent: true}}, nil
			}
			head := values[0]
			if !jsv.Truthy(head) {
				head = []any{}
			}
			rng := dig(result, "range")
			if !jsv.Truthy(rng) {
				rng = config.Val("range")
			}
			return []Row{{
				Fingerprint: fingerprint, Timestamp: jsv.ISO(now),
				Context: event("google_sheets", "event", "rows_added", "range", rng, "header", head,
					"firstRowNumber", float64(previous+1), "rows", values[previous:min(previous+maxSheetRowsPerRun, len(values))],
					"addedCount", float64(len(values)-previous)),
			}}, nil
		},
	},
}

var onedriveAdapter = Adapter{
	Type: "onedrive_file_added", Label: "OneDrive File Added", ProviderKey: "microsoft_365", AppKey: "onedrive",
	ConfigHint: "{ connectionId, folderId?: OneDrive item ID, otherwise the root folder }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "microsoft_365", "onedrive", func(out *jsv.Object) error {
			out.Set("folderId", trimText(pick(config, "folderId", "folder_id"), 200))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("OneDrive new files", when(config.Val("folderId"), "folder: "+str(config.Val("folderId"))))
	},
	Poll: &Poll{
		IntervalMinutes: every(5), Cursor: "ordered", Baseline: "now",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, _ time.Time) ([]Row, error) {
			result, err := tool("microsoft_365_onedrive_list_children", args("item_id", orNil(config.Val("folderId")), "top", 200.0))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, item := range objects(listFrom(result, "value")) {
				if !jsv.Truthy(item.Val("file")) {
					continue
				}
				size := item.Val("size")
				rows = append(rows, Row{
					Fingerprint: timeCursor(item.Val("createdDateTime"), item.Val("id")), Timestamp: str(item.Val("createdDateTime")),
					Context: event("onedrive", "event", "file_added", "fileId", item.Val("id"), "name", textOrEmpty(item.Val("name")),
						"size", size, "url", orNil(item.Val("webUrl"))),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

var nextcloudFileAdapter = Adapter{
	Type: "nextcloud_file_added", Label: "Nextcloud File Added", ProviderKey: "nextcloud", AppKey: "files",
	ConfigHint: `{ connectionId, path?: folder relative to the user root, e.g. "Documents" }`,
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "nextcloud", "files", func(out *jsv.Object) error {
			out.Set("path", trimText(config.Val("path"), 500))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		path := jsv.Text(config.Val("path"))
		if path == "" {
			path = "/"
		}
		return summaryParts("Nextcloud new files", path)
	},
	// Nextcloud numbers files in the order they arrive, so the file ID is the
	// cursor: clients keep a file's original modified time when they upload it.
	Poll: &Poll{
		IntervalMinutes: every(5), Cursor: "ordered", Baseline: "latest",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("nextcloud_list_files", args("path", orNil(config.Val("path"))))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, entry := range objects(listFrom(result)) {
				if entry.Val("type") != "file" {
					continue
				}
				rows = append(rows, Row{
					Fingerprint: sequenceCursor(entry.Val("fileId")), Timestamp: stampOrNow(entry.Val("lastModified"), now),
					Context: event("nextcloud", "event", "file_added", "path", entry.Val("path"), "name", entry.Val("name"),
						"size", entry.Val("size"), "mimeType", entry.Val("mimeType")),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

var nextcloudShareAdapter = Adapter{
	Type: "nextcloud_share_received", Label: "Nextcloud File Shared With You", ProviderKey: "nextcloud", AppKey: "files",
	ConfigHint: "{ connectionId }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.connectionConfig(config, "nextcloud", "files")
	},
	Summarize: func(*jsv.Object) string { return summaryParts("Nextcloud shares with you") },
	Poll: &Poll{
		IntervalMinutes: every(10), Cursor: "ordered", Baseline: "latest",
		FetchRows: func(tool ToolFunc, _ *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("nextcloud_list_shares", args("shared_with_me", true))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, share := range objects(listFrom(result)) {
				stamp := jsv.ISO(now)
				if jsv.Truthy(share.Val("stime")) {
					seconds := jsv.Number(share.Val("stime"))
					if !math.IsNaN(seconds) {
						stamp = jsv.ISO(time.UnixMilli(int64(seconds * 1000)))
					}
				}
				rows = append(rows, Row{
					Fingerprint: sequenceCursor(share.Val("id")), Timestamp: stamp,
					Context: event("nextcloud", "event", "share_received", "shareId", share.Val("id"),
						"path", orNil(pick(share, "file_target", "path")), "itemType", orNil(share.Val("item_type")),
						"owner", orNil(pick(share, "displayname_owner", "uid_owner")), "note", orNil(share.Val("note"))),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

func pageTitle(page *jsv.Object) string {
	props, _ := page.Val("properties").(*jsv.Object)
	for _, k := range props.Keys() {
		prop, _ := props.Val(k).(*jsv.Object)
		if prop.Val("type") != "title" {
			continue
		}
		var title strings.Builder
		for _, part := range objects(prop.Val("title")) {
			title.WriteString(jsv.Text(part.Val("plain_text")))
		}
		return title.String()
	}
	return ""
}

// Added and updated items read the same database, newest first by the
// timestamp each one watches. Notion keeps those timestamps to the minute.
func notionItemAdapter(typ, label, timestamp, verb string) Adapter {
	return Adapter{
		Type: typ, Label: label, ProviderKey: "notion", AppKey: "notion", ConfigHint: "{ connectionId, databaseId }",
		Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
			return vc.withConnection(config, "notion", "notion", func(out *jsv.Object) error {
				id, err := requiredText(pick(config, "databaseId", "database_id"), 200, "Notion database ID is required.")
				if err != nil {
					return err
				}
				out.Set("databaseId", id)
				return nil
			})
		},
		Summarize: func(config *jsv.Object) string { return summaryParts("Notion items "+verb, config.Val("databaseId")) },
		Poll: &Poll{
			IntervalMinutes: every(5), Cursor: "ordered", Baseline: "now",
			FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, _ time.Time) ([]Row, error) {
				result, err := tool("notion_query_database", args("database_id", config.Val("databaseId"),
					"sorts", []any{args("timestamp", timestamp, "direction", "descending")}, "page_size", 20.0))
				if err != nil {
					return nil, err
				}
				var rows []Row
				for _, page := range objects(listFrom(result, "results")) {
					properties := page.Val("properties")
					if properties == nil {
						properties = jsv.NewObject()
					}
					rows = append(rows, Row{
						Fingerprint: timeCursor(page.Val(timestamp), page.Val("id")), Timestamp: str(page.Val(timestamp)),
						Context: event("notion", "event", "database_item_"+verb, "databaseId", config.Val("databaseId"), "pageId", page.Val("id"),
							"title", pageTitle(page), "url", orNil(page.Val("url")), "createdTime", orNil(page.Val("created_time")),
							"lastEditedTime", orNil(page.Val("last_edited_time")), "properties", properties),
					})
				}
				return sortRows(keepFingerprinted(rows), byFingerprint), nil
			},
		},
	}
}

var trelloAdapter = Adapter{
	Type: "trello_card_entered_list", Label: "Trello Card Added to List", ProviderKey: "trello", AppKey: "trello",
	ConfigHint: "{ connectionId, listId }; fires for cards created in or moved into the list",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "trello", "trello", func(out *jsv.Object) error {
			id, err := requiredText(pick(config, "listId", "list_id"), 100, "Trello list ID is required.")
			if err != nil {
				return err
			}
			out.Set("listId", id)
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Trello cards entering list", config.Val("listId"))
	},
	Poll: &Poll{
		IntervalMinutes: every(5), Cursor: "ordered", Baseline: "now",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, _ time.Time) ([]Row, error) {
			result, err := tool("trello_list_actions", args("list_id", config.Val("listId"),
				"filter", "createCard,copyCard,updateCard:idList,moveCardToBoard,convertToCardFromCheckItem", "limit", 50.0))
			if err != nil {
				return nil, err
			}
			listID := jsv.String(config.Val("listId"))
			var rows []Row
			for _, action := range objects(listFrom(result)) {
				// The list's activity says how a card got there, so a card moved
				// in counts the same as one created there.
				if dig(action, "data", "listAfter", "id") != listID &&
					!(action.Val("type") != "updateCard" && dig(action, "data", "list", "id") == listID) {
					continue
				}
				how := "created"
				if action.Val("type") == "updateCard" {
					how = "moved"
				}
				listName := dig(action, "data", "listAfter", "name")
				if !jsv.Truthy(listName) {
					listName = dig(action, "data", "list", "name")
				}
				by := dig(action, "memberCreator", "fullName")
				if !jsv.Truthy(by) {
					by = dig(action, "memberCreator", "username")
				}
				rows = append(rows, Row{
					Fingerprint: timeCursor(action.Val("date"), action.Val("id")), Timestamp: str(action.Val("date")),
					Context: event("trello", "event", "card_entered_list", "how", how, "cardId", orNil(dig(action, "data", "card", "id")),
						"cardName", textOrEmpty(dig(action, "data", "card", "name")), "listId", config.Val("listId"),
						"listName", orNil(listName), "fromList", orNil(dig(action, "data", "listBefore", "name")),
						"boardName", orNil(dig(action, "data", "board", "name")), "by", orNil(by)),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

var figmaAdapter = Adapter{
	Type: "figma_comment_added", Label: "Figma Comment Added", ProviderKey: "figma", AppKey: "figma",
	ConfigHint: "{ connectionId, fileKey: from the Figma file URL }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "figma", "figma", func(out *jsv.Object) error {
			key, err := requiredText(pick(config, "fileKey", "file_key"), 100, "Figma file key is required.")
			if err != nil {
				return err
			}
			out.Set("fileKey", key)
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string { return summaryParts("Figma comments", config.Val("fileKey")) },
	Poll: &Poll{
		IntervalMinutes: every(10), Cursor: "ordered", Baseline: "now",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, _ time.Time) ([]Row, error) {
			result, err := tool("figma_get_comments", args("file_key", config.Val("fileKey")))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, comment := range objects(listFrom(result, "comments")) {
				rows = append(rows, Row{
					Fingerprint: timeCursor(comment.Val("created_at"), comment.Val("id")), Timestamp: str(comment.Val("created_at")),
					Context: event("figma", "event", "comment_added", "fileKey", config.Val("fileKey"), "commentId", comment.Val("id"),
						"message", textOrEmpty(comment.Val("message")), "author", orNil(dig(comment, "user", "handle")),
						"replyTo", orNil(comment.Val("parent_id"))),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

// ---- developer ----------------------------------------------------------------

func normalizeLabels(v any) string {
	var raw []string
	if list, ok := v.([]any); ok {
		for _, e := range list {
			raw = append(raw, jsv.Trim(jsv.Text(e)))
		}
	} else {
		for _, e := range strings.Split(jsv.Text(v), ",") {
			raw = append(raw, jsv.Trim(e))
		}
	}
	var labels []string
	for _, l := range raw {
		if l != "" && !slices.Contains(labels, l) {
			labels = append(labels, l)
		}
	}
	return strings.Join(labels, ",")
}

func stripAt(s string) string { return strings.TrimPrefix(s, "@") }

func containsFold(item *jsv.Object, query string) bool {
	return query == "" || strings.Contains(strings.ToLower(jsv.Text(item.Val("title"))+"\n"+jsv.Text(item.Val("body"))), query)
}

var githubIssueAdapter = Adapter{
	Type: "github_issue_opened", Label: "GitHub Issue Opened", ProviderKey: "github", AppKey: "repos",
	ConfigHint: `{ connectionId, repo: "owner/repo", author?, assignee?, labels?: "bug,urgent" (all must match), query?: text in title/body }`,
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "github", "repos", func(out *jsv.Object) error {
			repo, err := ownerRepo(config)
			if err != nil {
				return err
			}
			out.Set("repo", repo).Set("author", stripAt(trimText(pick(config, "author", "creator"), 100))).
				Set("assignee", stripAt(trimText(config.Val("assignee"), 100))).Set("labels", normalizeLabels(config.Val("labels"))).
				Set("query", trimText(config.Val("query"), 200))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("GitHub Issues", config.Val("repo"), when(config.Val("author"), "author: "+str(config.Val("author"))),
			when(config.Val("assignee"), "assignee: "+str(config.Val("assignee"))), when(config.Val("labels"), "labels: "+str(config.Val("labels"))),
			when(config.Val("query"), "contains: "+str(config.Val("query"))))
	},
	ReplyTarget: func(event map[string]any) (string, string, bool) {
		return "github", jsv.String(event["repo"]) + "#" + jsv.String(event["issueNumber"]), true
	},
	Poll: &Poll{
		IntervalMinutes: every(1), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			// state=all keeps the checkpoint issue in the list after it is closed, so
			// closing it never makes older issues look new.
			result, err := tool("github_list_issues", args("owner_repo", config.Val("repo"), "state", "all",
				"creator", orNil(config.Val("author")), "assignee", orNil(config.Val("assignee")), "labels", orNil(config.Val("labels")),
				"sort", "created", "direction", "desc", "max_results", 30.0))
			if err != nil {
				return nil, err
			}
			query := strings.ToLower(jsv.Text(config.Val("query")))
			var rows []Row
			for _, item := range objects(result) {
				// The issues endpoint also returns pull requests.
				if jsv.Truthy(item.Val("pull_request")) || !containsFold(item, query) {
					continue
				}
				var labels []any
				for _, l := range objects(item.Val("labels")) {
					if name := l.Val("name"); jsv.Truthy(name) {
						labels = append(labels, name)
					}
				}
				if labels == nil {
					labels = []any{}
				}
				rows = append(rows, Row{
					Fingerprint: fmt.Sprintf("github_issue:%s:%s:%s", idText(config.Val("connectionId")), idText(config.Val("repo")), idText(item.Val("number"))),
					Timestamp:   stampOrNow(item.Val("created_at"), now),
					Context: event("github", "repo", config.Val("repo"), "issueNumber", item.Val("number"), "title", textOrEmpty(item.Val("title")),
						"body", textOrEmpty(item.Val("body")), "author", orNil(dig(item, "user", "login")), "labels", labels,
						"url", orNil(item.Val("html_url"))),
				})
			}
			return sortRows(rows, byTimestamp), nil
		},
	},
}

var githubPRAdapter = Adapter{
	Type: "github_pr_opened", Label: "GitHub Pull Request Opened", ProviderKey: "github", AppKey: "repos",
	ConfigHint: `{ connectionId, repo: "owner/repo", author?, query?: text in title/body }`,
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "github", "repos", func(out *jsv.Object) error {
			repo, err := ownerRepo(config)
			if err != nil {
				return err
			}
			out.Set("repo", repo).Set("author", stripAt(trimText(config.Val("author"), 100))).Set("query", trimText(config.Val("query"), 200))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("GitHub Pull Requests", config.Val("repo"), when(config.Val("author"), "author: "+str(config.Val("author"))),
			when(config.Val("query"), "contains: "+str(config.Val("query"))))
	},
	ReplyTarget: func(event map[string]any) (string, string, bool) {
		return "github", jsv.String(event["repo"]) + "#" + jsv.String(event["number"]), true
	},
	Poll: &Poll{
		IntervalMinutes: every(2), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			// state=all keeps the checkpoint pull request listed after it closes.
			result, err := tool("github_list_prs", args("owner_repo", config.Val("repo"), "state", "all", "sort", "created",
				"direction", "desc", "max_results", 30.0))
			if err != nil {
				return nil, err
			}
			query := strings.ToLower(jsv.Text(config.Val("query")))
			var rows []Row
			for _, item := range objects(result) {
				if author := config.Val("author"); jsv.Truthy(author) && dig(item, "user", "login") != author {
					continue
				}
				if !containsFold(item, query) {
					continue
				}
				rows = append(rows, Row{
					Fingerprint: fmt.Sprintf("github_pr:%s:%s:%s", idText(config.Val("connectionId")), idText(config.Val("repo")), idText(item.Val("number"))),
					Timestamp:   stampOrNow(item.Val("created_at"), now),
					Context: event("github", "event", "pull_request_opened", "repo", config.Val("repo"), "number", item.Val("number"),
						"title", textOrEmpty(item.Val("title")), "body", textOrEmpty(item.Val("body")), "author", orNil(dig(item, "user", "login")),
						"baseBranch", orNil(dig(item, "base", "ref")), "headBranch", orNil(dig(item, "head", "ref")),
						"draft", item.Val("draft") == true, "url", orNil(item.Val("html_url"))),
				})
			}
			return sortRows(rows, byTimestamp), nil
		},
	},
}

// A run finishes long after it starts, so the cursor is when it last changed:
// that is when it failed, and a failed re-run counts again.
var githubWorkflowAdapter = Adapter{
	Type: "github_workflow_run_failed", Label: "GitHub Workflow Run Failed", ProviderKey: "github", AppKey: "repos",
	ConfigHint: `{ connectionId, repo: "owner/repo", workflow?: workflow file name or ID, branch? }`,
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "github", "repos", func(out *jsv.Object) error {
			repo, err := ownerRepo(config)
			if err != nil {
				return err
			}
			out.Set("repo", repo).Set("workflow", trimText(pick(config, "workflow", "workflow_id"), 200)).Set("branch", trimText(config.Val("branch"), 200))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("GitHub failed runs", config.Val("repo"), config.Val("workflow"), when(config.Val("branch"), "branch: "+str(config.Val("branch"))))
	},
	Poll: &Poll{
		IntervalMinutes: every(2), Cursor: "ordered", Baseline: "now",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, _ time.Time) ([]Row, error) {
			result, err := tool("github_list_workflow_runs", args("owner_repo", config.Val("repo"), "workflow_id", orNil(config.Val("workflow")),
				"branch", orNil(config.Val("branch")), "status", "failure", "max_results", 20.0))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, run := range objects(result) {
				attempt := run.Val("run_attempt")
				if !jsv.Truthy(attempt) {
					attempt = 1.0
				}
				rows = append(rows, Row{
					Fingerprint: timeCursor(run.Val("updated_at"), run.Val("id")), Timestamp: str(run.Val("updated_at")),
					Context: event("github", "event", "workflow_run_failed", "repo", config.Val("repo"), "runId", run.Val("id"),
						"workflow", orNil(run.Val("name")), "branch", orNil(run.Val("head_branch")), "commit", orNil(run.Val("head_sha")),
						"commitMessage", orNil(dig(run, "head_commit", "message")), "actor", orNil(dig(run, "actor", "login")),
						"attempt", attempt, "url", orNil(run.Val("html_url"))),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

// Commits are listed in branch order, newest first; author dates can be old
// after a rebase, so position rather than time decides what is new.
var githubCommitAdapter = Adapter{
	Type: "github_commit_pushed", Label: "GitHub Commit Pushed", ProviderKey: "github", AppKey: "repos",
	ConfigHint: `{ connectionId, repo: "owner/repo", branch?: default branch when empty }`,
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "github", "repos", func(out *jsv.Object) error {
			repo, err := ownerRepo(config)
			if err != nil {
				return err
			}
			out.Set("repo", repo).Set("branch", trimText(config.Val("branch"), 200))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("GitHub commits", config.Val("repo"), when(config.Val("branch"), "branch: "+str(config.Val("branch"))))
	},
	Poll: &Poll{
		IntervalMinutes: every(2), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("github_list_commits", args("owner_repo", config.Val("repo"), "sha", orNil(config.Val("branch")), "max_results", 20.0))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, item := range objects(result) {
				if !jsv.Truthy(item.Val("sha")) {
					continue
				}
				author := dig(item, "author", "login")
				if !jsv.Truthy(author) {
					author = dig(item, "commit", "author", "name")
				}
				rows = append(rows, Row{
					Fingerprint: fmt.Sprintf("github_commit:%s:%s:%s:%s", idText(config.Val("connectionId")), idText(config.Val("repo")),
						jsv.Text(config.Val("branch")), idText(item.Val("sha"))),
					Timestamp: stampOrNow(dig(item, "commit", "committer", "date"), now),
					Context: event("github", "event", "commit_pushed", "repo", config.Val("repo"), "branch", orNil(config.Val("branch")),
						"sha", item.Val("sha"), "message", textOrEmpty(dig(item, "commit", "message")), "author", orNil(author),
						"url", orNil(item.Val("html_url"))),
				})
			}
			slices.Reverse(rows)
			return rows, nil
		},
	},
}

// ---- home, media and memory ----------------------------------------------------

var settledStates = map[string]bool{"unavailable": true, "unknown": true}

func matchesCondition(config *jsv.Object, state string) bool {
	if to := config.Val("toState"); jsv.Truthy(to) {
		return state == jsv.String(to)
	}
	numeric := jsv.Number(state)
	if above := config.Val("above"); above != nil && !(numeric > jsv.Number(above)) {
		return false
	}
	if below := config.Val("below"); below != nil && !(numeric < jsv.Number(below)) {
		return false
	}
	return true
}

func hasCondition(config *jsv.Object) bool {
	return jsv.Truthy(config.Val("toState")) || config.Val("above") != nil || config.Val("below") != nil
}

var entityPattern = regexp.MustCompile(`^[a-z_]+\.[a-z0-9_]+$`)

// The checkpoint records whether the entity matched at its last change. With a
// condition the task runs when the entity starts matching, not on every
// reading while it stays there; without one, every change runs it.
var homeAssistantAdapter = Adapter{
	Type: "home_assistant_state_changed", Label: "Home Assistant State Changed", ProviderKey: "home_assistant", AppKey: "home_assistant",
	ConfigHint: `{ connectionId, entityId: e.g. "binary_sensor.front_door", toState?: e.g. "on", above?: number, below?: number }; without a condition every state change fires`,
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		entity, err := requiredText(pick(config, "entityId", "entity_id"), 200, "Home Assistant entity ID is required.")
		if err != nil {
			return nil, err
		}
		if !entityPattern.MatchString(entity) {
			return nil, errors.New(`Home Assistant entity ID must look like "light.kitchen".`)
		}
		toState := trimText(pick(config, "toState", "to_state"), 100)
		above, err := optionalNumber(config.Val("above"))
		if err != nil {
			return nil, err
		}
		below, err := optionalNumber(config.Val("below"))
		if err != nil {
			return nil, err
		}
		if toState != "" && (above != nil || below != nil) {
			return nil, errors.New("Use either a target state or a numeric range, not both.")
		}
		return vc.withConnection(config, "home_assistant", "home_assistant", func(out *jsv.Object) error {
			out.Set("entityId", entity).Set("toState", toState).Set("above", above).Set("below", below)
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Home Assistant", config.Val("entityId"), when(config.Val("toState"), "to "+str(config.Val("toState"))),
			when(config.Val("above") != nil, "above "+str(config.Val("above"))), when(config.Val("below") != nil, "below "+str(config.Val("below"))))
	},
	Poll: &Poll{
		IntervalMinutes: every(1), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, checkpoint string, _ time.Time) ([]Row, error) {
			entity, err := tool("home_assistant_get_state", args("entity_id", config.Val("entityId")))
			if err != nil {
				return nil, err
			}
			state := jsv.Text(dig(entity, "state"))
			changedAt := dig(entity, "last_changed")
			if !jsv.Truthy(changedAt) {
				changedAt = dig(entity, "last_updated")
			}
			if state == "" || !jsv.Truthy(changedAt) {
				return nil, nil
			}
			matched := !settledStates[state] && matchesCondition(config, state)
			kind := "idle"
			if matched {
				kind = "match"
			}
			fingerprint := fmt.Sprintf("%s:%s:%s", kind, jsv.String(config.Val("entityId")), jsv.String(changedAt))
			stillMatching := hasCondition(config) && strings.HasPrefix(checkpoint, "match:")
			if !matched || stillMatching {
				return []Row{{Fingerprint: fingerprint, Timestamp: jsv.String(changedAt), Silent: true}}, nil
			}
			name := dig(entity, "attributes", "friendly_name")
			if !jsv.Truthy(name) {
				name = config.Val("entityId")
			}
			return []Row{{
				Fingerprint: fingerprint, Timestamp: jsv.String(changedAt),
				Context: event("home_assistant", "event", "state_changed", "entityId", config.Val("entityId"), "name", name, "state", state,
					"unit", orNil(dig(entity, "attributes", "unit_of_measurement")), "changedAt", changedAt),
			}}, nil
		},
	},
}

var spotifyAdapter = Adapter{
	Type: "spotify_track_changed", Label: "Spotify Track Changed", ProviderKey: "spotify", AppKey: "spotify",
	ConfigHint: "{ connectionId }; fires when a different track starts playing",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.connectionConfig(config, "spotify", "spotify")
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("Spotify track changed", config.Val("accountEmail"))
	},
	Poll: &Poll{
		IntervalMinutes: every(1), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			playback, err := tool("spotify_get_current_playback", nil)
			if err != nil {
				return nil, err
			}
			item := dig(playback, "item")
			if !jsv.Truthy(dig(playback, "is_playing")) || !jsv.Truthy(dig(item, "id")) {
				return nil, nil
			}
			var artists []any
			for _, a := range objects(dig(item, "artists")) {
				if name := a.Val("name"); jsv.Truthy(name) {
					artists = append(artists, name)
				}
			}
			if artists == nil {
				artists = []any{}
			}
			return []Row{{
				Fingerprint: fmt.Sprintf("spotify:%s:%s", idText(config.Val("connectionId")), idText(dig(item, "id"))), Timestamp: jsv.ISO(now),
				Context: event("spotify", "event", "track_changed", "trackId", dig(item, "id"), "title", textOrEmpty(dig(item, "name")),
					"artists", artists, "album", orNil(dig(item, "album", "name")), "device", orNil(dig(playback, "device", "name")),
					"url", orNil(dig(item, "external_urls", "spotify"))),
			}}, nil
		},
	},
}

var neorecallMemoryAdapter = Adapter{
	Type: "neorecall_memory_created", Label: "NeoRecall Memory Created", ProviderKey: "neorecall", AppKey: "recall",
	ConfigHint: "{ connectionId, type?, topic?, query?: text the memory contains }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.withConnection(config, "neorecall", "recall", func(out *jsv.Object) error {
			out.Set("type", trimText(pick(config, "type", "memoryType"), 100)).Set("topic", trimText(config.Val("topic"), 100)).
				Set("query", trimText(config.Val("query"), 200))
			return nil
		})
	},
	Summarize: func(config *jsv.Object) string {
		return summaryParts("NeoRecall memories", when(config.Val("type"), "type: "+str(config.Val("type"))),
			when(config.Val("topic"), "topic: "+str(config.Val("topic"))), when(config.Val("query"), "contains: "+str(config.Val("query"))))
	},
	Poll: &Poll{
		IntervalMinutes: every(1), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("neorecall_list_memories", args("type", orNil(config.Val("type")), "topic", orNil(config.Val("topic")), "limit", 30.0))
			if err != nil {
				return nil, err
			}
			query := strings.ToLower(jsv.Text(config.Val("query")))
			var rows []Row
			for _, item := range objects(listFrom(result, "memories", "items")) {
				if !jsv.Truthy(item.Val("id")) {
					continue
				}
				if query != "" && !strings.Contains(strings.ToLower(jsv.Stringify(item)), query) {
					continue
				}
				content := pick(item, "summary", "body", "content")
				topics := item.Val("topics")
				if _, ok := topics.([]any); !ok {
					topics = []any{}
				}
				rows = append(rows, Row{
					Fingerprint: fmt.Sprintf("neorecall_memory:%s:%s", idText(config.Val("connectionId")), idText(item.Val("id"))),
					Timestamp:   stampOrNow(pick(item, "created_at", "createdAt", "timestamp"), now),
					Context: event("neorecall", "memoryId", item.Val("id"), "type", orNil(item.Val("type")), "title", textOrEmpty(item.Val("title")),
						"content", textOrEmpty(content), "topics", topics),
				})
			}
			return sortRows(rows, byTimestamp), nil
		},
	},
}

// A day's summary is rewritten while the day goes on; it fires once it is final.
var neorecallSummaryAdapter = Adapter{
	Type: "neorecall_daily_summary_created", Label: "NeoRecall Daily Summary Ready", ProviderKey: "neorecall", AppKey: "recall",
	ConfigHint: "{ connectionId }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.connectionConfig(config, "neorecall", "recall")
	},
	Summarize: func(*jsv.Object) string { return summaryParts("NeoRecall daily summary") },
	Poll: &Poll{
		IntervalMinutes: every(15), Cursor: "ordered", Baseline: "now",
		FetchRows: func(tool ToolFunc, _ *jsv.Object, _ string, _ time.Time) ([]Row, error) {
			result, err := tool("neorecall_list_daily_summaries", args("limit", 5.0))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, summary := range objects(listFrom(result, "items")) {
				if summary.Val("state") != "final" {
					continue
				}
				rows = append(rows, Row{
					Fingerprint: timeCursor(summary.Val("updated_at"), summary.Val("id")), Timestamp: str(summary.Val("updated_at")),
					Context: event("neorecall", "event", "daily_summary_ready", "date", summary.Val("local_date"),
						"summary", textOrEmpty(summary.Val("summary_en")), "sourceCount", summary.Val("source_count")),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

// A conversation counts once NeoRecall has closed it.
var neorecallConversationAdapter = Adapter{
	Type: "neorecall_conversation_recorded", Label: "NeoRecall Conversation Recorded", ProviderKey: "neorecall", AppKey: "recall",
	ConfigHint: "{ connectionId }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		return vc.connectionConfig(config, "neorecall", "recall")
	},
	Summarize: func(*jsv.Object) string { return summaryParts("NeoRecall conversations") },
	Poll: &Poll{
		IntervalMinutes: every(10), Cursor: "ordered", Baseline: "now",
		FetchRows: func(tool ToolFunc, _ *jsv.Object, _ string, now time.Time) ([]Row, error) {
			result, err := tool("neorecall_list_conversations", args("from", jsv.ISO(now.Add(-24*time.Hour)), "limit", 20.0))
			if err != nil {
				return nil, err
			}
			var rows []Row
			for _, c := range objects(listFrom(result, "items")) {
				if c.Val("state") == "open" {
					continue
				}
				topics := c.Val("topics")
				if _, ok := topics.([]any); !ok {
					topics = []any{}
				}
				rows = append(rows, Row{
					Fingerprint: timeCursor(c.Val("ended_at"), c.Val("id")), Timestamp: str(c.Val("ended_at")),
					Context: event("neorecall", "event", "conversation_recorded", "conversationId", c.Val("id"), "startedAt", c.Val("started_at"),
						"endedAt", c.Val("ended_at"), "title", orNil(c.Val("title")), "summary", orNil(c.Val("summary")), "topics", topics,
						"memoryWorthy", c.Val("memory_worthy")),
				})
			}
			return sortRows(keepFingerprinted(rows), byFingerprint), nil
		},
	},
}

// ---- the world ---------------------------------------------------------------------

var weatherEventTypes = []string{"rain_start", "snow_start", "wind_alert", "temperature_above", "temperature_below"}

func numberOr(v any, fallback float64) float64 {
	if n := jsv.Number(v); !math.IsNaN(n) && !math.IsInf(n, 0) {
		return n
	}
	return fallback
}

func normalizeEventTypes(v any) []any {
	var raw []string
	if list, ok := v.([]any); ok {
		for _, e := range list {
			raw = append(raw, jsv.String(e))
		}
	} else {
		for _, e := range strings.Split(jsv.Text(v), ",") {
			if e = jsv.Trim(e); e != "" {
				raw = append(raw, e)
			}
		}
	}
	out := []any{}
	for _, e := range raw {
		e = strings.ToLower(jsv.Trim(e))
		if slices.Contains(weatherEventTypes, e) && !slices.Contains(out, any(e)) {
			out = append(out, e)
		}
	}
	return out
}

func clampHours(v any, fallback float64) float64 {
	n := jsv.Number(v)
	if !jsv.Truthy(v) || math.IsNaN(n) || n == 0 {
		n = fallback
	}
	return math.Max(1, math.Min(n, 48))
}

var weatherAdapter = Adapter{
	Type: "weather_event", Label: "Weather Event", ProviderKey: "weather", AppKey: "forecast",
	ConfigHint: "{ connectionId, location, eventTypes: [rain_start|snow_start|wind_alert|temperature_above|temperature_below], windAlertKph?, temperatureAboveC?, temperatureBelowC? }",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		c, err := vc.ownedConnection(config, "weather", "forecast")
		if err != nil {
			return nil, err
		}
		eventTypes := normalizeEventTypes(pick(config, "eventTypes", "event_types"))
		if len(eventTypes) == 0 {
			return nil, errors.New("At least one weather event type is required: rain_start, snow_start, wind_alert, temperature_above, temperature_below.")
		}
		location := trimText(pick(config, "location", "locationQuery", "query"), 180)
		if location == "" {
			return nil, errors.New("Weather event location is required (for example: Berlin, DE).")
		}
		return jsv.NewObject().Set("connectionId", float64(c.ID)).Set("accountEmail", c.email()).Set("location", location).
			Set("eventTypes", eventTypes).
			Set("minPrecipitationMm", numberOr(coalesce(config, "minPrecipitationMm", "min_precipitation_mm"), 0.4)).
			Set("minSnowfallCm", numberOr(coalesce(config, "minSnowfallCm", "min_snowfall_cm"), 0.2)).
			Set("windAlertKph", numberOr(coalesce(config, "windAlertKph", "wind_alert_kph"), 40)).
			Set("temperatureAboveC", numberOr(coalesce(config, "temperatureAboveC", "temperature_above_c"), 32)).
			Set("temperatureBelowC", numberOr(coalesce(config, "temperatureBelowC", "temperature_below_c"), 0)).
			Set("horizonHours", clampHours(pick(config, "horizonHours", "horizon_hours"), 12)), nil
	},
	Summarize: func(config *jsv.Object) string {
		parts := []string{"Weather"}
		if loc := config.Val("location"); jsv.Truthy(loc) {
			parts = append(parts, jsv.String(loc))
		}
		if types, ok := config.Val("eventTypes").([]any); ok && len(types) > 0 {
			parts = append(parts, jsv.String(types))
		}
		return strings.Join(parts, " · ")
	},
	Poll: &Poll{
		IntervalMinutes: every(1), Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, _ string, _ time.Time) ([]Row, error) {
			request := jsv.NewObject()
			if loc := config.Val("location"); jsv.Truthy(loc) {
				request.Set("location", loc)
			}
			request.Set("forecast_hours", clampHours(config.Val("horizonHours"), 12))
			forecast, err := tool("weather_get_forecast", request)
			if err != nil {
				return nil, err
			}
			hourly, _ := dig(forecast, "hourly").([]any)
			eventTypes, _ := config.Val("eventTypes").([]any)
			enabled := func(t string) bool { return slices.Contains(eventTypes, any(t)) }
			threshold := func(key string, fallback float64) float64 {
				if v := jsv.Number(config.Val(key)); jsv.Truthy(config.Val(key)) && !math.IsNaN(v) && v != 0 {
					return v
				}
				return fallback
			}
			numberAt := func(row *jsv.Object, keys ...string) float64 { return jsv.Number(pick(row, keys...)) }
			var rows []Row
			for i := range hourly {
				row, _ := hourly[i].(*jsv.Object)
				if row == nil {
					row = jsv.NewObject()
				}
				var previous *jsv.Object
				if i > 0 {
					previous, _ = hourly[i-1].(*jsv.Object)
				}
				if previous == nil {
					previous = jsv.NewObject()
				}
				at := jsv.Trim(jsv.Text(row.Val("time")))
				if at == "" {
					continue
				}
				rain, prevRain := numberAt(row, "rain", "precipitation"), numberAt(previous, "rain", "precipitation")
				snow, prevSnow := jsv.Number(orZero(row.Val("snowfall"))), jsv.Number(orZero(previous.Val("snowfall")))
				wind := jsv.Number(orZero(row.Val("windSpeed")))
				temperature := jsv.Number(row.Val("temperature"))
				finite := !math.IsNaN(temperature) && !math.IsInf(temperature, 0)
				rainMin, snowMin := threshold("minPrecipitationMm", 0.4), threshold("minSnowfallCm", 0.2)
				candidates := []struct {
					kind   string
					active bool
				}{
					{"rain_start", enabled("rain_start") && rain >= rainMin && prevRain < rainMin},
					{"snow_start", enabled("snow_start") && snow >= snowMin && prevSnow < snowMin},
					{"wind_alert", enabled("wind_alert") && wind >= threshold("windAlertKph", 40)},
					{"temperature_above", enabled("temperature_above") && finite && temperature >= threshold("temperatureAboveC", 32)},
					{"temperature_below", enabled("temperature_below") && finite && temperature <= threshold("temperatureBelowC", 0)},
				}
				location := orNil(dig(forecast, "location", "label"))
				if location == nil {
					location = orNil(config.Val("location"))
				}
				for _, c := range candidates {
					if !c.active {
						continue
					}
					rows = append(rows, Row{
						Fingerprint: fmt.Sprintf("weather:%s:%s:%s", idText(config.Val("connectionId")), c.kind, at), Timestamp: at,
						Context: event("weather", "eventType", c.kind, "location", location, "time", at, "rain", rain, "snowfall", snow,
							"windSpeed", wind, "temperature", finiteOrNil(temperature)),
					})
				}
			}
			return sortRows(rows, byTimestamp), nil
		},
	},
}

// orZero is `value || 0`.
func orZero(v any) any {
	if jsv.Truthy(v) {
		return v
	}
	return 0.0
}

func finiteOrNil(f float64) any {
	if math.IsNaN(f) || math.IsInf(f, 0) {
		return nil
	}
	return f
}

var worldNewsAdapter = Adapter{
	Type: "world_news", Label: "World News", ProviderKey: "news", AppKey: "headlines",
	ConfigHint: "{ connectionId, query?: keywords, category?: world|nation|business|technology|science|health|sports|entertainment|general, lang?: \"en\", country?: \"de\", checkIntervalMinutes?: 15-720 }; " +
		"each run receives the new headlines and should decide from the prompt whether they are worth notifying about",
	Validate: func(vc *validation, config *jsv.Object) (*jsv.Object, error) {
		c, err := vc.ownedConnection(config, "news", "headlines")
		if err != nil {
			return nil, err
		}
		category := strings.ToLower(trimText(config.Val("category"), 30))
		if category == "" {
			category = "world"
		}
		if !slices.Contains(newsCategories, category) {
			return nil, fmt.Errorf("News category must be one of: %s.", strings.Join(newsCategories, ", "))
		}
		lang := strings.ToLower(trimText(config.Val("lang"), 2))
		if lang == "" {
			lang = "en"
		}
		interval := jsv.Number(pick(config, "checkIntervalMinutes", "check_interval_minutes"))
		if !jsv.Truthy(pick(config, "checkIntervalMinutes", "check_interval_minutes")) || math.IsNaN(interval) || interval == 0 {
			interval = 30
		}
		return jsv.NewObject().Set("connectionId", float64(c.ID)).Set("accountEmail", c.email()).Set("category", category).
			Set("query", trimText(pick(config, "query", "topics"), 180)).Set("lang", lang).
			Set("country", strings.ToLower(trimText(config.Val("country"), 2))).
			Set("checkIntervalMinutes", math.Max(15, math.Min(interval, 720))), nil
	},
	Summarize: func(config *jsv.Object) string {
		parts := []string{"World news"}
		if c := config.Val("category"); jsv.Truthy(c) && c != "world" {
			parts = append(parts, jsv.String(c))
		}
		if q := config.Val("query"); jsv.Truthy(q) {
			parts = append(parts, jsv.String(q))
		}
		return strings.Join(parts, " · ")
	},
	Poll: &Poll{
		// News APIs have small daily quotas, so each task polls on its own interval.
		IntervalMinutes: func(config *jsv.Object) float64 {
			if n := jsv.Number(config.Val("checkIntervalMinutes")); !math.IsNaN(n) && n != 0 {
				return n
			}
			return 30
		},
		Cursor: "list",
		FetchRows: func(tool ToolFunc, config *jsv.Object, checkpoint string, _ time.Time) ([]Row, error) {
			feed, err := tool("news_get_headlines", args("query", orNil(config.Val("query")), "category", config.Val("category"),
				"lang", config.Val("lang"), "country", orNil(config.Val("country")), "max", 10.0))
			if err != nil {
				return nil, err
			}
			type article struct {
				fingerprint string
				object      *jsv.Object
			}
			var articles []article
			for _, a := range objects(dig(feed, "articles")) {
				if !jsv.Truthy(a.Val("id")) || !jsv.Truthy(a.Val("publishedAt")) {
					continue
				}
				articles = append(articles, article{
					fingerprint: fmt.Sprintf("news:%s:%s:%s", idText(config.Val("connectionId")), jsv.String(a.Val("publishedAt")), jsv.String(a.Val("id"))),
					object:      a,
				})
			}
			slices.SortStableFunc(articles, func(a, b article) int { return localeCompare(a.fingerprint, b.fingerprint) })
			// Fingerprints start with the publish time, so anything ordered after the
			// checkpoint is new even when the checkpointed article left the feed.
			var fresh []article
			for _, a := range articles {
				if checkpoint == "" || a.fingerprint > checkpoint {
					fresh = append(fresh, a)
				}
			}
			if len(fresh) == 0 {
				return nil, nil
			}
			latest := fresh[len(fresh)-1]
			list := make([]any, len(fresh))
			for i, a := range fresh {
				clone := a.object.Clone()
				clone.Delete("id")
				list[i] = clone
			}
			return []Row{{
				Fingerprint: latest.fingerprint, Timestamp: jsv.String(latest.object.Val("publishedAt")),
				Context: event("news", "eventType", "headlines", "count", float64(len(fresh)), "articles", list),
			}}, nil
		},
	},
}

// encodeURIComponent is the JavaScript function: everything but letters,
// digits and -_.!~*'() is percent-encoded.
func encodeURIComponent(s string) string {
	return strings.NewReplacer("+", "%20", "%21", "!", "%27", "'", "%28", "(", "%29", ")", "%2A", "*").Replace(url.QueryEscape(s))
}

// triggerAdapters is every trigger the task system knows, in the order the
// catalog lists them.
var triggerAdapters = []*Adapter{
	&scheduleAdapter, &manualAdapter, &webhookAdapter,
	// Email and chat
	&gmailAdapter, &outlookEmailAdapter, &slackAdapter, &teamsAdapter, &whatsappPersonalAdapter,
	// Messaging platforms
	ptr(membershipAdapter("messaging_member_joined", "Member Joined", "member_joined", "joined")),
	ptr(membershipAdapter("messaging_member_left", "Member Left", "member_left", "left")),
	&reactionAdapter, &platformDisconnectedAdapter,
	// Calendars
	&googleCalendarStartingAdapter, &googleCalendarCreatedAdapter, &outlookCalendarStartingAdapter, &nextcloudCalendarStartingAdapter,
	// Files and documents
	&googleDriveAdapter, &googleSheetsAdapter, &onedriveAdapter, &nextcloudFileAdapter, &nextcloudShareAdapter,
	ptr(notionItemAdapter("notion_database_item_added", "Notion Database Item Added", "created_time", "added")),
	ptr(notionItemAdapter("notion_database_item_updated", "Notion Database Item Updated", "last_edited_time", "updated")),
	&trelloAdapter, &figmaAdapter,
	// Developer
	&githubIssueAdapter, &githubPRAdapter, &githubWorkflowAdapter, &githubCommitAdapter, &mcpServerAdapter,
	// Home, media, and memory
	&homeAssistantAdapter, &spotifyAdapter, &neorecallMemoryAdapter, &neorecallSummaryAdapter, &neorecallConversationAdapter,
	// World
	&weatherAdapter, &worldNewsAdapter,
	// Devices and tasks
	&androidNotificationAdapter, &geofenceAdapter, &healthMetricAdapter, &phoneAlarmAdapter, &wearableAdapter, &taskRunFinishedAdapter,
}

func ptr[T any](v T) *T { return &v }
