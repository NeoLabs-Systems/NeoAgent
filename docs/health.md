---
title: Health
sidebar_label: Health
description: Optional Health Connect sync from the Android app to your NeoAgent server, readable by your agent.
---

# Health

**The Android app can copy Health Connect data to your NeoAgent server, where your agent can read it.**

## ❤️ Set it up

1. Open **Health** in the Android app. The page only appears on Android.
2. Under **Device access**, press **Request permissions** and grant access in Health Connect.
3. Under **Backend sync**, press **Sync now** for a first upload.

- **Background sync.** While you are signed in and permissions are granted, the app syncs about every 15 minutes.
- **Status.** **Last Sync Summary** and **Stored Metrics** show what reached the server.

## 📊 What is synced

| Data | Health Connect record |
| --- | --- |
| Steps | `StepsRecord` |
| Heart rate | `HeartRateRecord` |
| Sleep | `SleepSessionRecord` |
| Exercise | `ExerciseSessionRecord` |
| Weight | `WeightRecord` |

- **No iOS or HealthKit.** Health sync is Android only.

## 🤖 How the agent uses it

- **Ask in chat.** The agent reads stored metrics with its `read_health_data` tool.
- **Automate.** The `health_metric_recorded` [trigger](automation.md) runs a task when a sync holds a matching metric, optionally above or below a value.

## 🔐 Privacy

- **Stays on your server.** Records go to your NeoAgent server only. A hosted model sees what the agent reads.
- **Revoking stops future reads.** Removing Health Connect access in Android settings keeps records already uploaded.
- **No selective delete.** Stored health records are removed only when the account is deleted.
- **Treat it as sensitive.** Use HTTPS for remote access, protect the account, and include the database in backup and deletion plans.
