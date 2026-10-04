# ResQ

ResQ is a mobile application for reporting lost and stray pets and helping people find possible matches. Users can publish a pet report with a photo and location, browse reports in a feed or on a map, and search for visually similar pet reports using image embeddings. The app also includes user profiles, direct messaging, chat attachments, push notifications, and admin screens.

The repository contains a Flutter client, Python API modules, and Firebase/Supabase configuration. It is a CSE327 project.

## Contents

- [Features](#features)
- [How image matching works](#how-image-matching-works)
- [Technology](#technology)
- [Repository structure](#repository-structure)
- [Services and data](#services-and-data)
- [Setup](#setup)
- [API routes](#api-routes)
- [Current integration notes](#current-integration-notes)

## Features

- **Lost and stray pet reports (“Flares”):** Create reports with pet details, a photo, address, and map location.
- **Feed and map:** Browse recent reports, view report locations, and react to or comment on posts.
- **Visual pet search:** Upload or capture a pet photo, select a species, and see visually similar reports ranked by similarity. The current search excludes reports owned by the signed-in user and uses a default similarity threshold of 0.50.
- **Match details:** Compare the search image with a report and view report and uploader details.
- **Accounts and profiles:** Email/password authentication through Firebase Authentication, with profile data stored in Firestore.
- **Direct chat:** Real-time conversations and messages in Firestore, with optional image, video, and file attachments stored privately in Supabase Storage.
- **Notifications:** Firebase Cloud Messaging notifications for new chat messages.
- **Admin screens:** User administration and dashboard screens are present in the Flutter client.
- **Theme support:** Light and dark themes, with the selected theme persisted locally.

## How image matching works

ResQ uses **DINOv2 Base**, loaded from the Hugging Face model repository [`facebook/dinov2-base`](https://huggingface.co/facebook/dinov2-base). The model is an image encoder, not a text or chat model. It is used as a pretrained feature extractor; this repository does not train or fine-tune it.

1. When a report with a photo is created, the Flutter client sends the image to the FastAPI embedding endpoint.
2. The backend decodes the image as RGB and applies the DINOv2 image processor.
3. The model's CLS token is taken from the final hidden state to represent the image. DINOv2 Base produces a **768-dimensional** vector.
4. The vector is L2-normalized. The client stores that embedding alongside the report's searchable metadata in the Supabase `pets` table.
5. For a search, the query image is embedded through the same API. The client calls the Supabase Postgres RPC `match_pets`, filters by species and similarity threshold, excludes the current user's reports, and sorts results by descending similarity.

Because vectors are normalized, cosine similarity can be evaluated as a dot product. Similarity values are used to rank candidates; they are not calibrated probabilities that two photos show the same animal. Lighting, pose, background, image quality, and the selected species can all affect results.

The Supabase schema and `match_pets` function are **not included in the checked-in migrations** at present. The existing client code expects a `pets` table with `flare_id`, `owner_id`, `species`, `image_url`, and a 768-dimensional `embedding`, plus an RPC accepting `query_embedding`, `match_species`, `match_threshold`, `match_count`, and `exclude_owner_id`. Configure this database side before using visual search.

## Technology

| Area | Technology |
| --- | --- |
| Mobile app | Flutter / Dart |
| Authentication | Firebase Authentication |
| Profiles, reports, feed, chat | Cloud Firestore |
| Report images | Supabase Storage (`flare-images`) |
| Chat attachments | Private Supabase Storage bucket (`chat-media`) |
| Vector storage and similarity search | Supabase Postgres / pgvector (expected by client) |
| API | FastAPI, Uvicorn, Python |
| Image model | PyTorch, Hugging Face Transformers, DINOv2 Base |
| Push notifications | Firebase Cloud Messaging |
| Maps | `flutter_map` with OpenStreetMap tiles; address lookup uses Nominatim |

## Repository structure

```text
ResQ/
├── backend/
│   ├── core/
│   │   └── config.py                 # Model name, limits, and service configuration
│   ├── models/
│   │   └── embedding.py              # Embedding API response model
│   ├── routers/
│   │   ├── auth_bridge.py            # Firebase-to-Supabase role bridge
│   │   ├── chat.py                   # Chat directory, attachment, notification routes
│   │   └── match.py                  # Image embedding route
│   ├── services/
│   │   ├── chat_service.py           # Firestore checks, Supabase media, FCM dispatch
│   │   ├── dinov2_service.py         # DINOv2 loading and inference
│   │   └── firebase_auth_service.py  # Firebase Admin token and claim handling
│   └── requirements.txt              # Python dependencies
├── firebase/
│   ├── firebase.json                 # Firebase CLI configuration
│   ├── firestore.rules               # Firestore access rules
│   ├── firestore.indexes.json        # Firestore indexes
│   └── storage.rules                 # Firebase Storage access rules
└── frontend/
    ├── android/                      # Android project and Firebase Android config
    ├── assets/                       # App images and icons
    ├── lib/
    │   ├── core/                     # Routes, theme, constants, and utilities
    │   ├── database/
    │   │   ├── models/               # User, Flare, feed, comment, and chat models
    │   │   └── services/             # Firebase, Supabase, API, and feature services
    │   ├── presentation/
    │   │   ├── screens/              # Auth, home, Flare, search, chat, profile, admin
    │   │   └── widgets/              # Shared UI widgets
    │   ├── app.dart                  # Material app and route/theme setup
    │   ├── firebase_options.dart     # FlutterFire-generated Firebase options
    │   └── main.dart                 # App initialization
    ├── supabase/
    │   ├── config.toml               # Supabase CLI local configuration
    │   └── migrations/               # Checked-in Supabase migration(s)
    ├── pubspec.yaml                  # Flutter dependencies and assets
    └── package.json                  # Supabase CLI tooling
```

## Services and data

### Firebase

Firebase Authentication is the account system. Firestore stores user profiles, Flares and their comments, conversations, messages, device tokens, chat preferences, and presence. Access is controlled by `firebase/firestore.rules`. Firebase Storage rules are in `firebase/storage.rules`; the current client stores report images in Supabase Storage instead.

The Firebase Admin SDK is used by the backend to verify Firebase ID tokens, manage the custom `role=authenticated` claim used by Supabase, and send chat notifications. The backend expects a Firebase service-account JSON file. Keep that credential private and out of Git.

### Supabase

The Flutter client initializes Supabase with Firebase ID tokens as the access token. Report photos are uploaded to the `flare-images` bucket. Pet embeddings and report metadata are upserted into the `pets` table by `flare_id`. Search calls the `match_pets` RPC.

Chat attachments use a separate private `chat-media` bucket. Uploads and signed URL requests pass through the backend, which verifies the Firebase token and checks that the user is a participant in the conversation. The included migration creates/configures this private bucket and sets a 25 MiB file limit.

## Setup

### Prerequisites

- Flutter SDK compatible with Dart `>=3.3.0 <4.0.0`
- Android Studio / Android SDK for Android builds
- Python 3.10 or newer (the backend dependencies include PyTorch and Transformers)
- A Firebase project with Authentication, Firestore, and Cloud Messaging configured
- A Supabase project with Storage configured; visual search additionally needs the database schema and RPC described above

### Configure Firebase and Supabase

1. Configure Firebase for the platforms you intend to run. Generate/update `frontend/lib/firebase_options.dart` with FlutterFire CLI (`flutterfire configure`) and install the matching Android `google-services.json` for your Firebase project.
2. Configure Firestore using `firebase/firestore.rules` and `firebase/firestore.indexes.json`. Review the rules for your deployment before publishing them.
3. Configure Supabase project credentials for the Flutter app in `frontend/lib/main.dart`. The app currently initializes the Supabase URL and publishable key there; use your own project values when setting up a separate deployment.
4. Create the `flare-images` bucket and configure its policies for authenticated uploads and public report-photo reads as required by the app. Apply the checked-in migration for the private `chat-media` bucket using the Supabase CLI from `frontend/`.
5. Add the `pets` table and `match_pets` RPC to Supabase. The RPC should use the same 768-dimensional vector representation and cosine similarity ranking expected by `PetSearchService`.
6. For the Python API, place a Firebase Admin service-account JSON at `backend/firebase-service-account.json`, or set `FIREBASE_SERVICE_ACCOUNT_PATH` to its path. Do not commit service-account credentials.

### Run the Flutter app

From `frontend/`:

```bash
flutter pub get
flutter run
```

The default backend URL is `http://10.0.2.2:8000`, which reaches the host machine from the Android emulator. For a physical device or another environment, provide a reachable backend address:

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://YOUR_HOST:8000
```

### Install backend dependencies

From the repository root:

```bash
python -m venv .venv
# Activate the environment using the command for your shell, then:
pip install -r backend/requirements.txt
```

The backend modules define the API routers and services, but the repository currently does not include an ASGI application entry point that creates a `FastAPI` instance and registers these routers. Add that application bootstrap before launching the API with Uvicorn. On first DINOv2 use, Transformers downloads the model weights from Hugging Face; inference uses CUDA when available and otherwise CPU.

## API routes

The Python router modules define these routes (all under the `/api` prefix):

| Method | Route | Purpose |
| --- | --- | --- |
| `POST` | `/api/match/embed` | Accept an image multipart upload and return model name, vector dimension, and normalized embedding. Maximum image size: 10 MiB. |
| `POST` | `/api/auth/sync-supabase-role` | Verify a Firebase ID token and ensure the Firebase user has the Supabase `authenticated` custom claim. |
| `GET` | `/api/chat/users` | Return a limited directory of chat users. Requires a Firebase bearer token. |
| `POST` | `/api/chat/media/upload` | Upload an attachment after verifying the caller's conversation membership. Default maximum size: 25 MiB. |
| `GET` | `/api/chat/media/signed-url` | Return a short-lived signed URL for conversation media after membership validation. |
| `POST` | `/api/chat/notifications/send` | Send a message notification to the other participant's registered devices. |

## Current integration notes
- Email/password authentication is implemented. Google sign-in currently reports that it is not configured.
- The Android Firebase configuration file is project-specific. Replace it with the configuration for your own Firebase project when creating a separate deployment.

## License

No license file is currently included.
