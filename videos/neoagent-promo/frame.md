---
version: alpha
name: NeoAgent — Frame (video / frame layer)
description: >
  Video layer of the NeoAgent product system. Taken from the Flutter app's dark palette
  (flutter_app/lib/src/theme/palette.dart) and the landing page's type voice: deep olive
  ground, warm gold as the one accent, sage for "done" states, Fraunces serif for the few
  words the film says, Geist for UI-adjacent text, Geist Mono for labels. Not a preset:
  the brief requires the app's own palette and Geist.
unit: the frame — 1920×1080
principle: the product is the picture · one accent · type arrives late and says little

colors:
  canvas: "#0E1511"
  surface: "#171F1A"
  surface-2: "#1C261F"
  ink: "#ECEFE5"
  ink-2: "#AEB7A6"
  muted: "#7E8877"
  gold: "#E1B052"
  sage: "#84BA87"
  hairline: "rgba(224, 240, 224, 0.10)"

typography:
  display:   { fontFamily: "Fraunces", px: 112, weight: 560, lineHeight: 1.0, tracking: "-0.03em", opsz: 144 }
  display-italic: { fontFamily: "Fraunces", px: 112, weight: 420, style: italic, color: gold }
  headline:  { fontFamily: "Fraunces", px: 76, weight: 560, lineHeight: 1.02, tracking: "-0.025em" }
  wordmark:  { fontFamily: "Geist", px: 64, weight: 600, tracking: "-0.03em" }
  body:      { fontFamily: "Geist", px: 30, weight: 400, lineHeight: 1.45, color: ink-2 }
  label:     { fontFamily: "Geist Mono", px: 20, weight: 500, tracking: "0.22em", upper: true, color: gold }
  label-quiet: { fontFamily: "Geist Mono", px: 20, weight: 500, tracking: "0.22em", upper: true, color: muted }

spacing:
  frame-pad: "96px"
  radius-window: "28px"
  radius-card: "18px"

components:
  app-window:
    description: "A real UI plate (3200×2000 capture) shown inside a window: radius-window corners, 1px hairline ring, deep soft shadow (0 60px 120px -30px rgba(0,0,0,.75)), faint top sheen. Displayed at 0.5× (1600×1000) or larger; never above 1:1 of the 2× capture (scale ≤ 2 relative to 0.5×)."
  eyebrow:
    typography: "{typography.label}"
    description: "Gold dot (12px, 4px soft ring) + uppercase mono label; quiet part in label-quiet after a middle dot."
  mascot-tile:
    description: "The NeoAgent mark: a near-black rounded tile (radius 22%) with a 9×9 dot matrix. Lit dots #F0C062 with a soft glow, unlit dots rgba(225,176,82,.13). Idle face rows: '.........','.........','..##.##..','..##.##..','..##.##..','.........','.........','.........','.........'. Blink: rows 2–4 collapse to row 4 only for 3 frames."
  grain:
    description: "Fine monochrome noise overlay, 6–8% opacity, overlay blend, on every frame. Static (not animated)."
  light:
    description: "Ground lighting: a warm gold radial from the top-right (≈13% alpha) and a faint sage radial bottom-left (≈7%), over a soft top-to-bottom darkening. Static per frame."
---

## Overview

NeoAgent is a self-hosted personal AI agent. The film shows the real app working; the brand speaks once, late.

## Do

- Real UI pixels only, from `assets/` pieces at their `layout.json` positions.
- One accent: gold. Sage only on "completed/active" UI that already carries it.
- Serif words are lowercase-led sentences, few of them.

## Don't

- No purple/blue AI gradients, sparkles, bokeh, glassmorphism, robot imagery.
- No paragraphs on screen. No bouncy easing. No looping breathing.
- No rebuilt product UI except a single moving component (e.g. typed text inside the real composer).
