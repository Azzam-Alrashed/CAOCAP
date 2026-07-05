# CDL v2.0 Asset Pack Manifest

Design-language asset pack for Cocaptain and CoStar. Generated drafts for review and knockout before app import.

**Guide version:** CDL v2.0  
**Primary metaphor:** Mindmap your Web  
**Status key:** `draft` (generated, needs review) · `approved` (ready for knockout / app use)

## Delivery notes

- **Format:** PNG, solid **white background** for easy knockout. Generation does **not** guarantee true alpha transparency.
- **Post-process:** Remove white background in Figma, Photopea, or remove.bg before importing into `Assets.xcassets`.
- **Style lock:** Thick outlines `#0D1B2A`, Cocaptain cyan `#4DB6FF`, CoStar purple `#A78BFA`, gold `#FFC83D`, error magenta `#C3606A`. Flat design with soft gradients only — no realism, no gloss.
- **References:** See `_references/` for CDL board, CoStar board, and locked baselines.
- **App icons:** Filled-background porthole icons live under `appicons/` (see § H). No knockout needed.
- **Out of scope this pack:** Xcode `Assets.xcassets` import and `AppIconService` wiring.

## References

| File | Role |
|------|------|
| `_references/cdl-board.png` | Cocaptain CDL visual guide |
| `_references/costar-board.png` | CoStar visual guide (user-provided) |
| `_references/cocaptain_avatar_idle_approved.png` | Locked Cocaptain avatar baseline |
| `_references/cocaptain_hero_wave_approved.png` | Locked Cocaptain hero baseline |
| `_references/costar_avatar_idle_approved.png` | Locked CoStar avatar baseline |
| `_references/cocaptain_avatar_idle_pilot.png` | Early pilot (superseded by idle_low) |
| `_references/anatomy-poses-v2.png` | Character poses & anatomy sheet (front-facing) |
| `_references/character-turnaround-v2.png` | Full-body turnaround — Front, 3/4 L/R, Profile, Back (both characters) |
| `_references/avatar-head-turnaround-v2.png` | Avatar-mode head turnaround — 8 angles per character |
| `_references/visual-asset-library-v2.png` | Visual Asset Library v2.0 |
| `_references/promo-cards-llm-draft.png` | LLM promo draft (mistakes — do not copy cape/text) |

---

## A. Cocaptain — Avatar Mode

Head + helmet, circular-crop friendly. Intended: chat bubbles, timeline avatars.

| ID | Path | Expression | Intensity | Intended surface | Status |
|----|------|------------|-----------|------------------|--------|
| `cocaptain_avatar_idle_low` | `cocaptain/avatar/cocaptain_avatar_idle_low.png` | Idle | Low | Default chat avatar | draft |
| `cocaptain_avatar_thinking_low` | `cocaptain/avatar/cocaptain_avatar_thinking_low.png` | Thinking | Low | `isThinking` | draft |
| `cocaptain_avatar_thinking_medium` | `cocaptain/avatar/cocaptain_avatar_thinking_medium.png` | Thinking | Medium | Longer processing | draft |
| `cocaptain_avatar_success_medium` | `cocaptain/avatar/cocaptain_avatar_success_medium.png` | Success | Medium | Success / apply | draft |
| `cocaptain_avatar_success_high` | `cocaptain/avatar/cocaptain_avatar_success_high.png` | Success | High | Celebration | draft |
| `cocaptain_avatar_confused_low` | `cocaptain/avatar/cocaptain_avatar_confused_low.png` | Confused | Low | Soft confusion | draft |
| `cocaptain_avatar_confused_medium` | `cocaptain/avatar/cocaptain_avatar_confused_medium.png` | Confused | Medium | Unclear intent | draft |
| `cocaptain_avatar_confused_high` | `cocaptain/avatar/cocaptain_avatar_confused_high.png` | Confused | High | Strong confusion | draft |
| `cocaptain_avatar_error_low` | `cocaptain/avatar/cocaptain_avatar_error_low.png` | Error | Low | Soft error | draft |
| `cocaptain_avatar_error_medium` | `cocaptain/avatar/cocaptain_avatar_error_medium.png` | Error | Medium | Failed turn | draft |
| `cocaptain_avatar_error_high` | `cocaptain/avatar/cocaptain_avatar_error_high.png` | Error / AI overload | High | Overload / limit | draft |

