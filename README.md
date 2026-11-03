# OurShelf

*Your Kitchen, in Sync.*

A shared family grocery, pantry and household-expense app built with Flutter and Firebase. One group, synced in real time across every family member's phone — shopping list, pantry stock, purchase history, bills, and spending, all in one place.

## Features

- **Shared shopping list** — add items, mark them bought, organized by category, synced live to everyone in the group.
- **Pantry tracking** — Full / Half / Low / Out stock levels per item, auto-topped-up when something's bought, low-stock items are one tap from the list again.
- **Receipt scanning** — photograph, upload an image, or upload a PDF of a bill; on-device OCR (Google ML Kit) reads item name, quantity and price automatically and matches them against the shopping list.
- **Add Purchase** — log a purchase manually or via scan, with date, store, and who paid.
- **Bills & EMI** — track non-grocery household spending (House EMI, internet, mobile recharge, electricity, transfers to parents, etc.) alongside groceries.
- **Expenses & Reports** — per-member totals, who-paid-the-most, spend-by-category pie chart, month-over-month comparison.
- **Reminders** — recurring essentials that aren't shopping-list items (e.g. an LPG refill every 30 days).
- **Activity feed** — a live log of who did what, across the whole group.
- **Push notifications** — item added / purchased notifications, delivered via a free Cloudflare Worker (no paid Firebase plan required).
- **Ask AI** — a chat assistant that answers questions about your own group's shopping list, pantry and spending, powered by Groq (free tier) through the same Worker.
- **Groups & invites** — join by 6-character code or email invite (opens your own mail app, pre-filled).

## Tech stack

- **Flutter** (Material 3) — UI, cross-platform mobile app.
- **Firebase** — Authentication (Google Sign-In), Cloud Firestore (data), Cloud Messaging (push notification delivery), all on the free Spark plan.
- **Cloudflare Workers** (free tier) — serverless backend for:
  - sending push notifications when the shopping list changes (replaces a paid Cloud Functions / Blaze plan), and
  - the Ask AI assistant, which reads the group's own Firestore data and calls the [Groq](https://groq.com) API for a response.
- **Google ML Kit** — on-device, offline, free OCR for receipt scanning. The recognition model updates itself via Google Play Services, so there's nothing to redeploy when it improves.
- **Riverpod** — state management.
- **fl_chart** — spending charts.

## Project structure

```
lib/
  src/
    app.dart                # Theme, design tokens, color palette
    data/                   # Firestore repositories and models
    features/                # One folder per screen/feature
      home/ shopping_list/ pantry/ purchase/ scan/ bills/
      dashboard/ expenses/ reminders/ activity/ ai/ groups/ more/
    notifications/          # Push notification client (talks to the Worker)
    ai/                      # Ask AI client (talks to the Worker)
    widgets/                 # Shared UI components (EmptyState, LoadingSkeleton, ...)
cloudflare-worker/
  notify.js                 # The Worker: push notifications + Ask AI, one file
functions/                   # Legacy Firebase Cloud Functions (kept for reference,
                              # not deployed — replaced by the Cloudflare Worker above
                              # so the app never needs a paid Blaze plan)
```

## Setup

### 1. Firebase

1. Create a Firebase project and add an Android app (package: `com.ourshelf.app`).
2. Download `google-services.json` into `android/app/`.
3. Enable **Authentication** (Google Sign-In), **Cloud Firestore**, and **Cloud Messaging** in the Firebase console.
4. Deploy the security rules: `firebase deploy --only firestore:rules`.

### 2. Cloudflare Worker (push notifications + Ask AI)

No paid plan needed anywhere in this stack.

1. Create a free [Cloudflare](https://dash.cloudflare.com) account and a new Worker.
2. Paste in the contents of `cloudflare-worker/notify.js`.
3. In the Worker's **Settings → Variables and Secrets**, add:
   - `FIREBASE_PROJECT_ID` — your Firebase project id.
   - `FIREBASE_CLIENT_EMAIL` — from a Firebase service-account key (Project Settings → Service accounts → Generate new private key). This does **not** require Blaze.
   - `FIREBASE_PRIVATE_KEY` — the private key from that same service-account JSON.
   - `GROQ_API_KEY` — a free API key from [console.groq.com](https://console.groq.com), only needed for Ask AI.
4. Deploy, and set `kNotifyWorkerUrl` in `lib/src/notifications/push_trigger.dart` to the Worker's `*.workers.dev` URL.

### 3. Run

```bash
flutter pub get
flutter run
```

### 4. Build a release APK

```bash
flutter build apk --release
```

## License

Private project — no license granted for reuse.
