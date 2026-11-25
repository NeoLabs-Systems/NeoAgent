package admin

import (
	"math"
	"os"
	"regexp"
	"strconv"
	"strings"
)

// The service-email settings: SMTP connection, sender, token lifetime and which
// account events send mail. The keys and defaults are the ones the email
// service reads at startup.

var emailStringFields = []struct{ name, key string }{
	{"from", "NEOAGENT_EMAIL_FROM"},
	{"smtpHost", "NEOAGENT_EMAIL_SMTP_HOST"},
	{"smtpUser", "NEOAGENT_EMAIL_SMTP_USER"},
	{"replyTo", "NEOAGENT_EMAIL_REPLY_TO"},
	{"brandName", "NEOAGENT_EMAIL_BRAND_NAME"},
	{"supportUrl", "NEOAGENT_EMAIL_SUPPORT_URL"},
	{"publicUrl", "NEOAGENT_EMAIL_PUBLIC_URL"},
}

var emailBoolFields = []struct {
	name, key string
	fallback  bool
}{
	{"smtpSecure", "NEOAGENT_EMAIL_SMTP_SECURE", false},
	{"smtpRequireTls", "NEOAGENT_EMAIL_SMTP_REQUIRE_TLS", true},
	{"smtpRejectUnauthorized", "NEOAGENT_EMAIL_SMTP_REJECT_UNAUTHORIZED", true},
	{"requireSignupConfirmation", "NEOAGENT_EMAIL_REQUIRE_SIGNUP_CONFIRMATION", true},
	{"requireEmailChangeConfirmation", "NEOAGENT_EMAIL_REQUIRE_EMAIL_CHANGE_CONFIRMATION", true},
	{"notifyUnusualLogin", "NEOAGENT_EMAIL_NOTIFY_UNUSUAL_LOGIN", true},
	{"notifyAccountChanges", "NEOAGENT_EMAIL_NOTIFY_ACCOUNT_CHANGES", true},
}

const (
	envEmailPort       = "NEOAGENT_EMAIL_SMTP_PORT"
	envEmailTokenHours = "NEOAGENT_EMAIL_TOKEN_TTL_HOURS"
	envEmailPassword   = "NEOAGENT_EMAIL_SMTP_PASS"
)

// EmailSettings is the settings object the admin page edits, in the order the
// Node server lists its keys.
type EmailSettings struct {
	SMTPPort                       int64  `json:"smtpPort"`
	TokenTTLHours                  int64  `json:"tokenTtlHours"`
	SMTPPasswordConfigured         bool   `json:"smtpPasswordConfigured"`
	From                           string `json:"from"`
	SMTPHost                       string `json:"smtpHost"`
	SMTPUser                       string `json:"smtpUser"`
	ReplyTo                        string `json:"replyTo"`
	BrandName                      string `json:"brandName"`
	SupportURL                     string `json:"supportUrl"`
	PublicURL                      string `json:"publicUrl"`
	SMTPSecure                     bool   `json:"smtpSecure"`
	SMTPRequireTLS                 bool   `json:"smtpRequireTls"`
	SMTPRejectUnauthorized         bool   `json:"smtpRejectUnauthorized"`
	RequireSignupConfirmation      bool   `json:"requireSignupConfirmation"`
	RequireEmailChangeConfirmation bool   `json:"requireEmailChangeConfirmation"`
	NotifyUnusualLogin             bool   `json:"notifyUnusualLogin"`
	NotifyAccountChanges           bool   `json:"notifyAccountChanges"`
}

// EmailView is the answer of both email routes.
type EmailView struct {
	Configured bool          `json:"configured"`
	Missing    []string      `json:"missing"`
	Settings   EmailSettings `json:"settings"`
}

func envString(key string) string { return jsTrim(os.Getenv(key)) }

func envPositive(key string, fallback int64) int64 {
	f := stringToNumber(envString(key))
	if isInteger(f) && f > 0 && f < math.MaxInt64 {
		return int64(f)
	}
	return fallback
}