**Count:** 11

---

## B. Cocaptain — Badge Mode

Waist-up + props. Intended: notifications, review CTAs, product cards.

| ID | Path | Expression | Prop level | Intended surface | Status |
|----|------|------------|------------|------------------|--------|
| `cocaptain_badge_idle_low` | `cocaptain/badge/cocaptain_badge_idle_low.png` | Idle | Chest badge only | Notification idle | draft |
| `cocaptain_badge_thinking_low` | `cocaptain/badge/cocaptain_badge_thinking_low.png` | Thinking | L1 gear | Processing badge | draft |
| `cocaptain_badge_thinking_medium` | `cocaptain/badge/cocaptain_badge_thinking_medium.png` | Thinking | L1 gears + nodes | Processing badge | draft |
| `cocaptain_badge_thinking_high` | `cocaptain/badge/cocaptain_badge_thinking_high.png` | Thinking | L2 node network | Complex analysis | draft |
| `cocaptain_badge_success_medium` | `cocaptain/badge/cocaptain_badge_success_medium.png` | Success | L1 check clipboard | Success notification | draft |
| `cocaptain_badge_success_high` | `cocaptain/badge/cocaptain_badge_success_high.png` | Success | L2 clipboard + nodes | Celebration badge | draft |
| `cocaptain_badge_confused_medium` | `cocaptain/badge/cocaptain_badge_confused_medium.png` | Confused | Broken nodes | Confusion badge | draft |
| `cocaptain_badge_error_low` | `cocaptain/badge/cocaptain_badge_error_low.png` | Error | Broken nodes | Error badge | draft |
| `cocaptain_badge_error_high` | `cocaptain/badge/cocaptain_badge_error_high.png` | AI overload | L2 AI nodes | Overload badge | draft |

**Count:** 9

---

## C. Cocaptain — Hero Mode

Full-body active poses. Intended: onboarding, empty states, marketing (composite over separate backgrounds).

| ID | Path | Pose | Mood | Intended surface | Status |
|----|------|------|------|------------------|--------|
| `cocaptain_hero_wave` | `cocaptain/hero/cocaptain_hero_wave.png` | Wave | Friendly idle | Intro / welcome | draft |
| `cocaptain_hero_thumbs_up` | `cocaptain/hero/cocaptain_hero_thumbs_up.png` | Thumbs up | Success medium | Success empty state | draft |
| `cocaptain_hero_working` | `cocaptain/hero/cocaptain_hero_working.png` | Working | Thinking medium | Building / coding | draft |
| `cocaptain_hero_looking_ahead` | `cocaptain/hero/cocaptain_hero_looking_ahead.png` | Looking ahead | Curious | Onboarding | draft |
| `cocaptain_hero_excited` | `cocaptain/hero/cocaptain_hero_excited.png` | Excited | Success high | Celebration | draft |

**Count:** 5

---

## D. Props

Standalone toy-like tools. Intended: badges, stickers, UI ornaments.

### Level 1

| ID | Path | Status |
|----|------|--------|
| `prop_clipboard_lines` | `props/level1/prop_clipboard_lines.png` | draft |
| `prop_clipboard_check` | `props/level1/prop_clipboard_check.png` | draft |
| `prop_clipboard_node` | `props/level1/prop_clipboard_node.png` | draft |
| `prop_gear` | `props/level1/prop_gear.png` | draft |
| `prop_guiding_star` | `props/level1/prop_guiding_star.png` | draft |
| `prop_node_cluster` | `props/level1/prop_node_cluster.png` | draft |

