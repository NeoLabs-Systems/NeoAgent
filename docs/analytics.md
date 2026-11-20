# Analytics

NeoAgent reports coarse product and host statistics to the NeoLabs analytics service.

## Configuration

Analytics are enabled by default. Set `ANALYTICS_ENABLED=false` in the server's `.env` and restart the server to disable browser and server reporting. With Docker Compose, set it in the Compose project's `.env` and recreate the container. The browser also respects Do Not Track and Global Privacy Control.

## What is reported

- **Browser activity** includes the page area (landing or app), page load time band, back/forward navigation, capped counts of clicks and browser errors, and a heartbeat once per minute while the tab is visible.
- **Feature requests** are batched counts of browser API requests to selected feature groups, split by read/write and broad outcome. Only fixed feature labels are sent. Countly's event count is the number of observed requests in the batch. Browser reporting covers the landing page and web app. CLI, API-only and native app activity is outside this coverage.
- **Host snapshots** are sent at server startup and hourly. They include the app version, Node major version, OS, architecture, and coarse bands for CPU capacity, RAM, memory usage, load, process memory and uptime. OS-reported values may reflect the host rather than container limits.

The browser sends event-only requests to Countly with credentials omitted and no referrer. Countly requires a `device_id` field, so all browsers share one stream label and all server instances share another. No sessions, individual identifiers, cookies, browser language, screen dimensions, full URLs, request contents, error messages, or hostnames are included in event payloads. The Countly endpoint and its reverse proxy can still see the source IP and normal HTTP request headers, which can include the browser origin. Configure their access logs and retention accordingly.

Use Countly's **Events** view for the counters and segment breakdowns. A browser heartbeat represents a visible tab reporting activity. A host snapshot represents a report from a running server. Neither stream supports counting unique devices or installations.
