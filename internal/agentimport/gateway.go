package agentimport

import (
	"database/sql"
	"path/filepath"
	"regexp"
	"time"
)

// jsDate parses the date strings and millisecond stamps source configs hold,
// the way `new Date(value)` does for the formats they use.
func jsDate(v any) (time.Time, bool) {
	switch t := v.(type) {
	case float64:
		return time.UnixMilli(int64(t)).UTC(), true
	case string:
		text := trim(t)
		for _, layout := range []string{
			time.RFC3339Nano, "2006-01-02T15:04:05.999999999Z0700", "2006-01-02", "2006-01", "2006",
			time.RFC1123Z, time.RFC1123, "Mon, 02 Jan 2006 15:04:05 GMT",
		} {
			if d, err := time.Parse(layout, text); err == nil {
				return d, true
			}
		}
		for _, layout := range []string{"2006-01-02T15:04:05.999999999", "2006-01-02T15:04", "2006-01-02 15:04:05.999999999", "2006-01-02 15:04"} {
			if d, err := time.ParseInLocation(layout, text, time.Local); err == nil {
				return d, true
			}
		}
	}
	return time.Time{}, false
}

// isoString is Date.prototype.toISOString.
func isoString(d time.Time) string { return d.UTC().Format("2006-01-02T15:04:05.000Z") }

// numberOf is Number(value) for decoded values; ok is false for NaN.
func numberOf(v any) (float64, bool) {
	switch t := v.(type) {
	case float64:
		return t, true
	case string:
		f, ok := parseNumber(trim(t))
		return f, ok
	case bool:
		if t {
			return 1, true
		}
		return 0, true
	case nil:
		return 0, true
	}
	return 0, false
}

// detail builds the original definition of a skipped item, keeping only the
// members the source had, as JSON.stringify would.
func detail(pairs ...any) *Obj {
	o := newObj()
	for i := 0; i+1 < len(pairs); i += 2 {
		if pairs[i+1] != undefined {
			o.set(pairs[i].(string), pairs[i+1])
		}
	}
	return o
}

// undefined marks a member the source did not have.
var undefined = &struct{ name string }{"undefined"}

func member(o *Obj, key string) any {
	if !o.Has(key) {
		return undefined
	}
	return o.Get(key)
}

// spread copies the members of src into dst (`{...src}`).
func spread(dst *Obj, src any) {
	if o := asObj(src); o != nil {
		for _, k := range o.Keys() {
			dst.set(k, o.Get(k))
		}
	}
}