### Level 2

| ID | Path | Status |
|----|------|--------|
| `prop_node_map` | `props/level2/prop_node_map.png` | draft |
| `prop_porthole_capsule` | `props/level2/prop_porthole_capsule.png` | draft |
| `prop_clipboard_chart` | `props/level2/prop_clipboard_chart.png` | draft |

**Count:** 9

---

## E. CoStar — Smaller matching set

Same CDL rules; purple hair `#A78BFA`, yellow/gold star clip, pink-red cape accents per CoStar board.

| ID | Path | Mode | Notes | Intended surface | Status |
|----|------|------|-------|------------------|--------|
| `costar_avatar_idle_low` | `costar/avatar/costar_avatar_idle_low.png` | Avatar | Idle head | CoStar chat avatar | draft |
| `costar_avatar_thinking_low` | `costar/avatar/costar_avatar_thinking_low.png` | Avatar | Dash eyes | CoStar thinking | draft |
| `costar_avatar_success_medium` | `costar/avatar/costar_avatar_success_medium.png` | Avatar | `^ ^` + blush | CoStar success | draft |
| `costar_badge_idle_low` | `costar/badge/costar_badge_idle_low.png` | Badge | Star clip visible | Notification | draft |
| `costar_badge_success_medium` | `costar/badge/costar_badge_success_medium.png` | Badge | Guiding star prop | Success badge | draft |
| `costar_hero_wave` | `costar/hero/costar_hero_wave.png` | Hero | Wave | Onboarding | draft |
| `costar_hero_looking_ahead` | `costar/hero/costar_hero_looking_ahead.png` | Hero | Scout pose | Inspiration | draft |
| `cocaptain_costar_hero_collab` | `duo/cocaptain_costar_hero_collab.png` | Duo | Structure vs scout | Collab / marketing | draft |

**Count:** 8

---

## Totals

| Group | Count |
|-------|------:|
| Cocaptain avatars | 11 |
| Cocaptain badges | 9 |
| Cocaptain heroes | 5 |
| Props | 9 |
| CoStar + duo | 8 |
| Scenes (solo + UI) | 8 |
| Ornaments | 4 |
| Wallpapers | 8 |
| App icons | 3 masters (+ 2 platform sets) |
| **Total** | **65** |

All assets currently status **`draft`**. Mark rows `approved` after visual QA.

---

## F. Scenes & ornaments (art-only promo / UI)

Character and scene art only — **no body copy**. Solid white backgrounds for knockout and compositing in app/website.

### Solo heroes

| ID | Path | Character | Pose | Status |
|----|------|-----------|------|--------|
| `cocaptain_scene_wave` | `scenes/cocaptain_scene_wave.png` | Cocaptain | Full-body wave (no cape) | draft |
| `cocaptain_scene_point` | `scenes/cocaptain_scene_point.png` | Cocaptain | Pointing / guiding | draft |
| `costar_scene_reach_star` | `scenes/costar_scene_reach_star.png` | CoStar | Reaching toward gold star | draft |
| `costar_scene_wave` | `scenes/costar_scene_wave.png` | CoStar | Full-body wave | draft |

### UI scenario crops

| ID | Path | Framing | Status |
|----|------|---------|--------|
| `cocaptain_scene_dashboard` | `scenes/cocaptain_scene_dashboard.png` | Waist-up neutral | draft |
| `costar_scene_dashboard` | `scenes/costar_scene_dashboard.png` | Waist-up neutral | draft |
| `scene_interactive_pair` | `scenes/scene_interactive_pair.png` | Duo + blank chat bubble (no copy) | draft |
| `scene_harmony_pair` | `scenes/scene_harmony_pair.png` | Duo collaboration | draft |

### Ornaments

