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

- [x] **Phase 15 — Playlists**
  - Create, rename, delete, Public/Private.
  - "Save to…" checkbox sheet from ⋮ and the Save button.
  - Drag to reorder, Play all, Shuffle, playlist panel on the watch page.
  - Liked and Watch later as built-in playlists.
  - History grouped by day: remove item, clear, pause history, search history.

- [x] **Phase 16 — Studio**
  - Manage your videos: thumbnail, title, visibility, date, views, likes, comments.
  - Edit fields and thumbnail.
  - Delete removes Firestore data only (the Cloudinary file is deleted manually).
  - Per-video and channel stats.



- [x] **Phase 17 — Notifications (in-app)**
  - An upload fans out to subscribers (batched, capped).
  - Replies, and comments on my video, notify me.
  - Real unread count, read/unread, tap to open, swipe or menu to remove.
  - Explain the limits of doing this without Cloud Functions.

- [x] **Phase 18 — Discovery**
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
- [ ] (Phase 15) Deploy the rules and the 2 new playlist indexes: `firebase deploy --only firestore:rules,firestore:indexes` — terminal in `mytube/` — until then creating playlists fails ("Couldn't create the playlist"), and your playlists / a channel's Playlists tab stay empty or show an error until the indexes finish building (a few minutes). (If you haven't done the Phase 14 deploy yet, this one command covers both.)
- [ ] (Phase 16, whenever you delete a video in Studio) Delete its file in Cloudinary too — console.cloudinary.com → Media Library → search the name shown in the delete dialog (it has a Copy button) → select → Delete — the app can't do it (that needs the API secret, which must never be in the app), and leftover files use your free storage. No rules deploy is needed for Phase 16.
- [ ] (Phase 17) Deploy the rules and the new subscribers index: `firebase deploy --only firestore:rules,firestore:indexes` — terminal in `mytube/` — until then no notifications are sent (the writes are refused) and uploads can't find their subscribers. The "subscribed.channelId" index takes a few minutes to build. (Covers the Phase 14/15 deploys too if they're still open.)
- [ ] (Phase 18) Deploy the rules and the 9 new indexes: `firebase deploy --only firestore:rules,firestore:indexes` — terminal in `mytube/` — Home, Explore and search load from Firestore now, so until the indexes are **built** (Firebase console → Firestore Database → Indexes → all "Enabled"; a few minutes) they show "Couldn't load videos" / "Couldn't search", and the old videos can't get their search keywords. (One command covers every earlier open deploy too.)

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
- 2026-10-30 — **Phase 15 (Playlists) done.** New `playlists/{id}`
  collection (owner, channel, title, Public/Private, videoIds in order up
  to 200): one read to open, one write to add/remove/reorder. Create from
  You → Playlists **+** or "New playlist" in the Save sheet; rename / change
  Public-Private / delete from the playlist page's ⋮. "Save video to…"
  checkbox sheet (Watch later + my playlists + New playlist) from the watch
  page's Save button (shows "Saved" if the video is in any of them) and a
  new "Save to playlist" row in every ⋮ menu. Playlist page (also for the
  built-in Liked videos and Watch later): big thumbnail, owner, "Private ·
  N videos", Play all, Shuffle, drag handles to reorder (own playlists),
  ⋮ → Remove (Liked = takes the like back). Play all / Shuffle start a play
  queue: ⏭ and autoplay follow the playlist, and the watch page shows a
  playlist panel ("Title · 3 / 12", tap to see the list, ✕ to stop);
  closing the player ends it. Shorts in a playlist are listed but skipped
  when playing. Channel → Playlists tab lists that channel's public
  playlists. History page: grouped by day (Today / Yesterday / weekday /
  date), search, ⋮ → Remove from watch history, Pause / Turn on, Clear all
  (deletes in batches of 400). Pause is also in Settings and is saved in
  this browser (not the account).
  Files: new lib/data/models/playlist.dart,
  lib/data/repositories/playlist_repository.dart, lib/features/playlists/
  (play_queue, playlist_dialogs, playlist_screen, save_to_playlist_sheet,
  widgets/playlist_panel, widgets/playlist_row), lib/features/you/
  history_screen.dart + history_groups.dart; changed app_router,
  compact_video_row (custom tap + extra ⋮ rows), video_options_sheet,
  channel_navigation (generic tab pages), channel_screen, player_panel
  (playlist-aware next video), watch_body, watch_details, playback_controller
  (respects pause), user_repository, you_providers, you_screen,
  video_list_screen (now just "Your videos"), settings, firestore.rules,
  firestore.indexes.json. Tests: test/playlist_test.dart,
  test/history_groups_test.dart, navigation + rules checks (84 tests).
  Known limits: Liked videos / Watch later can't be reordered (their order
  is by date); the play queue is a snapshot (videos added to the playlist
  while it plays join the next time you press Play all); pausing history is
  per browser.
