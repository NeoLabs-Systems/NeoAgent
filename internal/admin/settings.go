package admin

import (
	"os"
	"regexp"
	"strconv"
	"strings"
)

// Settings are the server-wide values the admin page edits. They live in the
// .env file (see EnvStore) and are read back from the process environment.
type Settings struct {
	Env *EnvStore
}

const (
	defaultRateLimit4h     = 2_500_000
	defaultRateLimitWeekly = 10_000_000

	envRateLimit4h     = "NEOAGENT_RATE_LIMIT_4H"
	envRateLimitWeekly = "NEOAGENT_RATE_LIMIT_WEEKLY"
	envAllowSignup     = "NEOAGENT_ALLOW_SIGNUP"
	envDisabledModels  = "NEOAGENT_DISABLED_MODELS"
	envAutoEnableNew   = "NEOAGENT_AUTO_ENABLE_NEW_MODELS"
)

// envBool reads a switch the way the Node server does: 1, true, yes or on.
func envBool(key string, fallback bool) bool {
	value := strings.ToLower(jsTrim(os.Getenv(key)))
	if value == "" {
		return fallback
	}
	switch value {
	case "1", "true", "yes", "on":
		return true
	}
	return false
}

// cleanLine is String(value ?? ”).trim() without line breaks.
func cleanLine(v any) string {
	return lineBreaks.Replace(jsTrim(jsText(v)))
}

func requireBoolean(v any, message string) (bool, error) {
	b, ok := v.(bool)
	if !ok {
		return false, fail(400, message, "")
	}
	return b, nil
}

// --- General ---

// GeneralSettings are the public address and cookie rules.
type GeneralSettings struct {
	PublicURL      string `json:"publicUrl"`
	SecureCookies  bool   `json:"secureCookies"`
	AllowedOrigins string `json:"allowedOrigins"`
}

func (s *Settings) General() GeneralSettings {
	return GeneralSettings{
		PublicURL:      os.Getenv("PUBLIC_URL"),
		SecureCookies:  envBool("SECURE_COOKIES", false),
		AllowedOrigins: os.Getenv("ALLOWED_ORIGINS"),
	}
}

func (s *Settings) UpdateGeneral(b body) error {
	publicURL := cleanLine(b["publicUrl"])
	if publicURL != "" {
		if _, ok := parseableScheme(publicURL); !ok {
			return fail(400, "publicUrl must be a valid URL.", "")
		}
	}
	allowedOrigins := cleanLine(b["allowedOrigins"])
	secure, err := requireBoolean(b["secureCookies"], "secureCookies must be a boolean.")
	if err != nil {
		return err
	}
	for _, change := range [][2]string{
		{"PUBLIC_URL", publicURL},
		{"SECURE_COOKIES", strconv.FormatBool(secure)},
		{"ALLOWED_ORIGINS", allowedOrigins},
	} {
		if err := s.Env.Persist(change[0], change[1]); err != nil {
			return err
		}
	}
	return nil
}

// --- Sign-up ---

// SignupKeyRequired reads whether open sign-up is off. Only an explicit false,
// 0 or no turns it off.
func SignupKeyRequired() bool {
	switch strings.ToLower(jsTrim(os.Getenv(envAllowSignup))) {
	case "false", "0", "no":
		return true
	}
	return false
}

func (s *Settings) SetSignupKeyRequired(v any) (bool, error) {
	required, err := requireBoolean(v, "keyRequired must be a boolean.")
	if err != nil {
		return false, err
	}
	value := "true"
	if required {
		value = "false"
	}
	return required, s.Env.Persist(envAllowSignup, value)
}

// --- Default rate limits ---

// intPrefix is the leading integer Number.parseInt(text, 10) reads.
var intPrefix = regexp.MustCompile(`^[+-]?\d+`)

func parsePositiveInteger(raw string, fallback float64) float64 {
	digits := intPrefix.FindString(strings.TrimLeftFunc(raw, isJSSpace))
	if digits == "" {
		return fallback
	}
	f, err := strconv.ParseFloat(digits, 64)
	if err != nil && !isRangeError(err) {
		return fallback
	}
	if f > 0 {
		return f
	}
	return fallback
}

// DefaultRateLimits are the server-wide token limits accounts without their
// own limit get.
type DefaultRateLimits struct {
	FourHour float64 `json:"rate_limit_4h"`
	Weekly   float64 `json:"rate_limit_weekly"`
}

func (s *Settings) DefaultRateLimits() DefaultRateLimits {
	return DefaultRateLimits{
		FourHour: parsePositiveInteger(os.Getenv(envRateLimit4h), defaultRateLimit4h),
		Weekly:   parsePositiveInteger(os.Getenv(envRateLimitWeekly), defaultRateLimitWeekly),
	}
}

func limitText(v any) string {
	switch v := v.(type) {
	case int64:
		return strconv.FormatInt(v, 10)
	case float64:
		return numberString(v)
	}
	return ""
}

// SetDefaultRateLimits stores both limits; empty values go back to the
// built-in defaults.
func (s *Settings) SetDefaultRateLimits(b body) error {
	fourHour, err := parseLimit(b["rate_limit_4h"], "rate_limit_4h")
	if err != nil {
		return err
	}
	weekly, err := parseLimit(b["rate_limit_weekly"], "rate_limit_weekly")
	if err != nil {
		return err
	}
	if err := s.Env.Persist(envRateLimit4h, limitText(fourHour)); err != nil {
		return err
	}
	return s.Env.Persist(envRateLimitWeekly, limitText(weekly))
}

// --- Model visibility ---

// ModelsConfig is the saved model visibility.
type ModelsConfig struct {
	OK                  bool     `json:"ok"`
	DisabledModels      []string `json:"disabledModels"`
	AutoEnableNewModels bool     `json:"autoEnableNewModels"`
}

// SetModelsConfig stores the disabled model list and, when given, whether
// models a provider adds later start enabled.
func (s *Settings) SetModelsConfig(disabled any, autoEnable any) (ModelsConfig, error) {
	list, ok := disabled.([]any)
	if !ok {
		return ModelsConfig{}, fail(400, "disabledModels must be an array", "")
	}
	if enabled, isBool := autoEnable.(bool); isBool {
		if err := s.Env.PersistList(envAutoEnableNew, []string{strconv.FormatBool(enabled)}); err != nil {
			return ModelsConfig{}, err
		}
	}
	ids := []string{}
	for _, item := range list {
		ids = append(ids, jsTrim(jsString(item)))
	}
	kept := []string{}
	for _, id := range uniqueStrings(ids) {
		if id != "" {
			kept = append(kept, id)
		}
	}
	if err := s.Env.PersistList(envDisabledModels, kept); err != nil {
		return ModelsConfig{}, err
	}
	return ModelsConfig{OK: true, DisabledModels: kept, AutoEnableNewModels: os.Getenv(envAutoEnableNew) != "false"}, nil
}
