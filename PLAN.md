# MyTube — remaining phases

Phases 1–11 are done (core app, Shorts, upload, sign-in).
Claude works through this list automatically (see CLAUDE.md) and stops at
each 🛑 checkpoint.

## Phases

- [x] ~~**Phase 11.5 — Music**~~ — SKIPPED (user decision, 2026-10-29). Do not build.

- [x] **Phase 12 — Security**
  - Final Firestore rules.
  - Walkthrough to restrict the Cloudinary preset (formats, folder, size/length).
  - App Check with reCAPTCHA v3, plus a debug token for local runs (token never committed).

- [ ] **Phase 13 — Channels**
  - Channel page: banner, avatar, name, @handle, subscribers, video count,
    Subscribe, tabs Home / Videos / Shorts / Playlists / About.
  - Tapping a channel name or avatar opens the channel.
  - "Your channel" editing: name, handle, description, banner, avatar color.
  - subscriberCount ±1, enforced by rules.
  - Subscriptions tab: avatar row, "All" chip, paginated feed, empty states.

> 🛑 **CHECKPOINT A** — after Phase 13. Stop and wait for the user to test.

- [ ] **Phase 14 — Comments**
  - Replies with an "X replies" expander, likes, edit/delete own, "(edited)".
  - Video owner can pin one comment and give a creator heart.
  - commentCount kept up to date.
  - Top / Newest sort with pagination.

- [ ] **Phase 15 — Playlists**
  - Create, rename, delete, Public/Private.
  - "Save to…" checkbox sheet from ⋮ and the Save button.
  - Drag to reorder, Play all, Shuffle, playlist panel on the watch page.
  - Liked and Watch later as built-in playlists.
  - History grouped by day: remove item, clear, pause history, search history.

- [ ] **Phase 16 — Studio**
  - Manage your videos: thumbnail, title, visibility, date, views, likes, comments.
  - Edit fields and thumbnail.
  - Delete removes Firestore data only (the Cloudinary file is deleted manually).
  - Per-video and channel stats.

> 🛑 **CHECKPOINT B** — after Phase 16. Stop and wait for the user to test.

- [ ] **Phase 17 — Notifications (in-app)**
  - An upload fans out to subscribers (batched, capped).
  - Replies, and comments on my video, notify me.
  - Real unread count, read/unread, tap to open, swipe or menu to remove.
  - Explain the limits of doing this without Cloud Functions.

- [ ] **Phase 18 — Discovery**
  - Keyword prefix search with filters (All / Videos / Shorts / Channels)
    and sort (relevance / date / views), plus channel results.
  - Explore / Trending.
  - Simple recommendations.
  - Hide: Not interested / Don't recommend channel.
  - Infinite scroll everywhere.

- [ ] **Phase 19 — Watch extras**
  - Deep links `/watch?v=ID`, `/shorts/ID`, `/@handle` that survive a refresh.
  - Share copies the link.
  - Keyboard shortcuts.
  - ⋮ menu: Not interested, Don't recommend channel, Report (a report doc),
    Save to playlist.
  - Remember volume, mute and speed.

> 🛑 **CHECKPOINT C** — after Phase 19. Stop and wait for the user to test.

- [ ] **Phase 20 — Release-ready (local only)**
  - `flutter build web` with no warnings.
  - Security review.
  - A "how to publish later" note. NO deploy, no Hosting, no PWA setup.

- [ ] **Phase 21 — Polish and tests**
  - Check all states and animations.
  - Performance: small Cloudinary transforms, fewer rebuilds and reads.
  - Unit and widget tests.
  - A full manual test checklist.

> 🛑 **CHECKPOINT D** — after Phase 21 (final). Stop and wait for the user.

## Manual steps for me

Console and deploy steps Claude can't do (or isn't allowed to). Do them at
the next checkpoint, top to bottom, and tick them off.

Format: `- [ ] (Phase X) What to do — where — why`

- [ ] (Phase 12) Restrict the Cloudinary preset `mytube_unsigned`: asset folder, overwrite off, allowed formats (optional: max size, `du_900`) — console.cloudinary.com → Settings → Upload → Upload presets — so strangers can't upload anything to your account. Steps: `docs/SECURITY_SETUP.md` §1.
- [ ] (Phase 12) Deploy the rules: `firebase deploy --only firestore:rules,firestore:indexes` — terminal in `mytube/` — the new rules only work after deploying. §2.
- [ ] (Phase 12) Make a reCAPTCHA v3 key (domain `localhost`) — google.com/recaptcha/admin — needed for App Check. §3a.
- [ ] (Phase 12) Register the web app in App Check with the reCAPTCHA **secret** key — Firebase console → App Check → Apps — §3b.
- [ ] (Phase 12) Generate a debug token and paste it (plus the site key) into `app_check.local.json` (git-ignored) — App Check → Apps → ⋮ → Manage debug tokens — §3c.
- [ ] (Phase 12) Run with `flutter run -d chrome --dart-define-from-file=app_check.local.json`, check "Verified" requests, then click **Enforce** for Cloud Firestore — Firebase console → App Check → APIs — §3d–3e. Only enforce once requests show as verified.

## Progress log

Newest entry at the bottom.

- 2026-10-29 — Automation setup added (CLAUDE.md, PLAN.md,
  .claude/settings.json, .gitignore secrets section). No phase started.
  Phase 11.5 Music skipped by the user. Phase 11 sign-in changes were left
  uncommitted on purpose.
- 2026-10-29 — **Phase 12 (Security) done.** Final `firestore.rules`: every
  write is checked field by field (types, lengths, allowed keys, server
  times); video and comment like counters only move ±1 together with the
  user's own reaction / commentLike record (`getAfter` checks both ways);
  uploads must start at 0 views/likes, use the uploader's own channel and
  profile name, and point to `res.cloudinary.com/hcrar4ku`; comments must
  use the author's real name/@handle; durationSeconds may only grow (max
  4 h); seed creates are limited to the 13 seed ids; profiles can't be
  deleted. App Check (`firebase_app_check`, reCAPTCHA v3 + debug token via
  `--dart-define-from-file=app_check.local.json`, git-ignored). Upload
  checks: formats mp4/mov/webm/m4v + jpg/jpeg/png/webp, 50 MB / 5 MB,
  Shorts ≤ 60 s, videos ≤ 15 min. Walkthrough in `docs/SECURITY_SETUP.md`.
  Files: firestore.rules, firestore.indexes.json (new), firebase.json,
  lib/core/security/app_check.dart (new), lib/core/utils/upload_validation.dart
  (new), lib/main.dart, lib/data/repositories/upload_repository.dart,
  lib/features/upload/upload_flow.dart + upload_screen.dart,
  app_check.example.json (new), .gitignore, pubspec.yaml/lock,
  docs/SECURITY_SETUP.md (new). `dart format` also reformatted ~50 existing
  files (style only). The uncommitted Phase 11 sign-in files are included
  in this commit. Tests: test/upload_validation_test.dart,
  test/app_check_test.dart, test/firestore_rules_test.dart (20 tests).
  Not done: the rules could not be run in the emulator (no Java on this
  PC); they get compiled when you deploy them.