// collectOpenClawTasks reads the automations. They live in
// state/openclaw.sqlite (2026) or cron/jobs.json (before). Jobs OpenClaw
// manages itself (heartbeat, memory dreaming) carry a declaration key and are
// left behind.
func (s Scanner) collectOpenClawTasks(home string, stateDB *sql.DB, agents []Agent, skipped *[]Skipped) []Task {
	var jobs []*Obj
	for _, row := range queryStrings(stateDB, `SELECT job_json FROM cron_jobs ORDER BY sort_order`, 1) {
		if v, err := parseJSON([]byte(row[0])); err == nil && v != nil {
			if o := asObj(v); o != nil {
				jobs = append(jobs, o)
			}
		}
	}
	if len(jobs) == 0 {
		if legacy, ok := readText(filepath.Join(home, "cron", "jobs.json")); ok && legacy != "" {
			if v, err := parseJSON([]byte(legacy)); err == nil {
				if list, isList := v.([]any); isList {
					for _, item := range list {
						if o := asObj(item); o != nil {
							jobs = append(jobs, o)
						}
					}
				} else {
					for _, item := range asList(asObj(v).Get("jobs")) {
						if o := asObj(item); o != nil {
							jobs = append(jobs, o)
						}
					}
				}
			}
		}
	}

	defaultAgent := ""
	for _, a := range agents {
		if a.IsDefault {
			defaultAgent = a.Key
			break
		}
	}
	var tasks []Task
	seen := map[string]int{}
	for _, job := range jobs {
		payload := asObj(job.Get("payload"))
		if truthy(job.Get("declarationKey")) || str(payload.Get("kind")) == "heartbeat" {
			continue
		}
		name := firstNonEmpty(trim(str(job.Get("displayName"))), trim(str(job.Get("name"))), "Automation")
		prompt := promptFor(payload)
		if prompt == "" {
			reason := "\"" + firstNonEmpty(str(payload.Get("kind")), "unknown") + "\" jobs have no NeoAgent equivalent"
			if str(payload.Get("kind")) == "command" {
				reason = "runs a shell command on this computer; NeoAgent's agent works on its own computer"
			}
			d := detail("schedule", member(job, "schedule"))
			spread(d, payload)
			*skipped = append(*skipped, Skipped{Kind: "Automation", Name: name, Reason: reason, Detail: d})
			continue
		}
		trigger, ok := openclawTrigger(asObj(job.Get("schedule")))
		if !ok {
			*skipped = append(*skipped, Skipped{Kind: "Automation", Name: name, Reason: "its schedule could not be read"})
			continue
		}
		if trigger.Mode == "one_time" && s.passed(trigger.RunAt) {
			*skipped = append(*skipped, Skipped{Kind: "Automation", Name: name, Reason: "a one-time job whose time has passed"})
			continue
		}
		// The same job saved twice: keep one, with whichever chat target was set.
		identity := name + "|" + prompt + "|" + firstNonEmpty(trigger.CronExpression, trigger.RunAt)
		delivery := asObj(job.Get("delivery"))
		channel := str(delivery.Get("channel"))
		if at, dup := seen[identity]; dup {
			if n := tasks[at].Notify; n != nil && n.To == "" && str(delivery.Get("to")) != "" {
				n.To = str(delivery.Get("to"))
			}
			continue
		}
		task := Task{
			Name:     name,
			AgentKey: firstNonEmpty(str(job.Get("agentId")), defaultAgent),
			Prompt:   prompt,
			Trigger:  trigger,
			Enabled:  asBoolNot(job.Get("enabled")),
			TZ:       str(asObj(job.Get("schedule")).Get("tz")),
			Model:    fromSlashModel(payload.Get("model")),
			Note:     trigger.Note,
		}
		if isMessagingPlatform(channel) {
			task.Notify = &Notify{Platform: channel, To: str(delivery.Get("to"))}
		}
		seen[identity] = len(tasks)
		tasks = append(tasks, task)
	}
	return tasks
}

// passed is `Date.parse(runAt) < Date.now()`.
func (s Scanner) passed(runAt string) bool {
	d, ok := jsDate(runAt)
	return ok && d.Before(s.now())
}

func promptFor(payload *Obj) string {
	switch str(payload.Get("kind")) {
	case "agentTurn":
		return trim(str(payload.Get("message")))
	case "systemEvent":
		return trim(str(payload.Get("text")))
	}
	return ""
}

func openclawTrigger(schedule *Obj) (Trigger, bool) {
	switch str(schedule.Get("kind")) {
	case "cron":
		if expr := str(schedule.Get("expr")); expr != "" {
			return cronTrigger(expr)
		}
	case "every":
		if truthy(schedule.Get("everyMs")) {
			ms, _ := numberOf(schedule.Get("everyMs"))
			c := intervalToCron(ms)
			note := ""
			if !c.Exact {
				note = "interval rounded to the nearest cron step"
			}
			return Trigger{Mode: "recurring", CronExpression: c.Expr, Note: note}, true
		}
	case "at":
		if truthy(schedule.Get("at")) {
			return oneTime(schedule.Get("at"))
		}
	}
	return Trigger{}, false
}

func cronTrigger(expr string) (Trigger, bool) {
	c, ok := toFiveFieldCron(expr)
	if !ok {
		return Trigger{}, false
	}
	note := ""
	if !c.Exact {
		note = "sub-minute timing rounded to the minute"
	}
	return Trigger{Mode: "recurring", CronExpression: c.Expr, Note: note}, true
}

func oneTime(at any) (Trigger, bool) {
	d, ok := jsDate(at)
	if !ok {
		return Trigger{}, false
	}
	return Trigger{Mode: "one_time", RunAt: isoString(d)}, true
}

var (
	channelSplit = regexp.MustCompile(`[:/]`)
	platforms    = []string{"telegram", "discord", "whatsapp"}
)

const whatsappNote = "WhatsApp links to one app at a time; scan the QR code in NeoAgent (allowed numbers were kept)"
const slackNote = "NeoAgent receives Slack events by webhook instead of socket mode; set it up under Integrations"

