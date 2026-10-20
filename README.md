# AudioLoca

AudioLoca is a context-aware music application featuring a **Flutter** mobile client and a **FastAPI** backend. It unifies local music management, Spotify authentication and discovery, GPS location-based listening feeds, and on-device real-time face & emotion recognition.

---

## 1. Project Structure

```text
audioloca/
├── audioloca/                 # Flutter mobile client (Dart / Android Kotlin)
│   ├── android/app/src/main/
│   │   ├── assets/           # Place native Android TFLite models here
│   │   └── kotlin/           # Native camera & ML Kit integration
│   ├── assets/               # Flutter static assets (images, models)
│   └── lib/                  # Flutter application source code
└── server/                   # FastAPI backend service (Python / SQLAlchemy)
    ├── media/                # Uploaded audio tracks and album covers (ignored by git)
    └── src/                  # API routers, models, CRUD, and security
```

---

## 2. Prerequisites

- **Flutter SDK:** Version 3.9 or newer (with Dart 3.9+)
- **Android SDK:** API Level 34+ (Android 14) with NDK support
- **Python:** Version 3.10 or newer (3.12 recommended)
- **Database:** PostgreSQL or SQLite supported by SQLAlchemy
- **External Accounts / Keys:**
  - [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) (Client ID, Client Secret, Redirect URI)
  - [LocationIQ](https://locationiq.com/) (Reverse-geocoding API token)

---

## 3. Emotion Recognition Model Setup (Required)

> [!IMPORTANT]
> The emotion recognition models are excluded from version control (`.gitignore`) due to file size and licensing. **Anyone setting up this project must supply their own 7-class TensorFlow Lite emotion recognition model.**

### Model Requirements & Specifications

- **Format:** TensorFlow Lite (`.tflite`)
- **Emotion Classes (Strictly 7 Emotions):**
  Your model output tensor must output probabilities corresponding to these 7 classes:
  1. `Anger`
  2. `Disgust`
  3. `Fear`
  4. `Happiness`
  5. `Neutral`
  6. `Sadness`
  7. `Surprise`
- **Expected Input Tensor:** `[1, 224, 224, 3]` (RGB float32 normalized between `[-1.0, 1.0]`)
- **Expected Output Tensor:** `[1, 7]` (Float probabilities or logits)

### Where to Place Your Model

Copy your `.tflite` model file to the following target paths:

1. **Android Live Camera Inference (Primary):**
   ```text
   audioloca/android/app/src/main/assets/emotion_model.tflite
   ```
   *(Note: `basic_finetuned.tflite` is also recognized automatically as a fallback).*

2. **Flutter Asset Bundle (Optional / Fallback):**
   ```text
   audioloca/assets/emotion_model.tflite
   ```

If no model is detected at startup, the camera tab will log a clear notice directing you to place the model file in the designated asset directory.

### How the 7 Emotions Map to Music Recommendations

When an emotion is recognized via the Camera tab, AudioLoca automatically recommends both local library tracks and Spotify songs:

| Emotion | Recommended Local Genres | Spotify Discovery Queries |
| :--- | :--- | :--- |
| **Happiness** | Pop, Rock, Electronic | `energetic`, `upbeat`, `party`, `dance` |
| **Sadness** | Jazz / Blues, Folk / Acoustic, Classical | `uplifting`, `healing`, `comfort`, `emotional` |
| **Anger** | Metal, Hip-Hop / Rap, Rock | `energetic`, `upbeat`, `party`, `dance` |
| **Fear** | Ambient / Chill, Experimental, Classical | `calm`, `ambient`, `soothing` |
| **Disgust** | Experimental, Metal, Rock | `serene`, `relaxing`, `peaceful` |
| **Surprise** | Pop, Electronic, Latin / World | `exciting`, `unexpected`, `novelty` |
| **Neutral** | Ambient / Chill, Folk / Acoustic, Country | `chill`, `lofi`, `mellow` |

---

## 4. Configuration & Environment Setup

Sensitive keys are kept in local configuration files that are ignored by git.

### Backend Setup (`server/.env`)

Create your local backend environment file from the example template:

```bash
cd server
copy .env.example .env   # Windows CMD
# or: cp .env.example .env (PowerShell / Bash)
```

Fill in your configuration:

```env
DATABASE_URL=sqlite:///./audioloca.db   # Or postgresql://user:pass@localhost:5432/audioloca
SECRET_KEY=your_generated_secret_key_here
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
APP_REDIRECT_URI=your_spotify_redirect_uri
LOCATIONIQ_ACCESS_TOKEN=your_locationiq_token
```

### Flutter App Setup (`audioloca/lib/environment.local.dart`)

Create the Flutter local configuration:

```bash
cd audioloca
copy lib\environment.example.dart lib\environment.local.dart
```

Configure your local IP/host and keys:

```dart
class EnvironmentLocal {
  static const String audiolocaBaseUrl = 'http://10.0.2.2:8000'; // 10.0.2.2 for Android Emulator, or local LAN IP for physical device
  static const String spotifyClientId = 'YOUR_SPOTIFY_CLIENT_ID';
  static const String spotifyClientSecret = 'YOUR_SPOTIFY_CLIENT_SECRET';
  static const String spotifyRedirectUri = 'your-redirect-uri://callback';
  static const String locationIQAccessToken = 'YOUR_LOCATIONIQ_TOKEN';
}
```

---

## 5. Running the Backend

```bash
cd server

# Create and activate virtual environment
python -m venv .venv
.venv\Scripts\activate       # On Windows
# source .venv/bin/activate  # On macOS/Linux

# Install dependencies
pip install -r requirements.txt

# Start FastAPI server
uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```

The server will initialize the database tables automatically and be accessible at `http://localhost:8000`. API documentation is available at `http://localhost:8000/docs`.

---

## 6. Running the Flutter App

Ensure your Android emulator or physical device is connected via USB debugging:

```bash
cd audioloca

# Install dependencies
flutter pub get

# Check connected devices
flutter devices

# Run the app
flutter run
```

---

## 7. Version Control & Security Guidelines

- `.tflite` model files are ignored by git (`*.tflite`). Never force-commit large weights into the repository.
- Never commit `server/.env` or `audioloca/lib/environment.local.dart`.
- Uploaded user audio and album covers (`server/media/`) are ignored by git.
- If Spotify credentials or access tokens are ever exposed, rotate them immediately in your Spotify Developer Dashboard.