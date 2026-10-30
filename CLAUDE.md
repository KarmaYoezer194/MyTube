# MyTube — standing rules for Claude

MyTube is a university project: a YouTube-mobile-style video app built with
Flutter for the web. It runs locally only (`flutter run -d chrome`).
Never use YouTube's name or logo in the UI.

## Tech stack
- Flutter web (stable), Dart 3, feature-first folders under `lib/`
  (`core/`, `data/models|repositories|seed`, `features/<name>/`).
- State: flutter_riverpod 3. Routing: go_router (StatefulShellRoute).
- Firebase on the free **Spark** plan: Auth (anonymous, email/password,
  Google) and Cloud Firestore. Project ID: `mytube-6d311`.
- Media: Cloudinary free plan, uploaded with `dio` through the UNSIGNED
  preset `mytube_unsigned` (cloud `hcrar4ku`).
- Other packages: video_player (custom controls), file_picker,
  shared_preferences, material_symbols_icons, shimmer, intl, share_plus, web.

## Hard rules (never break these)
1. **100% free.** No Firebase Storage, no Cloud Functions, no Blaze plan,
   no paid APIs or services. "Server" logic runs in the app and is protected
   by Firestore rules.
2. **No secrets in code or git.** No API secrets, service account keys,
   `.env` files or App Check debug tokens in committed files. (The Firebase
   web config in `lib/firebase_options.dart` and the Cloudinary cloud name
   and unsigned preset are public by design, so they are fine.)
3. **Local only. Never deploy.** Do not run `firebase deploy` (rules,
   indexes or hosting) or publish anything. Write the files, then add the
   deploy command to "Manual steps for me" in PLAN.md.
4. **Keep the existing design system:** the theme in `lib/core/theme/`,
   the shared widgets in `lib/core/widgets/`, the dark/light colors, Roboto,
   pill buttons, and the 430px centered mobile column.
5. **Guests can only watch.** Guests may browse, watch, and write their own
   history and the +1 view. Every other write needs sign-in: use
   `checkSignedIn` / `requireAccount` with a `SignInReason`, which shows the
   "Sign in to …" sheet. Firestore rules must enforce the same thing.
6. **Low Firestore usage.** Always use `limit()` and paginate. Never read a
   whole collection. Keep counts (commentCount, subscriberCount, …)
   denormalized with `FieldValue.increment`.
7. **Never push to GitHub** unless the user says "push".

## Verify commands
Run these from the project root (`mytube/`), in this order, using the Bash
tool and without a `cd` prefix (so the allowed-command rules match):

```
flutter pub get
dart format lib test tool
flutter analyze
flutter test
flutter build web
```

A phase is only "done" when `flutter analyze` reports no issues and every
command exits successfully.

## Workflow: one phase at a time
The user does NOT want automation (decided 2026-10-30). Only build the
phase the user asks for, then stop.

For that phase:
1. Read the phase in PLAN.md. If it says "SPEC NEEDED" or something is
   unclear in a way that changes the result, ask first.
2. Build it with complete code (no TODO placeholders). Update
   `firestore.rules` and `firestore.indexes.json` when the data model changes.
3. Add tests for the new logic under `test/` (pure Dart unit tests for
   models, parsing, validation and helpers; widget tests where practical).
   Don't initialize real Firebase in tests.
4. Run all verify commands and fix every error and analyzer issue.
5. Make one Git commit named `Phase X: <short summary>`, staging only the
   files for that phase.
6. In PLAN.md: tick the phase, add a Progress log entry, and add any
   Firebase/Cloudinary console or deploy steps to "Manual steps for me".
7. **STOP.** Tell the user which files changed, the manual steps, and how
   to test it in Chrome. Wait until they ask for the next phase.

Also stop and ask before anything hard to undo or that costs money, and
when the same error still fails after 3 different fix attempts (explain it
in 1–2 sentences and what you tried).

### Writing for the user
The user is a student. Keep summaries short and simple, give exact file
paths, and explain any error's cause in 1–2 sentences before the fix.
