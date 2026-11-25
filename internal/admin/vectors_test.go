package admin

import (
	"bytes"
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"testing"
)

// These tests replay inputs through the Go routes and settings and compare with
// what the Node services answered for the same inputs (testdata/gen_vectors.js).
// The sections share one seeded stack and run in the order Node ran them,
// because some answers depend on what earlier ones changed.

func TestNodeVectors(t *testing.T) {
	v := loadVectors(t)
	s := newStack(t, v.Seed...)
	admin := s.login(1)

	t.Run("route ids", func(t *testing.T) {
		for _, c := range v.UserID {
			id, ok := positiveID(c.Input)
			switch {
			case c.Error != nil && ok:
				t.Errorf("%q accepted as %d, Node refused", c.Input, id)
			case c.Error == nil && (!ok || float64(id) != *c.ID):
				t.Errorf("%q = %d (%v), Node read %v", c.Input, id, ok, *c.ID)
			}
		}
	})

	t.Run("user list", func(t *testing.T) {
		for _, c := range v.List {
			_, raw := admin.do("GET", "/api/admin/users?q="+urlEscape(c.Q), nil)
			sameJSON(t, "q="+c.Q, raw, c.Out)
		}
	})

	t.Run("sign-up key list", func(t *testing.T) {
		_, raw := admin.do("GET", "/api/admin/signup-keys", nil)
		sameJSON(t, "keys", raw, v.Keys)
	})

	t.Run("account limits", func(t *testing.T) {
		for _, c := range v.UserLimits {
			status, raw := admin.do("PUT", "/api/admin/users/2/rate-limits", c.Body)
			if c.Error != nil {
				expectError(t, string(c.Body), status, raw, c.Error)
				continue
			}
			sameJSON(t, string(c.Body)+" put", raw, json.RawMessage(`{"ok":true}`))
			_, raw = admin.do("GET", "/api/admin/users/2/rate-limits", nil)
			sameJSON(t, string(c.Body)+" get", raw, c.Value)
		}
	})

	t.Run("model grants", func(t *testing.T) {
		base := s.catalog
		for _, c := range v.Grants {
			var ids []any
			if json.Unmarshal(c.ModelIDs, &ids) == nil && len(ids) == 201 {
				s.catalog = append(append([]string{}, base...), idStrings(ids)...)
			} else {
				s.catalog = base
			}
			before := len(s.auditRows())
			status, raw := admin.do("PUT", "/api/admin/users/3/allowed-models", json.RawMessage(`{"modelIds":`+string(c.ModelIDs)+`}`))
			label := string(c.ModelIDs)
			if len(label) > 60 {
				label = label[:60]
			}
			if c.Error != nil {
				expectError(t, label, status, raw, c.Error)
			} else {
				sameJSON(t, label, raw, c.Value)
			}
			var stored *string
			if err := s.db.W.QueryRow(`SELECT allowed_models FROM users WHERE id = 3`).Scan(&stored); err != nil {
				t.Fatal(err)
			}
			if !samePtr(stored, c.Stored) {
				t.Errorf("%s: stored %v, Node stored %v", label, deref(stored), deref(c.Stored))
			}
			sameAudit(t, label, s.auditRows()[before:], c.Audit)
			_, raw = admin.do("GET", "/api/admin/users/3/allowed-models", nil)
			sameJSON(t, label+" read", raw, c.Read.Value)
		}
		s.catalog = base
		for _, c := range v.GrantsRead {
			status, raw := admin.do("GET", "/api/admin/users/"+itoa(c.ID)+"/allowed-models", nil)
			if c.Error != nil {
				expectError(t, "read "+itoa(c.ID), status, raw, c.Error)
			} else {
				sameJSON(t, "read "+itoa(c.ID), raw, c.Value)
			}
		}
	})

	t.Run("sign-up keys", func(t *testing.T) {
		for _, c := range v.CreateKeys {
			payload := map[string]json.RawMessage{}
			if string(c.Count) != `"__undefined"` {
				payload["count"] = c.Count
			}
			if string(c.Label) != `"__undefined"` {
				payload["label"] = c.Label
			}
			raw, _ := json.Marshal(payload)
			before := len(s.auditRows())
			status, body := admin.do("POST", "/api/admin/signup-keys", json.RawMessage(raw))
			label := string(c.Count) + " " + string(c.Label)
			if len(label) > 60 {
				label = label[:60]
			}
			if c.Error != nil {
				expectError(t, label, status, body, c.Error)
			} else {
				if status != http.StatusCreated {
					t.Errorf("%s: status %d", label, status)
				}
				var out struct{ Keys []SignupKey }
				if err := json.Unmarshal(body, &out); err != nil || len(out.Keys) != c.Created {
					t.Fatalf("%s: %d keys (%v), Node made %d", label, len(out.Keys), err, c.Created)
				}
				k, want := out.Keys[0], c.Sample
				// Node stores half of a split emoji as invalid UTF-8; Go stores U+FFFD.
				if strings.ContainsRune(want.Label, '\ufffd') {
					k.Label, want.Label = strings.TrimRight(k.Label, "\ufffd"), strings.TrimRight(want.Label, "\ufffd")
				}
				if k.Label != want.Label || k.Status != want.Status || !samePtr(k.CreatedBy, want.CreatedBy) ||
					k.UsedAt != nil || k.UsedBy != nil || k.RevokedAt != nil || keyShape(k.Code) != want.CodePattern {
					t.Errorf("%s: key %+v, Node %+v", label, k, *want)
				}
			}
			sameAudit(t, label, s.auditRows()[before:], c.Audit)
		}
		for _, c := range v.RevokeKeys {
			before := len(s.auditRows())
			status, raw := admin.do("DELETE", "/api/admin/signup-keys/"+itoa(c.ID), nil)
			if c.Error != nil {
				expectError(t, "revoke "+itoa(c.ID), status, raw, c.Error)
			} else {
				sameJSON(t, "revoke "+itoa(c.ID), raw, c.Value)
			}
			sameAudit(t, "revoke "+itoa(c.ID), s.auditRows()[before:], c.Audit)
		}
	})

	t.Run("sql console", func(t *testing.T) {
		for _, c := range v.SQL {
			status, raw := admin.do("POST", "/api/admin/sql", map[string]string{"query": c.Query})
			label := c.Query
			if len(label) > 50 {
				label = label[:50]
			}
			if c.Error != nil {
				expectError(t, label, status, raw, c.Error)
				continue
			}
			if status != http.StatusOK {
				t.Errorf("%s: status %d %s", label, status, raw)
			}
			sameJSON(t, label, raw, c.Value)
		}
		for _, c := range v.SQLRaw {
			status, raw := admin.do("POST", "/api/admin/sql", c.Body)
			expectError(t, string(c.Body), status, raw, c.Error)
		}
	})

	t.Run("sql console number text", func(t *testing.T) {
		_, raw := admin.do("POST", "/api/admin/sql", map[string]string{"query": "SELECT 9223372036854775807 AS big, 1e21 AS e21, 1e-7 AS em7, -0.0 AS nz"})
		const want = `"rows":[{"big":9223372036854776000,"e21":1e+21,"em7":1e-7,"nz":-0}]`
		if !bytes.Contains(raw, []byte(want)) {
			t.Errorf("number text %s, want %s", raw, want)
		}
	})

	t.Run("settings", func(t *testing.T) { settingsVectors(t, v, s) })

	t.Run("admin grants", func(t *testing.T) {
		ctx := t.Context()
		for i, c := range v.AdminFlow {
			label := c.Op + " " + string(c.Arg)
			before := len(s.auditRows())
			var out any
			var err error
			var names []string
			var name string
			_ = json.Unmarshal(c.Arg, &names)
			_ = json.Unmarshal(c.Arg, &name)
			switch c.Op {
			case "apply":
				out, err = s.api.Store.ApplyEnvAdminGrants(ctx, names)
				if r, ok := out.(EnvGrants); ok {
					out = map[string][]string{"granted": r.Granted, "missing": r.Missing, "revoked": r.Revoked}
				}
			case "grant":
				out, err = s.api.Store.GrantAdmin(ctx, name, "cli")
			case "revoke":
				out, err = s.api.Store.RevokeAdmin(ctx, name, "cli")
			case "needs":
				out, err = s.api.Store.NeedsAdminGrant(ctx)
			default:
				out, err = s.api.Store.ListAdmins(ctx)
			}
			if r, ok := out.(GrantResult); ok {
				out = map[string]any{"username": r.Username, "changed": r.Changed}
			}
			if c.Error != nil {
				if err == nil || err.Error() != c.Error.Message {
					t.Errorf("step %d %s: error %v, Node %q", i, label, err, c.Error.Message)
				}
			} else {
				if err != nil {
					t.Fatalf("step %d %s: %v", i, label, err)
				}
				got, _ := json.Marshal(out)
				sameJSON(t, "step "+itoa(int64(i))+" "+label, got, c.Value)
			}
			sameAudit(t, "step "+itoa(int64(i))+" "+label, s.auditRows()[before:], c.Audit)
		}
	})
}

