# MyTube security review (Phase 20)

Reviewed on 2026-10-30: `firestore.rules`, the app code, the git history
and the build output. MyTube has **no server** (Firebase Spark plan, no
Cloud Functions), so the Firestore rules are the only thing standing
between the database and a modified app. Every finding below was checked
against them.

## Summary

| Area | Result |
|---|---|
| Secrets in the code or in git history | ✅ None. `app_check.local.json` is git-ignored and was never committed. No API secret, service-account key or `.env` file anywhere. |
| Public config (`firebase_options.dart`, Cloudinary cloud name and unsigned preset) | ✅ Public by design. Protected by the rules, App Check and the preset restrictions. |
| Firestore rules: every write | ✅ Checked field by field. Counters only move together with the record that explains them. |
| Guests (anonymous) | ✅ Read, own history, +1 view and fill-ins only. Everything else needs an account. |
| Private data (history, reactions, watch later, notifications, private playlists) | ✅ Readable only by its owner. |
| Release build | ✅ `flutter build web --no-wasm-dry-run` finishes with no warnings. |
| Browser console in release | ✅ Silent (fixed in this phase, see below). |

## Fixed in this phase

1. **Sample videos could carry any link.** The rule that lets the first
   launch write the 13 sample videos didn't check their fields. Someone
   could have created a missing sample video pointing to another website.
   Now: only the known fields, links to our Cloudinary account, and whole
   numbers for the counts.
2. **Notifications could show made-up text.** The sender could write any
   video title or thumbnail into your notification. Now: the title must be
   the real video's title, the thumbnail must be a Cloudinary link, and
   upload notifications are only allowed for **public** videos.
3. **The browser console showed the signed-in email.** Now it shows only
   the user id, and a release build prints nothing at all (`debugPrint` is
   switched off in `main.dart`).

## Known limits (accepted for a free, server-less demo)

These would need a server or a paid feature to fix properly:

| What | Risk | Why it stays |
|---|---|---|
| **+1 view**: anyone (guests too) may add one view per request | View counts can be inflated by a script | Counting "one view per person per day" needs a server. App Check makes scripting harder. |
| **Video length** may only grow, up to 4 hours | Someone could make a video look longer than it is | The first Cloudinary conversion reports lengths that are too short, so the player must be able to fix them. |
| **One-time fill-ins** (`keywords`, `commentCount`) on old documents | Junk keywords or a wrong count, once, on documents from before Phases 14 / 18 | The rules can't compute them. Existing documents were filled in by the app the first time it loaded them. |
| **Comment text in a notification** is written by the sender | The commenter could show slightly different text in your notification | They must be the real author of the real comment. Opening it shows the real comment. |
| **Upload fan-out**: max 100 subscribers, done by the uploader's tab | Some subscribers may miss a notification | See `docs/NOTIFICATIONS.md`. |
| **Unsigned Cloudinary preset**: anyone who knows its name can upload files to the account | Free storage could be filled up | Limits on format, size and folder are set on the preset (docs/SECURITY_SETUP.md §1). Signed uploads need a server. |
| **No rate limits** on writes | Spam (many comments, reports...) | Needs a server. App Check blocks requests that don't come from the app. |
| **Profiles are public** (name, @handle, avatar) | By design | Like YouTube channels. Emails are never stored in Firestore. |
| **A channel can list its subscribers' user ids** | By design | Needed to send upload notifications. Only for your own channel. |

## Checklist before publishing (all free)

- [ ] Deploy the rules and indexes (see PLAN.md → Manual steps).
- [ ] Turn on **App Check enforcement** for Firestore (SECURITY_SETUP.md §3e).
- [ ] Restrict the **Cloudinary preset** (SECURITY_SETUP.md §1).
- [ ] Restrict the **Firebase web API key** to your site's address in the
      Google Cloud console (see PUBLISHING.md, step 5).
- [ ] Check that **Email enumeration protection** is on in Firebase
      Authentication → Settings (it is on by default for new projects).
- [ ] Build **without** the App Check debug token (PUBLISHING.md, step 2).

## How the review was done

- Read every `allow` rule in `firestore.rules` and asked, for each
  collection: who can read, who can create, update or delete, which
  fields, which values, and what else must change in the same batch.
- Searched the code and **all** git history for secret-looking strings,
  tokens, keys and ignored files.
- Checked that user-supplied links can only point to our Cloudinary account
  (videos, thumbnails, avatars, banners, notification thumbnails).
- Checked what the browser console shows.
- `flutter analyze`, the unit tests (they include structure checks of the
  rules) and a release build.

> The rules can't be run in the Firestore emulator on this PC (it needs
> Java). They are compiled when you deploy them: if `firebase deploy` shows
> an error, nothing changes on the server, and the error says which line
> to fix.
