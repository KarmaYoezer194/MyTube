# MyTube — remaining phases

Phases 1–11 are done (core app, Shorts, upload, sign-in).
Claude builds ONE phase when asked, then stops (see CLAUDE.md).

## Phases

- [x] ~~**Phase 11.5 — Music**~~ — SKIPPED (user decision, 2026-10-29). Do not build.

- [x] **Phase 12 — Security**
  - Final Firestore rules.
  - Walkthrough to restrict the Cloudinary preset (formats, folder, size/length).
  - App Check with reCAPTCHA v3, plus a debug token for local runs (token never committed).

- [x] **Phase 13 — Channels**
  - Channel page: banner, avatar, name, @handle, subscribers, video count,
    Subscribe, tabs Home / Videos / Shorts / Playlists / About.
  - Tapping a channel name or avatar opens the channel.
  - "Your channel" editing: name, handle, description, banner, avatar color.
  - subscriberCount ±1, enforced by rules.
  - Subscriptions tab: avatar row, "All" chip, paginated feed, empty states.



- [x] **Phase 14 — Comments**
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
- [ ] (Phase 12 + 13) Deploy the rules AND the new index: `firebase deploy --only firestore:rules,firestore:indexes` — terminal in `mytube/` — the new rules only work after deploying, and the channel tabs + Subscriptions feed need the index (it takes a few minutes to build; until then those lists show "Couldn't load"). §2.
- [ ] (Phase 12) Make a reCAPTCHA v3 key (domain `localhost`) — google.com/recaptcha/admin — needed for App Check. §3a.
- [ ] (Phase 12) Register the web app in App Check with the reCAPTCHA **secret** key — Firebase console → App Check → Apps — §3b.
- [ ] (Phase 12) Generate a debug token and paste it (plus the site key) into `app_check.local.json` (git-ignored) — App Check → Apps → ⋮ → Manage debug tokens — §3c.
- [ ] (Phase 12) Run with `flutter run -d chrome --dart-define-from-file=app_check.local.json`, check "Verified" requests, then click **Enforce** for Cloud Firestore — Firebase console → App Check → APIs — §3d–3e. Only enforce once requests show as verified.
- [ ] (Phase 14) Deploy the new rules AND the new comments index: `firebase deploy --only firestore:rules,firestore:indexes` — terminal in `mytube/` — without it, posting/replying/deleting comments is refused ("Couldn't post") and the **Top** sort shows "Couldn't load comments" until the index finishes building (a few minutes; Newest works right away).

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
- 2026-10-29 — **Phase 13 (Channels) done.** New `channels/{channelId}`
  collection: the 6 sample channels (seeded once, with banners cut from
  their videos) and one per account (`user-{uid}`, created on sign-in /
  before uploading / when opening your channel). Channel page at
  `<tab>/channel/<id>` (Home, Subscriptions and You tabs; from Shorts it
  opens in Home): banner, avatar, name, @handle, subscribers, video count
  (count query), Subscribe or Edit channel, tabs Home / Videos / Shorts /
  Playlists (empty until Phase 15) / About; Videos and Shorts load 12 at a
  time. Avatars and channel names open the channel (video cards, watch
  page, description sheet, Shorts, comment avatars, You → View channel).
  "Edit channel": name, @handle (checked + reserved in `handles/{@handle}`),
  description, banner (Cloudinary), avatar color; saves profile, channel
  and your videos' channel name/color in one batch. Subscribing changes
  `subscriberCount` ±1 in the same batch; rules check both sides and block
  subscribing to yourself. Subscriptions tab: guest / empty / error states,
  avatar row (tap = only that channel), "All" chip, paged feed (newest
  public videos of your 30 latest subscriptions), pull to refresh.
  Files: new lib/data/models/channel.dart,
  lib/data/repositories/channel_repository.dart + paged_videos.dart,
  lib/features/channel/ (channel_screen, edit_channel_screen,
  channel_navigation), lib/core/widgets/paged_footer.dart; changed
  firestore.rules, firestore.indexes.json (1 composite index), app_router,
  seed_videos, main, video model (+channelAvatarColor), user_repository,
  auth_repository, require_account, subscribe_button, channel_avatar,
  video_card, watch_details, description_sheet, comments_sheet, short_page,
  you_screen, subscriptions_screen, upload_screen. Tests:
  test/channel_test.dart, channel_navigation_test.dart,
  paged_footer_test.dart, + rules checks (40 tests total).
  Known limits: videos keep the subscriber number saved on them only for
  old uploads without a channel doc; old comments keep the old name/handle
  after a rename; subscriptions made before this phase didn't add +1, so a
  user channel's count can start low (it never goes below 0).
- 2026-10-30 — **Phase 14 (Comments) done.** Replies live in
  `videos/{v}/comments/{c}/replies/{r}` (one level deep; replying to a reply
  adds "@handle " and goes into the same thread). Each comment shows
  "N replies" (blue) that opens the thread 10 at a time with "Show more
  replies". Likes work on replies too (like record gets `parentId`). Edit
  and delete your own comment/reply from the ⋮ menu ("Editing your
  comment" bar above the box, then "(edited)"); deleting a comment also
  deletes its replies. The uploader can pin one comment ("Pinned by …",
  always on top, saved as `videos/{v}.pinnedCommentId`) and give a creator
  heart (`hearted`). `videos/{v}.commentCount` (comments + replies) and
  `comments/{c}.replyCount` move in the same batch as the post/delete; the
  rules check it via `lastCommentId` / `lastReplyId`. Older videos fill in
  their missing count once (a count query, not a read of every comment).
  Comments now load 20 at a time (Top = likes then newest, needs the new
  index; Newest = by date) instead of reading ALL comments live; my own
  posts/edits/likes/deletes show at once. The watch-page card reads only
  the pinned/top comment; Shorts use `commentCount`.
  Files: lib/data/models/comment.dart, video.dart,
  lib/data/repositories/comment_repository.dart, paged_comments.dart (new),
  lib/features/comments/comments_sheet.dart, comments_preview_card.dart,
  widgets/comment_tile.dart (new), lib/features/watch/widgets/watch_details.dart,
  lib/features/shorts/widgets/short_page.dart, lib/data/seed/seed_videos.dart,
  firestore.rules, firestore.indexes.json, CLAUDE.md (one phase at a time).
  Tests: test/comment_test.dart, test/comment_tile_test.dart, rules checks
  (59 tests total).
  Known limits: the list isn't live (other people's new comments show after
  reopening the sheet or switching Top/Newest); a comment with more than
  400 replies keeps the extra replies in the database (hidden) when
  deleted; old comments keep the old name/handle after a rename.