| ID | Path | Status |
|----|------|--------|
| `ornament_code_window` | `scenes/ornaments/ornament_code_window.png` | draft |
| `ornament_constellation` | `scenes/ornaments/ornament_constellation.png` | draft |
| `ornament_mini_rocket` | `scenes/ornaments/ornament_mini_rocket.png` | draft |
| `ornament_guiding_star_glow` | `scenes/ornaments/ornament_guiding_star_glow.png` | draft |

**Scene pack count:** 12

### Scene QA notes

- Cocaptain must **not** wear a cape (CoStar may have magenta cape).
- Prefer simple mitten hands; avoid detailed fingers.
- Composite typography and space backgrounds in Figma/website — do not bake promo copy into assets.
- Knock out white (or soft vignette) before app import.

---

## G. Wallpapers / posters

Full-bleed portrait art (not white knockout). Polished porthole icon style with soft glossy glass highlights.

| ID | Path | Notes | Status |
|----|------|-------|--------|
| `cocaptain_wallpaper` | `intro/cocaptain_wallpaper.png` | Earlier porthole draft (not preferred for daily lock screen) | draft |
| `cocaptain_wallpaper_earth_rise` | `intro/cocaptain_wallpaper_earth_rise.png` | Epic Earth rise; **1242×2688 (9:16)**; Cocaptain small on rail; quiet navy top for clock; no body copy | draft |
| `cocaptain_wallpaper_night_watch` | `intro/cocaptain_wallpaper_night_watch.png` | Calm premium-minimal night watch; **1242×2688 (9:16)**; Cocaptain medium-small, cyan rim glow, empty navy top; no porthole/planet | draft |
| `cocaptain_wallpaper_moon` | `intro/cocaptain_wallpaper_moon.png` | On the moon; **1242×2688 (9:16)**; Cocaptain on lunar surface, empty navy top for clock; no body copy | draft |
| `cocaptain_wallpaper_coding` | `intro/cocaptain_wallpaper_coding.png` | Coding / builder; **1242×2688 (9:16)**; Cocaptain with toy code window, empty navy top; no readable UI | draft |
| `costar_wallpaper_guiding_star` | `intro/costar_wallpaper_guiding_star.png` | CoStar scout/inspirer; **1242×2688 (9:16)**; purple bun + gold star clip, guiding star, empty navy top | draft |
| `costar_wallpaper_moon` | `intro/costar_wallpaper_moon.png` | CoStar on the moon; **1242×2688 (9:16)**; lunar surface, empty navy top; pairs with cocaptain_wallpaper_moon | draft |
| `duo_wallpaper_side_by_side_watch` | `intro/duo_wallpaper_side_by_side_watch.png` | Cocaptain + CoStar calm night watch; **1242×2688 (9:16)**; side-by-side on rail, empty navy top | draft |

**Reference:** `_references/cocaptain_porthole_icon.png`, `_references/costar-board.png`

---

## H. App icons (iOS / Android / brand)

Alternate app icons for CAOCAP. **Filled backgrounds** (space navy `#0D1B2A` or soft in-porthole gradients) — no white knockout required. Square **1024×1024** masters; no transparency; no baked rounded corners.

**Design direction:** Avatar-mode head in glass helmet, centered in a thick navy **porthole ring**. Bold outlines, readable at ~40px. No text or wordmarks.

| ID | Path | Character | Framing | Intended use | Status |
|----|------|-----------|---------|--------------|--------|
| `cocaptain_appicon` | `appicons/cocaptain/cocaptain_appicon_1024.png` | Cocaptain | Porthole + cyan glow | Alternate icon (new) | draft |
| `costar_appicon` | `appicons/costar/costar_appicon_1024.png` | CoStar | Porthole + purple glow | Alternate icon (`AppIcon_5`) | draft |
| `caocap_duo_appicon` | `appicons/duo/caocap_duo_appicon_1024.png` | Cocaptain + CoStar | Dual porthole brand | Marketing / future default | draft |

### Cocaptain set (`appicons/cocaptain/`)

