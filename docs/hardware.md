---
title: Waveshare ESP32-S3 1.8inch AMOLED Setup
sidebar_label: Waveshare 1.8inch AMOLED
---

# Waveshare ESP32-S3 1.8inch AMOLED Setup

Use this only if you want to build or flash this board:

Waveshare ESP32-S3 1.8inch AMOLED Touch Display Dev Board with Battery x 1.

When working on this ESP-IDF wearable target, keep generated artifacts out of version control.

## What Is Ignored

The root ignore config excludes generated files under `firmware/**`:

- `build/`
- `managed_components/`
- `sdkconfig`
- `sdkconfig.old`
- `dependencies.lock`

## Why

This keeps `git status` focused on real wearable source changes instead of local build output.

## Verify

```bash
git ls-files --others --exclude-standard firmware
```

You should only see actual project files you intend to track.
