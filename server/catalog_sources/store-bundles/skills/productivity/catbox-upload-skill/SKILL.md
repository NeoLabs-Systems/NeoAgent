---
name: Catbox & Litterbox File Uploader
description: Upload local files to Catbox for permanent sharing or Litterbox for temporary sharing. Use when you need a public link for logs, screenshots, archives, media, or other local artifacts.
version: 1.0.0
author: Microck
upstream: https://github.com/Microck/opendots-microck/tree/main/skills/catbox-upload-skill
---

# Catbox & Litterbox File Uploader

Use this skill when the user wants a direct public URL for a local file.

- Prefer `litterbox` for temporary sharing of logs, builds, screenshots, and one-off artifacts.
- Prefer `catbox` for permanent hosting.
- Return the final URL plainly, and for `litterbox` also mention the selected expiry window.

## Command

Run the bundled uploader script:

```bash
bash ~/.neoagent/agent-data/skills/productivity-catbox-upload-skill/scripts/upload.sh /path/to/file
```

## Arguments

- `file_path` (required): local file to upload
- `--service litterbox|catbox` (optional): defaults to `litterbox`
- `--time 1h|12h|24h|72h` (optional): only used for `litterbox`, defaults to `24h`
- `--userhash HASH` (optional): Catbox account hash for uploads tied to a Catbox account

## Examples

Temporary upload with the default 24-hour expiry:

```bash
bash ~/.neoagent/agent-data/skills/productivity-catbox-upload-skill/scripts/upload.sh ./logs/server.log
```

Temporary upload that expires after 1 hour:

```bash
bash ~/.neoagent/agent-data/skills/productivity-catbox-upload-skill/scripts/upload.sh ./build/output.zip --time 1h
```

Permanent upload to Catbox:

```bash
bash ~/.neoagent/agent-data/skills/productivity-catbox-upload-skill/scripts/upload.sh ./artifacts/screenshot.png --service catbox
```

Permanent upload associated with a Catbox account:

```bash
bash ~/.neoagent/agent-data/skills/productivity-catbox-upload-skill/scripts/upload.sh ./artifacts/screenshot.png --service catbox --userhash YOUR_HASH
```

## Expected Output

The script prints exactly one URL on success, for example:

```text
https://litterbox.catbox.moe/abc123.png
```

or:

```text
https://files.catbox.moe/abc123.png
```

## Presenting Results

When the upload succeeds:

- show the returned URL clearly
- mention whether it is temporary or permanent
- if using `litterbox`, include the expiration window

Example response:

```text
File uploaded successfully.

Link: https://litterbox.catbox.moe/abc123.png
Expires in: 24 hours
```

## Limits

- `litterbox`: up to 1 GB, temporary, supports `1h`, `12h`, `24h`, and `72h`
- `catbox`: up to 200 MB, permanent

## Troubleshooting

- If the file does not exist or is unreadable, verify the path first.
- If the upload fails, surface the exact error from the script.
- If `curl` is missing, install it before retrying.
- If Catbox rejects the file, the file may exceed the service limit or violate Catbox content rules.