- 2026-10-30 — **Phase 16 (Studio) done.** You → Studio (also "View all"
  next to Your videos), route `/you/studio`. Channel dashboard:
  subscribers, views, likes, comments, number of videos and Shorts, and
  the top upload. Content list (All / Videos / Shorts; sort Newest / Most
  viewed / Most liked) with thumbnail, title, Public/Unlisted · date and
  👁 👍 💬 numbers; ⋮ → Analytics / Edit / Delete. Video analytics page:
  views, likes, comments, likes per view, views per day, length, rank by
  views and its share of the channel's views / likes / comments, plus
  Watch, Edit and Delete. Edit video: title, description, category,
  Public/Unlisted and a new thumbnail (uploaded to Cloudinary on Save; asks
  before throwing away changes). Delete removes the Firestore document only
  and shows the Cloudinary file name(s) to delete by hand (with Copy); it
  also stops the video if it's playing. All numbers come from data the app
  already loads, so the Studio costs no extra Firestore reads. No rules
  changes (the uploader could already edit / delete their videos).
  Files: new lib/features/studio/ (studio_screen, video_stats_screen,
  edit_video_screen, delete_video, studio_stats, widgets/stat_tile);
  changed video_repository (updateDetails, deleteVideo), app_router,
  you_screen; removed lib/features/you/video_list_screen.dart ("Your
  videos" page, replaced by the Studio). Tests: test/studio_stats_test.dart
  (97 tests total).
  Known limits: a deleted video's comments stay in the database (hidden;
  only their authors may delete them); dislikes and watch time aren't
  stored, so they aren't shown; the video file itself can't be replaced.
- 2026-10-30 — **Phase 17 (Notifications) done.** Real in-app
  notifications in `users/{uid}/notifications/{id}`, written by the
  SENDER's app and checked by the rules (no Cloud Functions): a public
  upload notifies up to 100 subscribers (found with a collection-group query
  on `subscribed.channelId`, written 15 per batch); a comment notifies the
  video's uploader; a reply notifies the author of the comment. Fixed ids
  (`u_`/`c_`/`r_` + id) mean nothing is sent twice. New subscriptions save
  `channelId`; older ones get it filled in automatically while the app runs
  (the rules allow adding just that field). Bell badge = real unread count
  (of the newest 50, "9+" above 9). Notifications page: blue dot + bold for
  unread, tap opens the video (Shorts in the Shorts tab) and marks it read;
  comment / reply notifications also open the comments with that comment
  on top as "Highlighted comment" (replies open); ⋮ → Mark as read/unread,
  Remove; swipe left to remove; "Mark all as read" (✓✓). Guests see a
  "Sign in" page. Limits explained in docs/NOTIFICATIONS.md (sender's tab
  does the work, 100-subscriber cap, no push while closed, no automatic
  cleanup, a reply to a reply notifies the thread's author).
  Files: new lib/data/models/app_notification.dart,
  lib/data/repositories/notification_repository.dart, docs/NOTIFICATIONS.md;
  rewrote lib/features/notifications/ (providers + screen; the old
  "8 newest videos" fake list and its "seen at" setting are gone); changed
  comments_sheet (send comment/reply notifications, highlighted comment,
  root-navigator option), comment_tile (Highlighted label), upload_screen
  (fan-out after a public upload), user_repository (channelId on
  subscriptions + fill-in), app_shell (keeps subscriptions loaded), video
  model (copyWith id), firestore.rules, firestore.indexes.json (field
  override for the collection-group query). Tests:
  test/notification_test.dart, comment tile + rules checks (110 tests).
- 2026-10-30 — **Phase 18 (Discovery) done.** Search without a search
  server: videos and channels store `keywords` (every word's beginnings, up
  to 15 letters, max 200; video = title + channel name + category, channel
  = name + @handle). Search asks Firestore for the longest typed word
  (`array-contains`) and checks the other words in the app; filters All /
  Videos / Shorts / Channels; sort Relevance (best title match first among
  what's loaded), Upload date, View count; "All" shows the 2 best channels
  on top; channel rows have Subscribe. Keywords are saved on upload, on
  Studio edit and on channel rename; older videos / channels get them
  filled in once by the first person who loads them (the rules allow
  adding only that field while it's missing). Home now loads page by page
  from Firestore (newest first; chips = category or "Recently uploaded",
  pull to refresh; restarted after an upload / delete) with a "Recommended
  for you" shelf on All. Explore page (Explore chip): Trending = most viewed,
  or one category, ranked #1, #2, … page by page. Recommendations (Home
  shelf + Up next) use a simple score: same channel / category as the
  current video, channels I subscribe to, categories I watch most, not
  watched yet, popularity — all from data the app already has. ⋮ → Not
  interested (now remembered) and new "Don't recommend channel"; hidden
  items leave Home, Shorts shelf, Explore, search, suggestions and Up next;
  Settings → "Show hidden videos and channels again". Infinite scroll:
  Home, Explore, search (+ channel pages, Subscriptions, comments from
  before).
  Files: new lib/core/utils/search_keywords.dart, lib/features/discovery/
  (discovery_providers, hidden_content, recommendations, explore_screen),
  lib/features/home/widgets/recommended_shelf.dart; changed video + channel
  models (keywords, hasKeywords), video_repository (fill-in + Home /
  Trending / search queries, keywords on edit), channel_repository (fill-in,
  search query, keywords on rename), seed_videos, home_providers,
  home_screen, home_chips_bar, search_screen (+ ChannelResultRow),
  search_providers (old in-app search removed), watch_providers (Up next),
  video_options_sheet, settings_screen, upload_screen, edit_video_screen,
  delete_video, app_router, firestore.rules, firestore.indexes.json
  (13 indexes). Tests: test/discovery_test.dart + rules check (129 tests).
  Known limits: prefix search only (no typos / middle-of-word matches);
  "Relevance" can only reorder what has been loaded; Trending = most viewed
  (not "views this week" — that needs a server); hidden items are per
  browser; the watch page / player still use the full video list (Phase 21
  performance).
