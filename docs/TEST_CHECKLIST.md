# MyTube manual test checklist

Run it in Chrome after deploying the rules and indexes (PLAN.md → Manual
steps). Use **two accounts**: A in a normal window, B in an incognito
window, plus a **guest** (signed out). Tick each box. If something fails,
note the step number.

Start with: `flutter run -d chrome --dart-define-from-file=app_check.local.json`

## 0. Before you start
- [ ] 0.1 Firebase console → Firestore → Indexes: all **Enabled**.
- [ ] 0.2 `flutter analyze` → no issues; `flutter test` → all passed.

## 1. Guest (signed out)
- [ ] 1.1 Home loads: skeletons first, then videos; more load at the bottom.
- [ ] 1.2 A video plays. History (You tab) shows it with a red progress bar.
- [ ] 1.3 Like / Subscribe / Save / Comment / + / Report each show the
      "Sign in to …" sheet; nothing is saved.
- [ ] 1.4 The comment box opens the sign-in sheet instead of typing.
- [ ] 1.5 🔔 Notifications says "Sign in"; You tab shows "You're not signed in".

## 2. Accounts
- [ ] 2.1 Sign up with email (wrong email / short password / mismatch show
      messages). Your guest history is kept.
- [ ] 2.2 Sign out → you become a guest; sign in again; "Forgot password?" sends an email.
- [ ] 2.3 Continue with Google works (popup).
- [ ] 2.4 The nav "You" icon shows your avatar.

## 3. Home, Explore, search
- [ ] 3.1 Chips (Animation, Cars, …, Recently uploaded) change the feed; the
      top bar hides on scroll down and snaps back on scroll up.
- [ ] 3.2 "Recommended for you" and the Shorts shelf show on **All** only.
- [ ] 3.3 Pull to refresh starts from the newest video.
- [ ] 3.4 Explore → Trending ranked #1, #2, …; a category chip narrows it.
- [ ] 3.5 Search "bun" → Big Buck Bunny; Videos / Shorts / Channels
      filters; sort Relevance / Upload date / View count.
- [ ] 3.6 Recent searches appear; long-press removes one.
- [ ] 3.7 ⋮ → Not interested / Don't recommend channel hides it (Undo
      works); Settings → "Show hidden … again" brings it back.

## 4. Watch page and player
- [ ] 4.1 Tap a video: the page slides up; tap the player to show / hide
      controls (they hide after 3 s).
- [ ] 4.2 Double-tap left / right seeks 10 s with a ripple.
- [ ] 4.3 ⚙: volume slider and speed; after a reload both are remembered,
      and so is mute.
- [ ] 4.4 Full screen; the ⌄ button or dragging down → mini player;
      drag / tap it back up. Switching tabs keeps it playing.
- [ ] 4.5 At the end: "Up next" countdown (autoplay on) plays the next video.
- [ ] 4.6 Resume: reopen a half-watched video, it continues where you stopped.
- [ ] 4.7 Keyboard: ? shows the list; K, J, L, ←, →, ↑, ↓, M, F, Esc, I,
      Shift+N, >, <, 0-9 do what it says. Typing a comment is not affected.
- [ ] 4.8 Like / Dislike / Save / Share ("Link copied") / ⋮ menu.
- [ ] 4.9 Copy the address while watching, reload: the same video opens.

## 5. Comments
- [ ] 5.1 Post: it appears on top, the count goes +1.
- [ ] 5.2 Reply; "N replies" opens the thread; replying to a reply adds @name.
- [ ] 5.3 ⋮ Edit → "(edited)"; ⋮ Delete (with replies) → count goes down.
- [ ] 5.4 As the uploader: Pin (stays on top, "Pinned by"), give a ♡.
- [ ] 5.5 Top / Newest; scroll loads 20 more.

## 6. Shorts
- [ ] 6.1 Swipe up / down; it loops; tap pauses; the line is draggable.
- [ ] 6.2 The address shows #/shorts/ID; reload keeps the same Short.
- [ ] 6.3 Like / comments / share on the side.

## 7. Channels and subscriptions
- [ ] 7.1 Tap a channel name: banner, avatar, subscribers, tabs
      Home / Videos / Shorts / Playlists / About.
- [ ] 7.2 Subscribe +1 / Unsubscribe -1 (B on A's channel).
- [ ] 7.3 Edit your channel (name, @handle, description, banner, color);
      your videos show the new name.
- [ ] 7.4 Open #/@yourhandle in the address bar: your channel opens.
- [ ] 7.5 Subscriptions tab: avatar row, "All" chip, feed; empty state when
      you have none.

## 8. Playlists, history
- [ ] 8.1 Save → New playlist (Private); add more videos from ⋮.
- [ ] 8.2 Playlist page: drag to reorder, remove, Edit (rename, Public), Delete.
- [ ] 8.3 Play all / Shuffle: playlist box on the watch page; ⏭ follows it.
- [ ] 8.4 Public playlists appear on the channel's Playlists tab.
- [ ] 8.5 History grouped by day; search; remove one; Pause (nothing new
      is added); Clear all.

## 9. Upload and Studio
- [ ] 9.1 + → Upload a video: progress bar, title, category, thumbnail,
      Public / Unlisted. It appears at the top of Home (Public).
- [ ] 9.2 Too big / wrong type / too long files are refused with a message.
- [ ] 9.3 Studio: dashboard numbers, filters, sort, analytics page.
- [ ] 9.4 Edit (title, Unlisted, new thumbnail); Delete shows the Cloudinary
      file name to delete by hand.

## 10. Notifications
- [ ] 10.1 B subscribes to A; A uploads Public → B's 🔔 shows 1.
- [ ] 10.2 B comments on A's video → A is notified; tap opens the
      "Highlighted comment".
- [ ] 10.3 Mark read / unread, swipe to remove, ✓✓ mark all read.

## 11. States
- [ ] 11.1 **Loading**: skeletons on Home, Shorts, lists, comments.
- [ ] 11.2 **Empty**: no history, no playlists, no comments, no
      notifications, no results, empty channel tabs.
- [ ] 11.3 **Error**: Chrome DevTools → Network → Offline: the offline bar
      appears, lists show "Couldn't load … / Retry", Retry works when back
      online.
- [ ] 11.4 **Video unavailable**: a deleted video's link shows "Video
      unavailable".
- [ ] 11.5 **Not found**: #/@nobody shows "Channel not found"; a deleted
      playlist shows "Playlist unavailable".
- [ ] 11.6 Light theme (Settings → Appearance): every screen is readable.
- [ ] 11.7 Narrow window (phone size) and wide window (430 px column with
      dark sides).

## 12. Animations
- [ ] 12.1 Watch page slides up; mini player follows your finger and snaps.
- [ ] 12.2 Thumbnails fade in; skeletons shimmer.
- [ ] 12.3 Like / subscribe icons animate; the subscribe pill changes smoothly.
- [ ] 12.4 Double-tap ripple; controls fade; "Up next" countdown ring.
- [ ] 12.5 Home top bar hides / snaps; bottom sheets slide; snackbars
      sit above the nav bar and the mini player.

## 13. Performance (Chrome DevTools)
- [ ] 13.1 Network tab: thumbnails load as small copies (links contain
      `c_limit,w_…`), about 20–60 KB each.
- [ ] 13.2 Firestore → Usage (next day): reads stay well under the free
      50,000 / day during a normal test session.
