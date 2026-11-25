package authapi

import (
	"fmt"
	"net/http"
	"strings"
)

// escapeHTML matches the Node helper: & < > " ' only.
var htmlEscaper = strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;", "'", "&#39;")

func escapeHTML(s string) string { return htmlEscaper.Replace(s) }

func writePage(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	_, _ = fmt.Fprint(w, body)
}

const pageHead = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>%s</title>
  </head>
  <body style="margin:0;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#0f172a;">
    <main style="min-height:100vh;display:grid;place-items:center;padding:24px;">
      <section style="max-width:520px;width:100%%;background:#ffffff;border:1px solid #e2e8f0;border-radius:16px;padding:32px;box-shadow:0 18px 45px rgba(15,23,42,0.08);">
        <div style="display:inline-block;border-radius:999px;background:#ccfbf1;color:#0f766e;font-weight:800;font-size:12px;letter-spacing:.08em;text-transform:uppercase;padding:8px 11px;">NeoAgent</div>
        <h1 style="margin:22px 0 0;font-size:26px;line-height:1.25;">%s</h1>
        <p style="margin:14px 0 0;color:#475569;font-size:15px;line-height:1.65;">%s</p>
`

const pageTail = `      </section>
    </main>
  </body>
</html>`

// sendEmailConfirmationPage answers a confirmation link click.
func sendEmailConfirmationPage(w http.ResponseWriter, ok bool, title, message string) {
	accent, status := "#b45309", http.StatusBadRequest
	if ok {
		accent, status = "#0f766e", http.StatusOK
	}
	t, m := escapeHTML(title), escapeHTML(message)
	body := fmt.Sprintf(pageHead, t, t, m) +
		`        <a href="/" style="display:inline-block;margin-top:26px;background:` + accent + `;color:#ffffff;text-decoration:none;font-weight:700;border-radius:8px;padding:13px 18px;">Open NeoAgent</a>
` + pageTail
	writePage(w, status, body)
}

// sendPasswordResetPage shows the reset form, or its error or success state.
func sendPasswordResetPage(w http.ResponseWriter, token, errText string, success bool) {
	title := "Reset password"
	message := "Enter a new password for your NeoAgent account."
	if success {
		title = "Password changed"
		message = "Your NeoAgent password has been changed. You can return to the app and sign in."
	}
	safeToken, safeError := escapeHTML(token), escapeHTML(errText)

	var b strings.Builder
	b.WriteString(fmt.Sprintf(pageHead, title, title, message))
	b.WriteString("        ")
	if safeError != "" {
		b.WriteString(`<p style="margin:18px 0 0;color:#b91c1c;background:#fee2e2;border:1px solid #fecaca;border-radius:8px;padding:12px;font-size:13px;">` + safeError + `</p>`)
	}
	b.WriteString("\n        ")
	if success {
		b.WriteString(`
          <a href="/" style="display:inline-block;margin-top:26px;background:#0f766e;color:#ffffff;text-decoration:none;font-weight:700;border-radius:8px;padding:13px 18px;">Open NeoAgent</a>
        `)
	} else {
		b.WriteString(`
          <form method="post" action="/api/auth/password/reset" style="margin-top:24px;">
            <input type="hidden" name="token" value="` + safeToken + `">
            <label style="display:block;font-weight:700;font-size:13px;margin-bottom:8px;">New password</label>
            <input name="password" type="password" autocomplete="new-password" minlength="8" required style="width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:8px;padding:13px 12px;font-size:15px;">
            <label style="display:block;font-weight:700;font-size:13px;margin:16px 0 8px;">Confirm new password</label>
            <input name="confirmPassword" type="password" autocomplete="new-password" minlength="8" required style="width:100%;box-sizing:border-box;border:1px solid #cbd5e1;border-radius:8px;padding:13px 12px;font-size:15px;">
            <button type="submit" style="margin-top:22px;width:100%;background:#0f766e;color:#ffffff;border:0;border-radius:8px;padding:14px 18px;font-weight:800;font-size:15px;cursor:pointer;">Change password</button>
          </form>
        `)
	}
	b.WriteString("\n")
	b.WriteString(pageTail)
	status := http.StatusOK
	if errText != "" {
		status = http.StatusBadRequest
	}
	writePage(w, status, b.String())
}
