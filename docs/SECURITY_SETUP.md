# MyTube security setup (Phase 12)

Three things to do in web consoles. All of them are free. Do them in this
order: Cloudinary first, then the Firestore rules, then App Check.

---

## 1. Restrict the Cloudinary upload preset

The app uploads with the **unsigned** preset `mytube_unsigned`. "Unsigned"
means anyone who knows the preset name can upload to your account, so the
preset itself must refuse anything the app would not send.

1. Go to <https://console.cloudinary.com> and sign in.
2. Click the **gear icon (Settings)** at the bottom left → **Upload** →
   **Upload presets**.
3. Click **mytube_unsigned** to edit it.
4. **General** (or "Storage and access"):
   - **Signing mode**: `Unsigned` (keep it).
   - **Asset folder**: `mytube/uploads` — new uploads land in their own
     folder, apart from the seed clips in `mytube/seed`.
   - **Overwrite**: OFF (an upload can never replace an existing file).
   - **Unique filename / Generated public ID**: ON (random names, so a
     file name can't be guessed or reused).
5. **Upload control** (may be called "Upload manipulations" or be under
   "Advanced"):
   - **Allowed formats**: `mp4,mov,webm,m4v,jpg,jpeg,png,webp`
     (videos for uploads, pictures for thumbnails/avatars/banners).
     Anything else is refused by Cloudinary.
   - **Max file size**: if your preset page shows this option, set it to
     `52428800` (50 MB). If it doesn't, the app's 50 MB check and the
     free plan's own 100 MB video limit still apply.
6. **Length** (optional, test it once): a preset can't *reject* a video by
   length, but an **Incoming transformation** can cut it. Setting the
   incoming transformation to `du_900` trims every uploaded video to
   15 minutes. Upload a short test video afterwards to make sure uploads
   still work; if they fail, remove the incoming transformation. The app
   already refuses videos over 15 minutes and Shorts over 60 seconds.
7. Click **Save**.

What protects you even if someone skips the app:
- Cloudinary: only the allowed formats, never overwriting files.
- Firestore rules: an uploaded video can only point to
  `https://res.cloudinary.com/hcrar4ku/...`, start at 0 views and
  0 likes, and use the uploader's own channel.

Never put the Cloudinary **API secret** in this project.

---

## 2. Deploy the Firestore rules

The new rules are in `firestore.rules` (and `firestore.indexes.json`).
They only take effect after you deploy them. From the `mytube/` folder:

```
firebase deploy --only firestore:rules,firestore:indexes
```

If the command shows a rules error, copy the error text and send it to
Claude. To check usage afterwards: Firebase console → **Firestore
Database** → **Usage** tab.

---

## 3. Turn on App Check (reCAPTCHA v3 + a debug token)

App Check makes Firebase accept requests only from **this** app, not from a
script that copied the public Firebase config.

- Local runs (`flutter run`) use a **debug token**.
- A published site (later) uses invisible **reCAPTCHA v3**.

### 3a. Create a reCAPTCHA v3 key (free)

1. Open <https://www.google.com/recaptcha/admin/create>.
2. **Label**: `MyTube`. **reCAPTCHA type**: **Score based (v3)**.
3. **Domains**: add `localhost` (later also your real domain, if you ever
   publish).
4. Submit. You get two keys:
   - **Site key** — public, goes in the app.
   - **Secret key** — goes ONLY into the Firebase console (next step).
     Never into the code.

### 3b. Register the app in Firebase App Check

1. Firebase console → project **mytube-6d311** → **App Check**
   (under "Security" / "Build" in the left menu) → **Apps** tab.
2. Click your web app → **reCAPTCHA** → paste the **secret key** → **Save**.

### 3c. Make a debug token for local runs

1. Still on **App Check → Apps**, click the **⋮** menu next to the web
   app → **Manage debug tokens** → **Add debug token** → **Generate token**.
   Name it e.g. `my laptop` and **Save**.
2. Copy the token (it looks like `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
3. Open `mytube/app_check.local.json` (it is **git-ignored**, so the token is
   never committed; copy `app_check.example.json` if it's missing) and fill
   it in:

   ```json
   {
     "APP_CHECK_DEBUG_TOKEN": "paste-the-debug-token-here",
     "RECAPTCHA_SITE_KEY": "paste-the-site-key-here"
   }
   ```

### 3d. Run the app with App Check

```
flutter run -d chrome --dart-define-from-file=app_check.local.json
```

The terminal shows `APP CHECK: on (debug token)`. Use the app for a minute
(open a few videos).

### 3e. Turn on enforcement (only after 3d works)

1. Firebase console → **App Check** → **APIs** tab → **Cloud Firestore**.
2. The chart should show your requests as **Verified**. If most are
   "Unverified", don't enforce yet — check the token step again.
3. Click **Enforce** → confirm. (Leave **Authentication** not enforced.)

After enforcing, **always** start the app with
`--dart-define-from-file=app_check.local.json`; without it Firestore
answers "permission denied" / App Check errors.

Good to know:
- Chrome remembers the App Check setting for `localhost` (local storage).
  To reset it, open DevTools → **Application** → **Clear site data**.
- If a debug token ever leaks, delete it under **Manage debug tokens** and
  make a new one.
- A new computer or browser profile needs the same file (or a new token).
