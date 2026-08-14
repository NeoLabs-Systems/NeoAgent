# Billing

NeoAgent includes an optional Stripe-based billing system for deployments that
charge users for access. When disabled — the default — no billing routes are
exposed, no payment UI is shown, and no payment-related information appears
anywhere in the application.

## Enable billing

Run the interactive setup wizard:

```bash
neoagent billing setup
```

The wizard prompts for your Stripe API keys, webhook secret, and trial length,
then asks whether to enable billing immediately. Use Stripe test keys
(`sk_test_...`, `pk_test_...`) during development.

To check the current configuration at any time:

```bash
neoagent billing        # or: neoagent billing status
```

To toggle billing without re-running setup:

```bash
neoagent billing enable    # set NEOAGENT_BILLING_ENABLED=true and restart
neoagent billing disable   # set NEOAGENT_BILLING_ENABLED=false and restart
```

When enabled the admin dashboard will show a **Billing** navigation item and
the `/api/billing/*` endpoints become active.

> **Manual alternative** — you can also set variables directly and restart:
> ```bash
> neoagent env set STRIPE_SECRET_KEY sk_live_...
> neoagent env set STRIPE_PUBLISHABLE_KEY pk_live_...
> neoagent env set STRIPE_WEBHOOK_SECRET whsec_...
> neoagent env set NEOAGENT_BILLING_ENABLED true
> neoagent restart
> ```

## Subscription plans

Plans are managed in **Admin › Billing › Plans**. Each plan controls:

| Field | Purpose |
|---|---|
| Name | Displayed to users in the settings submenu |
| Price | Stripe price in cents (0 = free) |
| Billing interval | `month`, `year`, or blank for one-time or free |
| Stripe Price ID | The `price_...` ID from your Stripe dashboard |
| 4h token limit | Per-user 4-hour rolling token budget (blank = server default) |
| Weekly token limit | Per-user 7-day rolling token budget (blank = server default) |
| Allowed models | Comma-separated model IDs; blank = all models accessible |
| Features | Marketing feature strings shown on pricing pages |

Token limits are written directly to the user account when a subscription
becomes active or is updated via webhook. The existing rate-limit enforcement
in the runtime reads them with no additional configuration.

Token limits gate interactive run starts. Background task executions are not
blocked by the internal token admission check, so scheduled and integration
tasks can still run while a user is over quota. Their token usage is still
recorded and included in account and admin usage snapshots.

### Free plan

Create a plan with **Price = 0** to serve as the default for new users. If a
free plan exists when billing is enabled, every new registration is
automatically placed on it.

### Model restrictions

If **Allowed models** is non-empty, users on that plan can only use the listed
model IDs. Models outside the allowlist remain visible in the UI with an
unavailable status so users understand what upgrading unlocks.

Leave the field blank to allow all configured models on a plan.

## User subscriptions

Users manage their subscription in **Settings › Billing** (Flutter client). From
there they can:

- View their current plan, status, and next renewal date
- Upgrade or downgrade through Stripe Checkout
- Open the Stripe Customer Portal to update a payment method or download invoices
- Cancel at the end of the current billing period

### Stripe Checkout

When a user selects a paid plan, the server creates a Stripe Checkout session
and redirects the client to Stripe's hosted payment page. No card data passes
through NeoAgent.

### Stripe Customer Portal

The Customer Portal is a Stripe-hosted page where users can update their
payment method, view billing history, and cancel. Configure the portal in your
[Stripe dashboard](https://dashboard.stripe.com/settings/billing/portal) before
enabling it.

## Free trials

Enable free trials in **Admin › Billing › Plans** by configuring a Stripe price
that supports trials, then setting `BILLING_TRIAL_DAYS` to the desired length
(default: 14 days).

Trials start when a user calls `POST /api/billing/trial` with a plan ID. The
server runs anti-abuse checks before granting a trial:

| Check | Limit |
|---|---|
| IP address | 2 trials per IP per 30 days |
| Email domain | 3 trials per non-common domain per 30 days |
| Account age | Account must be at least 1 day old |
| Device fingerprint | 1 trial per device per 90 days (opaque hash from client) |

The Flutter client is responsible for generating and sending the device
fingerprint. The server hashes it with SHA-256 before storage — the raw
fingerprint is never persisted.

## Webhooks

Stripe sends events to `POST /api/billing/webhook`. Register this URL in your
[Stripe dashboard](https://dashboard.stripe.com/webhooks) under the endpoint
for your account.

Handled events:

| Event | Effect |
|---|---|
| `customer.subscription.created` | Creates a local subscription row |
| `customer.subscription.updated` | Syncs status, period dates, and token limits |
| `customer.subscription.deleted` | Marks subscription canceled |
| `customer.subscription.trial_will_end` | Sends trial-ending email (fires 3 days before) |
| `invoice.payment_succeeded` | Records payment; sends renewal email on cycle |
| `invoice.payment_failed` | Records failure; sends payment-failed email |

Events are idempotent — replaying a webhook event produces the same result.

**Required events to enable in Stripe:**

```
customer.subscription.created
customer.subscription.updated
customer.subscription.deleted
customer.subscription.trial_will_end
invoice.payment_succeeded
invoice.payment_failed
```

### Verifying the webhook locally

Use the Stripe CLI to forward events to a local server during development:

```bash
stripe listen --forward-to http://localhost:3333/api/billing/webhook
```

## Email notifications

If [service email](configuration.md#service-email) is configured, users receive
emails at the following billing events:

| Event | Email |
|---|---|
| Trial started | Confirmation with trial end date |
| Trial ending soon | Reminder 3 days before end |
| Subscription activated | Welcome to the paid plan |
| Subscription renewed | Renewal confirmation |
| Payment failed | Action required with next retry date |
| Subscription canceled | Cancellation confirmation |
| Plan changed | Summary of the new plan |

No emails are sent if SMTP is not configured.

## AI context awareness

When billing is enabled, each AI request includes the user's subscription in
the system prompt:

```
SUBSCRIPTION: User is on the "Pro" plan, status: active.
```

This lets the agent answer questions about the user's plan without promising
models or limits the plan does not include.

## Admin controls

The **Admin › Billing** page provides:

- **Plans** — create, edit, and deactivate subscription plans
- **Subscriptions** — every user subscription, with status filter and pagination
- **Override** — per-row button that assigns a user to a plan without going through Stripe, for comped accounts or repairing a missed webhook

## Configuration reference

| Variable | Default | Purpose |
|---|---|---|
| `NEOAGENT_BILLING_ENABLED` | `false` | Master on/off switch |
| `STRIPE_SECRET_KEY` | required | Stripe server-side API key |
| `STRIPE_PUBLISHABLE_KEY` | required | Stripe client-side key (returned to Flutter) |
| `STRIPE_WEBHOOK_SECRET` | required | Webhook signing secret from Stripe dashboard |
| `BILLING_TRIAL_DAYS` | `14` | Free trial length in days |

All variables can be set with `neoagent env set` or added to `~/.neoagent/.env`
directly. Restart the server after any change.

## Security notes

- NeoAgent stores only Stripe customer IDs and subscription IDs — no card
  numbers, bank details, or PII beyond what Stripe already holds.
- Webhook payloads are verified with HMAC-SHA256 using `STRIPE_WEBHOOK_SECRET`
  before any processing. Requests missing the `stripe-signature` header are
  rejected with 400.
- Trial fingerprints are stored as SHA-256 hashes — the raw IP, email domain,
  and device identifiers are never persisted.
- All billing routes return 404 when `NEOAGENT_BILLING_ENABLED` is not set,
  regardless of whether Stripe credentials are present.
