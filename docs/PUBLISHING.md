# How to publish MyTube later (free)

MyTube runs **locally** for now (`flutter run -d chrome`). Nothing is
deployed. This is the plan for putting it online later, still on free
plans. **Don't do it before you're ready**: once it's online, anyone with
the link can use your Firebase and Cloudinary quotas.

The app is already prepared:

- Links use `#/` addresses (`/#/watch?v=ID`, `/#/shorts/ID`, `/#/@handle`),
  so they work after a refresh on **any** static host. No server rewrite
  rules are needed.
- A release build has no warnings and prints nothing in the browser
  console.
- The Firestore rules and App Check are ready (see SECURITY_REVIEW.md).

## 1. Choose where to host it

| Host | Cost | Notes |
|---|---|---|
| **Firebase Hosting** (recommended) | Free on Spark: 10 GB storage, 360 MB/day transfer | Same project, free HTTPS, `<project>.web.app` address |
| GitHub Pages | Free for public repos | Build with `--base-href /<repo-name>/` |
| Netlify / Cloudflare Pages | Free tiers | Upload the `build/web` folder |

The steps below use Firebase Hosting.

## 2. Build the release version

Make a file **next to** `app_check.local.json`, for example
`app_check.release.json` (also git-ignore it), with ONLY the reCAPTCHA site
key, and no debug token:

```json
{ "RECAPTCHA_SITE_KEY": "your-site-key" }
```

Then:

```
flutter build web --release --no-wasm-dry-run --dart-define-from-file=app_check.release.json
```

The site is now in `build/web`.

> Never build the release version with `app_check.local.json`. The debug
> token would end up inside the published files, and with it anyone could
> pass App Check.

## 3. Set up Firebase Hosting (one time)

1. Add this to `firebase.json` (next to `"firestore"`):

   ```json
   "hosting": {
     "public": "build/web",
     "ignore": ["firebase.json", "**/.*"],
     "headers": [
       {
         "source": "**",
         "headers": [
           { "key": "X-Content-Type-Options", "value": "nosniff" },
           { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
           { "key": "X-Frame-Options", "value": "DENY" }
         ]
       },
       {
         "source": "**/*.@(js|wasm|png|jpg|ttf|otf|json)",
         "headers": [{ "key": "Cache-Control", "value": "public, max-age=3600" }]
       }
     ]
   }
   ```

   No `rewrites` are needed, because the app uses `#/` addresses.

2. Deploy: `firebase deploy --only hosting`
3. Your site is at `https://mytube-6d311.web.app`.

## 4. Make sign-in and App Check work on the new address

1. **Firebase console → Authentication → Settings → Authorized domains:**
   add `mytube-6d311.web.app` (and `mytube-6d311.firebaseapp.com`). Google
   sign-in only works on listed domains.
2. **reCAPTCHA admin** (google.com/recaptcha/admin) → your v3 key →
   Domains: add `mytube-6d311.web.app`.
3. **App Check → APIs → Cloud Firestore → Enforce** (only once requests
   show as "Verified").

## 5. Lock down the Firebase web API key (free)

The key in `lib/firebase_options.dart` is public by design, but you can
limit where it works:

Google Cloud console → APIs & Services → Credentials → the "Browser key"
→ **Application restrictions: Websites** → add
`https://mytube-6d311.web.app/*` (and `http://localhost/*` plus
`http://localhost:*/*` so local runs keep working).

## 6. Before you share the link

- [ ] Everything in SECURITY_REVIEW.md → "Checklist before publishing".
- [ ] The Cloudinary preset is restricted (formats, size, folder).
- [ ] Try it in an incognito window: guest browsing, sign up, upload,
      comment, playlist, notifications.
- [ ] Keep an eye on usage: Firestore → **Usage** tab, Hosting →
      **Usage**, Cloudinary → **Dashboard**. The free limits are about
      50,000 reads, 20,000 writes and 20,000 deletes per day for
      Firestore, and 25 monthly credits for Cloudinary.

## Updating the site later

```
flutter build web --release --no-wasm-dry-run --dart-define-from-file=app_check.release.json
firebase deploy --only hosting
```

Rules and indexes are deployed separately:
`firebase deploy --only firestore:rules,firestore:indexes`.

## Not part of this project

- **PWA / install as an app:** `web/manifest.json` exists (from Flutter's
  template), but there's no offline mode or install prompt.
- **Push notifications:** they need a server (see NOTIFICATIONS.md).
- **Custom domain:** possible on Firebase Hosting for free; add it in
  Hosting → Add custom domain, then repeat step 4 for that domain.
