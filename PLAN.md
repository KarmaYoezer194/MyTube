# MyTube — remaining phases

Phases 1–11 are done (core app, Shorts, upload, sign-in).
Claude works through this list automatically (see CLAUDE.md) and stops at
each 🛑 checkpoint.

## Phases

- [x] ~~**Phase 11.5 — Music**~~ — SKIPPED (user decision, 2026-10-29). Do not build.

- [ ] **Phase 12 — Security**
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

_(none yet)_

## Progress log

Newest entry at the bottom.

- 2026-10-29 — Automation setup added (CLAUDE.md, PLAN.md,
  .claude/settings.json, .gitignore secrets section). No phase started.
  Phase 11.5 Music skipped by the user. Phase 11 sign-in changes were left
  uncommitted on purpose.