| Asset | Path | Notes |
|-------|------|-------|
| Master | `cocaptain_appicon_1024.png` | 1024×1024 PNG |
| iOS ladder | `Assets.xcassets/AppIcon.appiconset/` | Full iPhone / iPad / Watch / Mac sizes + `Contents.json` (exported from master via `sips`) |
| App Store | `appstore.png` | 512×512 |
| Play Store | `playstore.png` | 1024×1024 |
| Android | `android/mipmap-*/ic_launcher.png` | mdpi–xxxhdpi |

**References used:** `_references/cocaptain_avatar_idle_approved.png`, `_references/cocaptain_porthole_icon.png`

**QA:** Cyan hair `#4DB6FF`, no cape, navy porthole ring, filled navy starfield background.

### CoStar set (`appicons/costar/`)

| Asset | Path | Notes |
|-------|------|-------|
| Master | `costar_appicon_1024.png` | Regenerated CDL v2 v2 (avatar head, star clip, headphones) |
| iOS ladder | `Assets.xcassets/AppIcon.appiconset/` | Regenerated from new master |
| App Store | `appstore.png` | 512×512 |
| Play Store | `playstore.png` | 1024×1024 |
| Android | `android/mipmap-*/ic_launcher.png` | mdpi–xxxhdpi |

**References used:** `_references/costar_avatar_idle_approved.png`

**QA:** Purple hair `#A78BFA`, gold star clip `#FFC83D`, purple headphones, magenta cape accents optional at collar only.

**iOS wiring (not in this pack):** Import `AppIcon.appiconset` into Xcode as `AppIcon_5` (CoStar) or a new `AppIcon_*` set for Cocaptain / duo. See `AppIconService.swift`.

### Duo / brand variant (`appicons/duo/`)

| Asset | Path | Notes |
|-------|------|-------|
| Master | `caocap_duo_appicon_1024.png` | Side-by-side dual portholes; no size ladder yet |

**Count:** 3 masters + 2 full platform sets (Cocaptain, CoStar)

---

## I. Personalization app wiring (iOS)

CDL assets imported into `Assets.xcassets` for personalization v2 and chat avatars.

| Asset | App imageset | Source |
|-------|--------------|--------|
| Cocaptain hero (picker) | `CopilotHeroCocaptain` | `cocaptain/hero/cocaptain_hero_wave.png` |
| CoStar hero (picker) | `CopilotHeroCostar` | `costar/hero/costar_hero_wave.png` |
| Cocaptain avatar (chat) | `CopilotAvatarCocaptain` | `cocaptain/avatar/cocaptain_avatar_idle_low.png` |
| CoStar avatar (chat) | `CopilotAvatarCostar` | `costar/avatar/costar_avatar_idle_low.png` |
| Moon stage (personalization picker) | `PersonalizationMoonStage` | `intro/personalization_moon_stage.png` — dedicated moon horizon strip, transparent background, no character |

**UI references:** `ui-mockups/onboarding_copilot_picker_mockup.png`, `ui-mockups/onboarding_copilot_hero_select_mockup.png`

**Post-process:** White backgrounds knocked out before import. Selection persists as `selectedCopilot` in `PersonalizationSurveyAnswers` (survey `v2`).

---

## QA checklist (per asset)

- [ ] Thick outer outline, consistent internal detail weight
- [ ] No gloss / no photorealism
- [ ] Palette matches CDL (cyan / purple / gold / error magenta as appropriate)
- [ ] Avatars readable at ~40px
- [ ] Heroes ~3 heads tall
- [ ] Prop complexity matches Level 1 vs Level 2
- [ ] White background clean for knockout
- [ ] Scene assets have no body copy

## Next steps (not in this pack)

1. Review and mark approved assets in this manifest.
2. Knock out white backgrounds.
3. Export @2x / @3x for iOS.
4. Import into `Assets.xcassets` and wire expression states in CoCaptain UI.
5. Composite promo cards / website sections using scenes + ornaments + your typography.