// Email reads the current email settings from the environment.
func (s *Settings) Email() EmailView {
	port := envPositive(envEmailPort, 587)
	st := EmailSettings{
		SMTPPort:               port,
		TokenTTLHours:          envPositive(envEmailTokenHours, 24),
		SMTPPasswordConfigured: envString(envEmailPassword) != "",
	}
	texts := []*string{&st.From, &st.SMTPHost, &st.SMTPUser, &st.ReplyTo, &st.BrandName, &st.SupportURL, &st.PublicURL}
	for i, field := range emailStringFields {
		*texts[i] = envString(field.key)
	}
	flags := []*bool{
		&st.SMTPSecure, &st.SMTPRequireTLS, &st.SMTPRejectUnauthorized, &st.RequireSignupConfirmation,
		&st.RequireEmailChangeConfirmation, &st.NotifyUnusualLogin, &st.NotifyAccountChanges,
	}
	for i, field := range emailBoolFields {
		fallback := field.fallback
		switch field.name {
		case "smtpSecure": // implicit TLS is the norm on port 465
			fallback = port == 465
		case "smtpRequireTls":
			fallback = !st.SMTPSecure
		}
		*flags[i] = envBool(field.key, fallback)
	}

	missing := []string{}
	if st.From == "" {
		missing = append(missing, "Sender address")
	}
	if st.SMTPHost == "" {
		missing = append(missing, "SMTP host")
	}
	return EmailView{Configured: len(missing) == 0, Missing: missing, Settings: st}
}

var lineBreakChars = regexp.MustCompile(`[\r\n]`)

func singleLine(v any, label string) (string, error) {
	cleaned := jsTrim(jsText(v))
	if lineBreakChars.MatchString(cleaned) {
		return "", fail(400, label+" must be a single line.", "")
	}
	return cleaned, nil
}

func httpURL(v any, label string) (string, error) {
	cleaned, err := singleLine(v, label)
	if err != nil || cleaned == "" {
		return "", err
	}
	scheme, ok := parseableScheme(cleaned)
	if !ok || (scheme != "http" && scheme != "https") {
		return "", fail(400, label+" must be an HTTP or HTTPS URL.", "")
	}
	return strings.TrimSuffix(cleaned, "/"), nil
}

func boundedInteger(v any, label string, min, max float64) (int64, error) {
	f := jsToNumber(v)
	if !isInteger(f) || f < min || f > max {
		return 0, fail(400, label+" must be an integer from "+numberString(min)+" to "+numberString(max)+".", "")
	}
	return int64(f), nil
}

// UpdateEmail validates the whole form, then stores it. The SMTP password is
// only touched when a new one is sent or clearSmtpPassword is true.
func (s *Settings) UpdateEmail(b body) (EmailView, error) {
	texts := make([]string, len(emailStringFields))
	for i, field := range emailStringFields {
		var err error
		switch field.name {
		case "supportUrl":
			texts[i], err = httpURL(b[field.name], "Support URL")
		case "publicUrl":
			texts[i], err = httpURL(b[field.name], "Public URL")
		default:
			texts[i], err = singleLine(b[field.name], field.name)
		}
		if err != nil {
			return EmailView{}, err
		}
	}
	port, err := boundedInteger(b["smtpPort"], "SMTP port", 1, 65535)
	if err != nil {
		return EmailView{}, err
	}
	hours, err := boundedInteger(b["tokenTtlHours"], "Token lifetime", 1, 8760)
	if err != nil {
		return EmailView{}, err
	}
	flags := make([]bool, len(emailBoolFields))
	for i, field := range emailBoolFields {
		if flags[i], err = requireBoolean(b[field.name], field.name+" must be true or false."); err != nil {
			return EmailView{}, err
		}
	}
	password, err := singleLine(b["smtpPassword"], "SMTP password")
	if err != nil {
		return EmailView{}, err
	}
	clearPassword := b["clearSmtpPassword"] == true

	for i, field := range emailStringFields {
		if err := s.Env.PersistQuoted(field.key, texts[i]); err != nil {
			return EmailView{}, err
		}
	}
	if err := s.Env.PersistQuoted(envEmailPort, strconv.FormatInt(port, 10)); err != nil {
		return EmailView{}, err
	}
	if err := s.Env.PersistQuoted(envEmailTokenHours, strconv.FormatInt(hours, 10)); err != nil {
		return EmailView{}, err
	}
	for i, field := range emailBoolFields {
		if err := s.Env.PersistQuoted(field.key, strconv.FormatBool(flags[i])); err != nil {
			return EmailView{}, err
		}
	}
	if password != "" || clearPassword {
		if clearPassword {
			password = ""
		}
		if err := s.Env.PersistQuoted(envEmailPassword, password); err != nil {
			return EmailView{}, err
		}
	}
	return s.Email(), nil
}