func (s Scanner) collectOpenClawChannels(home string, config *Obj, env *envVars, stateDB *sql.DB, skipped *[]Skipped) []Channel {
	pairing := map[string][]string{}
	for _, row := range queryStrings(stateDB, `SELECT channel_key, entry FROM channel_pairing_allow_entries ORDER BY sort_order`, 2) {
		platform := channelSplit.Split(row[0], 2)[0]
		pairing[platform] = append(pairing[platform], row[1])
	}
	for _, platform := range platforms {
		for _, file := range []string{platform + "-allowFrom.json", platform + "-default-allowFrom.json"} {
			text, ok := readText(filepath.Join(home, "credentials", file))
			if !ok || text == "" {
				continue
			}
			v, err := parseJSON([]byte(text))
			if err != nil {
				continue
			}
			list, isList := v.([]any)
			if !isList {
				list, isList = asObj(v).Get("allowFrom").([]any)
			}
			if isList {
				for _, item := range list {
					pairing[platform] = append(pairing[platform], str(item))
				}
			}
		}
	}

	source := asObj(config.Get("channels"))
	accountOf := func(cfg any) *Obj {
		c := asObj(cfg)
		if c == nil {
			return newObj()
		}
		var accounts []*Obj
		for _, k := range asObj(c.Get("accounts")).Keys() {
			if a := asObj(asObj(c.Get("accounts")).Get(k)); a != nil {
				accounts = append(accounts, a)
			}
		}
		if len(accounts) > 1 {
			*skipped = append(*skipped, Skipped{Kind: "Channel", Name: "extra accounts", Reason: "NeoAgent connects one account per platform; the first one was used"})
		}
		merged := newObj()
		if len(accounts) > 0 {
			spread(merged, accounts[0])
		}
		spread(merged, c)
		return merged
	}
	allowOf := func(cfg *Obj, platform string) []string {
		var out []string
		seen := map[string]bool{}
		add := func(value string) {
			if v := trim(value); v != "" && v != "*" && !seen[v] {
				seen[v] = true
				out = append(out, v)
			}
		}
		for _, item := range asList(cfg.Get("allowFrom")) {
			add(str(item))
		}
		for _, item := range asList(asObj(cfg.Get("dm")).Get("allowFrom")) {
			add(str(item))
		}
		for _, item := range pairing[platform] {
			add(item)
		}
		return out
	}

	var channels []Channel
	home2 := s.home()
	telegram := accountOf(source.Get("telegram"))
	token := resolveSecret(telegram.Get("botToken"), env, home2)
	if token == "" && truthy(telegram.Get("tokenFile")) {
		text, _ := readText(expandHome(str(telegram.Get("tokenFile")), home2))
		token = trim(text)
	}
	if token == "" {
		token = env.get("TELEGRAM_BOT_TOKEN")
	}
	if token != "" && asBoolNot(telegram.Get("enabled")) {
		channels = append(channels, Channel{Platform: "telegram", Config: []header{{"botToken", token}}, Allow: allowOf(telegram, "telegram")})
	}

	discord := accountOf(source.Get("discord"))
	dToken := resolveSecret(firstTruthy(discord.Get("token"), discord.Get("botToken")), env, home2)
	if dToken == "" {
		dToken = env.get("DISCORD_BOT_TOKEN")
	}
	if dToken != "" && asBoolNot(discord.Get("enabled")) {
		channels = append(channels, Channel{Platform: "discord", Config: []header{{"token", dToken}}, Allow: allowOf(discord, "discord")})
	}

	whatsapp := accountOf(source.Get("whatsapp"))
	if truthy(source.Get("whatsapp")) && asBoolNot(whatsapp.Get("enabled")) {
		channels = append(channels, Channel{Platform: "whatsapp", Allow: allowOf(whatsapp, "whatsapp")})
		*skipped = append(*skipped, Skipped{Kind: "Channel", Name: "WhatsApp", Reason: whatsappNote})
	}

	if slack := source.Get("slack"); truthy(slack) && asBoolNot(asObj(slack).Get("enabled")) {
		*skipped = append(*skipped, Skipped{Kind: "Channel", Name: "Slack", Reason: slackNote})
	}
	for _, name := range source.Keys() {
		other := asObj(source.Get(name))
		if !isMessagingPlatform(name) && other != nil && asBoolNot(other.Get("enabled")) {
			*skipped = append(*skipped, Skipped{Kind: "Channel", Name: name, Reason: "not supported by NeoAgent"})
		}
	}
	return channels
}

func firstTruthy(values ...any) any {
	for _, v := range values {
		if truthy(v) {
			return v
		}
	}
	return nil
}