func settingsVectors(t *testing.T, v *vectors, s *stack) {
	t.Helper()
	var keys []string
	for key := range v.General[0].Env {
		keys = append(keys, key)
	}
	for _, key := range keys {
		t.Setenv(key, "")
		os.Unsetenv(key)
	}
	snapshot := func() (map[string]*string, string) {
		env := map[string]*string{}
		for _, key := range keys {
			if value, ok := os.LookupEnv(key); ok {
				env[key] = &value
			} else {
				env[key] = nil
			}
		}
		file, _ := os.ReadFile(s.envFile)
		return env, string(file)
	}
	decode := func(raw json.RawMessage) body {
		var b body
		dec := json.NewDecoder(bytes.NewReader(raw))
		dec.UseNumber()
		if dec.Decode(&b) != nil {
			return body{}
		}
		return b
	}
	check := func(name string, c settingsCase, ok any, err error) {
		t.Helper()
		label := name + " " + string(c.Input)
		if len(label) > 90 {
			label = label[:90]
		}
		if c.Error != nil {
			if err == nil {
				t.Errorf("%s: no error, Node answered %q", label, c.Error.Message)
			} else if err.Error() != c.Error.Message {
				t.Errorf("%s: error %q, Node %q", label, err.Error(), c.Error.Message)
			}
		} else {
			if err != nil {
				t.Errorf("%s: unexpected error %v", label, err)
			}
			got, _ := json.Marshal(ok)
			sameJSON(t, label, got, c.Value)
		}
		env, file := snapshot()
		for key, want := range c.Env {
			if !samePtr(env[key], want) {
				t.Errorf("%s: %s = %v, Node %v", label, key, deref(env[key]), deref(want))
			}
		}
		if file != c.File {
			t.Errorf("%s: .env file\n got  %q\n want %q", label, file, c.File)
		}
	}
	st := s.api.Settings

	for _, c := range v.General {
		err := st.UpdateGeneral(decode(c.Input))
		check("general", c, map[string]any{"ok": true}, err)
	}
	for _, c := range v.DefaultLimits {
		err := st.SetDefaultRateLimits(decode(c.Input))
		check("defaults", c, map[string]any{"r": map[string]any{"ok": true}, "now": st.DefaultRateLimits()}, err)
	}
	for _, c := range v.DefaultLimitParse {
		t.Setenv(envRateLimit4h, c.Raw)
		if got := st.DefaultRateLimits(); got.FourHour != c.Now.FourHour || got.Weekly != c.Now.Weekly {
			t.Errorf("default limit %q = %+v, Node %+v", c.Raw, got, c.Now)
		}
	}
	os.Unsetenv(envRateLimit4h)
	for _, c := range v.Signup {
		var in any
		_ = json.Unmarshal(c.Input, &in)
		required, err := st.SetSignupKeyRequired(in)
		check("signup", c, map[string]any{"r": map[string]any{"ok": true, "signupKeyRequired": required}, "now": map[string]any{"signupKeyRequired": SignupKeyRequired()}}, err)
	}
	for _, c := range v.SignupParse {
		if c.Raw == "__undefined" {
			os.Unsetenv(envAllowSignup)
		} else {
			t.Setenv(envAllowSignup, c.Raw)
		}
		if got := SignupKeyRequired(); got != c.Now.Required {
			t.Errorf("sign-up %q: required %v, Node %v", c.Raw, got, c.Now.Required)
		}
	}
	os.Unsetenv(envAllowSignup)
	for _, c := range v.Models {
		b := decode(c.Input)
		out, err := st.SetModelsConfig(b["disabledModels"], b["autoEnableNewModels"])
		check("models", c, out, err)
	}
	for _, c := range v.Email {
		out, err := st.UpdateEmail(decode(c.Input))
		check("email", c, struct {
			OK bool `json:"ok"`
			EmailView
		}{true, out}, err)
	}

	for _, key := range keys {
		os.Unsetenv(key)
	}
	view := func(name string) {
		got, _ := json.Marshal(st.Email())
		sameJSON(t, "email defaults "+name, got, v.EmailDefaults[name])
	}
	view("base")
	t.Setenv("NEOAGENT_EMAIL_SMTP_PORT", "465")
	view("secure")
	t.Setenv("NEOAGENT_EMAIL_SMTP_PORT", "0x10")
	view("hex")
	t.Setenv("NEOAGENT_EMAIL_SMTP_SECURE", "Yes")
	t.Setenv("NEOAGENT_EMAIL_NOTIFY_UNUSUAL_LOGIN", "off")
	t.Setenv("NEOAGENT_EMAIL_SMTP_PASS", " s ")
	view("mixed")
}

func idStrings(ids []any) []string {
	out := make([]string, len(ids))
	for i, id := range ids {
		out[i], _ = id.(string)
	}
	return out
}

func samePtr(a, b *string) bool { return (a == nil) == (b == nil) && (a == nil || *a == *b) }

func deref(s *string) string {
	if s == nil {
		return "<unset>"
	}
	return *s
}

func keyShape(code string) bool {
	parts := strings.Split(code, "-")
	if len(parts) != 3 {
		return false
	}
	for _, part := range parts {
		if len(part) != 4 || strings.Trim(part, keyAlphabet) != "" {
			return false
		}
	}
	return true
}
