# NeoAgent Design System

Reference for UI/UX conventions across the Flutter workspace. When adding new screens or widgets, use the tokens and patterns documented here rather than raw values.

---

## Tokens

### Spacing — `AppSpacing` (main_spacing.dart)

| Token | Value | Use |
|-------|-------|-----|
| `AppSpacing.xs` | 8px | Tight internal gaps, icon-to-label |
| `AppSpacing.sm` | 12px | Component internal padding |
| `AppSpacing.md` | 16px | Standard padding, list item spacing |
| `AppSpacing.lg` | 24px | Section gaps |
| `AppSpacing.xl` | 32px | Screen-level margins |

Page-level horizontal padding is handled by `_pagePadding(context)` (20–40px responsive). Do not hardcode page margins.

### Border Radius — `AppRadius` (main_spacing.dart)

| Token | Value | Use |
|-------|-------|-----|
| `AppRadius.tag` | 8px | Code blocks, chips, inline badges |
| `AppRadius.card` | 14px | Secondary cards, list items, blockquotes |
| `AppRadius.input` | 18px | Buttons, text fields (matches theme) |
| `AppRadius.panel` | 28px | Major glass surfaces, primary cards (matches theme) |
| `AppRadius.pill` | 999px | Avatars, full-pill badges, status indicators |

### Typography — `main_theme.dart`

| Function | Size | Weight | Use |
|----------|------|--------|-----|
| `_displayTitleStyle(size)` | 28px default | w700 | Section headers, page titles |
| `_heroTitleStyle(size)` | 24px default | w800 | Stats, empty-state headlines, splash copy |
| `_sectionEyebrowStyle()` | 12px | w700 | Category labels above sections |
| Theme `titleMedium` | 18px | w600 | App bar titles, panel headers |
| Theme `bodyMedium` | — | — | Body text (always prefer theme over `TextStyle()`) |

**Rules:**
- Minimum font size: **12px**. Never go below this for legibility.
- Use `Theme.of(context).textTheme.bodyMedium?.copyWith(color: ...)` instead of bare `TextStyle(color: ...)` to guarantee font-family inheritance.
- Defined weights: **w600** (sub-labels), **w700** (standard bold), **w800** (hero/display). Do not use w400, w500, or w900.

---

## Color System

Colors are defined in `src/theme/palette.dart` and accessed via theme-aware getters in `main_theme.dart`.

### Background layers (darkest → lightest prominence)

```
_bgPrimary → _bgSecondary → _bgTertiary → _bgCard
```

### Text hierarchy

```
_textPrimary (readable body) → _textSecondary (supporting) → _textMuted (subtle, disabled)
```

### Accents

- `_accent` — gold/brown, primary interactive elements
- `_accentHover` — lighter gold, hover/focus states
- `_accentAlt` — teal, secondary highlights, assistant avatar glow
- `_accentMuted` — low-saturation accent for backgrounds

### Semantic status colors

| Color | Meaning | Never use for |
|-------|---------|---------------|
| `_success` | Completed, connected, healthy | General decoration |
| `_warning` | In-progress, caution | Errors |
| `_danger` | Error, destructive action, disconnected | Warnings |
| `_info` | Informational, neutral status | Alerts requiring action |

### Hardcoded color rules

- **Do not** use `Color(0x...)` or `Colors.X` literals in widget trees. Use palette getters.
- **Exception 1:** `Color(0xFF4285F4)` — Google Sign-In brand blue, required by Google branding guidelines.
- **Exception 2:** `_qrPanel*` constants in `main_app_shell.dart` — intentional deep-space atmosphere for the QR login panel, defined as named constants at file scope.
- `Colors.transparent` and `Colors.white/black` with `.withValues(alpha:)` for glass overlays are acceptable when no semantic color applies.

---

## Component Patterns

### Glass surface

Use `_GlassSurface` from `main_shared.dart`. Do not duplicate the backdrop-blur + fill + border pattern inline.

Parameters: `child`, `borderRadius` (default `AppRadius.panel`), `padding`.

### Inline status messages

- Errors → `_InlineError(message: '...')` from `main_shared.dart`
- Success → `_InlineSuccess(message: '...')` from `main_shared.dart`

Do not inline `Container(color: _danger...)` patterns — use these shared widgets so error styling stays consistent.

### Empty states

Pattern: eyebrow label → icon → headline (`_heroTitleStyle`) → helper text (`_textSecondary`).

### Dialogs

- Confirm/cancel: **Cancel** (outlined, left) + **primary action** (filled, right)
- Destructive: **Cancel** (left) + **Delete** (filled with `_danger` background, right)
- Avoid "OK" — always use a specific verb (Save, Connect, Remove, etc.)

### Buttons

- **Primary action:** `FilledButton`
- **Secondary/cancel:** `OutlinedButton`
- **Tertiary/nav links:** `TextButton`
- **Icon-only actions:** `IconButton` — always include `tooltip:` with a descriptive label

---

## Accessibility

- Every `IconButton` must have `tooltip: 'Descriptive action'`.
- Prefer `InkWell` over `GestureDetector` for tappable surfaces — `InkWell` inherits Material semantics. If you must use `GestureDetector`, wrap it with `Semantics(button: true, label: '...')`.
- Minimum touch target: 44×44px (Material guideline). Use `minimumSize` on `ButtonStyle` or `IconButton.styleFrom` if needed.
- Do not rely on color alone to convey state — pair color with an icon or label.

---

## Animation

| Animation | Duration | Curve |
|-----------|----------|-------|
| Page entrance (slide + fade) | 700ms | `Curves.easeOutCubic` |
| Button / container hover | 180ms | `Curves.easeOutCubic` |
| Ambient background orbs | 24 000ms | `Curves.easeInOut` (looping) |
| Opacity fades | 140–180ms | default |

---

## Responsive layout

| Breakpoint | Value | Layout change |
|------------|-------|---------------|
| `AppBreakpoints.mobile` | 480px | Sidebar becomes modal, single-column |
| `AppBreakpoints.tablet` | 960px | Two-column layouts activate |
| Desktop implicit | 1280px+ | Full sidebar + main panel |

Use `_pagePadding(context)` for horizontal screen padding. Do not hardcode `EdgeInsets.symmetric(horizontal: 20)` — the helper already handles responsive scaling.

---

## File conventions

| What | Where |
|------|-------|
| Color palette | `lib/src/theme/palette.dart` |
| Theme builder + text styles | `lib/main_theme.dart` |
| Spacing + radius tokens | `lib/main_spacing.dart` |
| Shared widgets | `lib/main_shared.dart` |
| Navigation enums + labels | `lib/main_navigation.dart` |
| App state | `lib/main_controller.dart` |

**Do not** define new reusable widgets in feature files (`main_chat.dart`, `main_operations.dart`, etc.) — add them to `main_shared.dart` so they are available across the app.
