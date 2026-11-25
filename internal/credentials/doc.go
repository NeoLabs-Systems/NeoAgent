// Package credentials is the credential broker: it binds Bitwarden vault items
// to a browser origin or an HTTPS API target, and lets an agent use a binding
// without ever seeing the secret. Browser fills happen in a protected form the
// model can only submit or cancel; HTTP requests get their authentication
// added here and everything that could echo the secret is redacted from the
// response. Every use is written to credential_usage_audit.
//
// The Bitwarden CLI driver, the browser runtime and the SSRF-safe HTTP executor
// belong to other domains and are reached through the Vault, Browsers and
// Requester interfaces.
package credentials
