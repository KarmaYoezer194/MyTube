# MyTube

A YouTube-style **mobile** video app built with **Flutter** for a university
project. It runs in Chrome (Flutter web) and looks like a phone app: on wide
screens it is shown in a centered 430 px "phone" column.

It uses only free services: **Firebase** (Auth + Cloud Firestore, Spark
plan, no Cloud Functions) and **Cloudinary** (free plan) for video and image
hosting. It runs locally; see `docs/PUBLISHING.md` for putting it online
later.

> MyTube is a student demo. It is not affiliated with YouTube or Google, and
> uses its own name and logo.

## Features

- **Accounts**: browse and watch as a guest; sign up / sign in with email or
  Google to like, comment, subscribe, save, upload and report.
- **Home**: feed loaded page by page with category chips, "Recommended for
  you", a Shorts shelf, pull to refresh; **Explore** with Trending and
  categories.
- **Search** in Firestore by word beginnings: filters (All / Videos /
  Shorts / Channels), sort (relevance / date / views), channel results,
  recent searches.
- **Watch page** with a custom player: double-tap seek, speed, volume,
  autoplay with countdown, full screen, resume, **keyboard shortcuts**
  (press `?`), **mini player** that keeps playing across tabs, smart
  "Up next".
- **Shorts**: vertical swipe, loop, side actions.
- **Comments**: replies, likes, edit / delete, pinned comment and creator
  heart, Top / Newest, 20 at a time.
- **Channels**: channel page with tabs, edit your channel (name, @handle,
  banner, color), subscribe, Subscriptions feed.
- **Playlists**: create, Public / Private, "Save to…", drag to reorder,
  Play all / Shuffle with a playlist panel; Liked videos and Watch later.
- **History** grouped by day with search, remove, pause and clear.
- **Studio**: channel dashboard, per-video analytics, edit, delete.
- **Notifications** (in-app) for uploads, comments and replies, with an
  unread badge.
- **Upload** videos and Shorts to Cloudinary with a progress bar.
- **Hide**: Not interested / Don't recommend channel; **Report** a video.
- **Links** that survive a refresh: `#/watch?v=ID`, `#/shorts/ID`,
  `#/@handle`; Share copies them.
- Dark / light theme, empty / error / offline states everywhere.

## Tech stack

| Area | Package / service |
|---|---|
| UI | Flutter web (Dart), Material Symbols icons |
| State management | `flutter_riverpod` (Riverpod 3) |
| Navigation | `go_router` with `StatefulShellRoute` (bottom tabs) |
| Backend | Firebase Auth (anonymous, email, Google) + Cloud Firestore + App Check |
| Video hosting | Cloudinary (unsigned upload preset), uploads with `dio` |
| Video playback | `video_player` with custom controls |
| Other | `file_picker`, `shared_preferences`, `shimmer`, `intl`, `web` |

## Project structure

```
lib/
  main.dart                 app start, Firebase, App Check, phone frame
  core/                     theme, router, shared widgets, helpers, constants
  data/
    models/                 Video, Comment, AppUser, Channel, Playlist, ...
    repositories/           Firestore + Cloudinary access
    seed/                   13 sample videos + 6 channels (first launch)
  features/                 home, discovery, search, watch, mini_player,
                            shorts, comments, channel, playlists, studio,
                            notifications, upload, auth, you, settings, report
test/                       unit + widget tests (flutter test)
docs/                       security setup + review, notifications, publishing
tool/upload_seed_media.dart one-time script to copy the sample clips to Cloudinary
firestore.rules             Firestore security rules
firestore.indexes.json      Firestore indexes
```

UI, state (providers) and data (repositories) are kept separate.

## Run it yourself

You need Flutter (stable), Node.js and the Firebase CLI.

1. **Firebase**
   - Create a project in the Firebase Console (Spark plan is enough).
   - Authentication: enable **Anonymous**, **Email/Password** and **Google**.
   - Create a **Firestore** database.
   - Connect the app: `flutterfire configure --project=<your-project-id> --platforms=web`
   - Deploy the rules and indexes:
     `firebase deploy --only firestore:rules,firestore:indexes --project <your-project-id>`
2. **Cloudinary**
   - Create a free account and note your **cloud name**.
   - Settings > Upload > add an **unsigned** upload preset and restrict it
     (see `docs/SECURITY_SETUP.md`).
   - Put both in `lib/core/constants/cloudinary_config.dart`.
     Never put your Cloudinary API secret in the app.
3. **Sample videos** (once): `dart run tool/upload_seed_media.dart`
4. **Run**: `flutter pub get`, then `flutter run -d chrome`
   (with App Check: add `--dart-define-from-file=app_check.local.json`).
5. **Check**: `flutter analyze` and `flutter test`.

On first launch the app writes the sample videos and channels to Firestore.

## Video credits

- *Big Buck Bunny*, *Elephants Dream*, *Sintel* and *Tears of Steel*:
  (c) Blender Foundation, Creative Commons Attribution (CC BY), via the
  Internet Archive and Wikimedia Commons.
- Other sample clips are from Wikimedia Commons, used under their
  CC BY / CC BY-SA licenses: MrChia SG, Flykit production, Vladislav
  Sanikovich, Sherp ET, Fumikas Sagisavas, Tomasz Sienicki, kallerna,
  Bastoche\*, LyaiDemon. Each clip's author and license is also in its
  description inside the app.

Channel names, view counts and likes on the sample videos are made up for
the demo.
