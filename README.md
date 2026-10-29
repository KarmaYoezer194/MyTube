# MyTube

A YouTube-style **mobile** video app built with **Flutter** for a university
project. It runs in Chrome (Flutter web) and looks like a phone app: on wide
screens it is shown in a centered 430 px "phone" column.

It uses only free services: **Firebase** (Anonymous Auth + Cloud Firestore,
Spark plan) and **Cloudinary** (free plan) for video and image hosting.

> MyTube is a student demo. It is not affiliated with YouTube or Google, and
> uses its own name and logo.

## Features

- **Home feed**: category chips (Animation, Cars, Entertainment, Sci-Fi,
  Recently uploaded), a top bar that hides on scroll and snaps back, a Shorts
  shelf, pull to refresh, shimmer loading skeletons.
- **Watch page** with a custom player built on `video_player`:
  - tap to show/hide controls (auto-hide after 3 s)
  - red progress bar with buffered part and draggable scrubber
  - double-tap left/right to seek 10 s (with ripple)
  - playback speed 0.25x to 2x, autoplay switch, full screen
  - 5-second "Up next" countdown, resume where you left off
- **Mini player**: drag the watch page down into a mini player above the
  bottom nav, and drag it back up. The video keeps playing across tabs.
- **Likes / dislikes, Subscribe, Watch later, view counts and watch
  history**, saved per user in Firestore.
- **Comments**: draggable sheet, Top / Newest sorting, likes on comments,
  posting appears instantly.
- **Shorts**: full-screen vertical swipe, loop, tap to pause, scrubbable
  progress line, side actions.
- **Search** with live suggestions and saved recent searches, plus
  **notifications** with an unread badge.
- **Upload videos and Shorts** to Cloudinary with a real progress bar
  (title, description, category, thumbnail, Public / Unlisted).
- **You tab**: profile, history with progress bars, Liked videos,
  Watch later, Your videos.
- **Settings**: device / dark / light theme, autoplay, clear history.
- Empty, error and offline states everywhere.

## Tech stack

| Area | Package / service |
|---|---|
| UI | Flutter (Dart, null safety), Material Symbols icons |
| State management | `flutter_riverpod` (Riverpod 3) |
| Navigation | `go_router` with `StatefulShellRoute` (bottom tabs) |
| Backend | Firebase Anonymous Auth + Cloud Firestore |
| Video hosting | Cloudinary (unsigned upload preset), uploads with `dio` |
| Video playback | `video_player` with custom controls |
| Other | `file_picker`, `shared_preferences`, `share_plus`, `shimmer`, `intl` |

## Project structure

```
lib/
  main.dart                 app start, Firebase, phone frame
  core/                     theme, router, shared widgets, helpers, constants
  data/
    models/                 Video, Comment, AppUser
    repositories/           Firestore + Cloudinary access
    seed/                   13 sample videos written on first launch
  features/                 home, watch, mini_player, shorts, comments,
                            search, notifications, upload, you, settings
tool/upload_seed_media.dart one-time script to copy the sample clips to Cloudinary
firestore.rules             Firestore security rules
```

UI, state (providers) and data (repositories) are kept separate.

## Run it yourself

You need Flutter (stable), Node.js and the Firebase CLI.

1. **Firebase**
   - Create a project in the Firebase Console (Spark plan is enough).
   - Authentication: enable the **Anonymous** sign-in provider.
   - Create a **Firestore** database.
   - Connect the app: `flutterfire configure --project=<your-project-id> --platforms=web`
   - Deploy the rules: `firebase deploy --only firestore:rules --project <your-project-id>`
2. **Cloudinary**
   - Create a free account and note your **cloud name**.
   - Settings > Upload > add an **unsigned** upload preset.
   - Put both in `lib/core/constants/cloudinary_config.dart`.
     Never put your Cloudinary API secret in the app.
3. **Sample videos** (once): `dart run tool/upload_seed_media.dart`
4. **Run**: `flutter pub get`, then `flutter run -d chrome`

On first launch the app writes the 13 sample videos to Firestore.

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
