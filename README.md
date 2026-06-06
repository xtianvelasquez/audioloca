# AudioLoca

AudioLoca is a mobile music application with a Flutter frontend and a FastAPI backend. The app combines local music library features, Spotify authentication/recommendations, location-aware listening data, and on-device emotion recognition models.

## Project Structure

```text
audioloca/
  audioloca/   Flutter mobile app
  server/      FastAPI backend API
```

## Prerequisites

- Flutter SDK with Dart 3.9 or newer
- Python 3.12 or newer
- A running database supported by the configured SQLAlchemy `DATABASE_URL`
- Spotify developer application credentials
- LocationIQ access token

## Configuration

Sensitive values are kept in local config files that should not be committed.

### Backend

Create `server/.env` from the template:

```bash
cp server/.env.example server/.env
```

Fill in:

```env
DATABASE_URL=
SECRET_KEY=
SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=
APP_REDIRECT_URI=
LOCATIONIQ_ACCESS_TOKEN=
```

### Flutter App

Create the local Flutter environment file:

```bash
cp audioloca/lib/environment.example.dart audioloca/lib/environment.local.dart
```

Fill in the values in `audioloca/lib/environment.local.dart`, especially:

- `audiolocaBaseUrl`
- `spotifyClientId`
- `spotifyClientSecret`
- `spotifyRedirectUri`
- `locationIQAccessToken`

## Run The Backend

```bash
cd server
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn src.main:app --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000` unless another host is configured.

## Run The Flutter App

```bash
cd audioloca
flutter pub get
flutter run
```

To run on a specific connected device:

```bash
flutter devices
flutter run -d <device-id>
```

## Main Features

- Local user sign up and login
- Spotify OAuth login
- Secure token storage on device
- Spotify track search and recommendations
- Local audio and album management
- Location-aware stream tracking
- Emotion recognition using bundled TensorFlow Lite models

## Development Notes

- Do not commit `server/.env`.
- Do not commit `audioloca/lib/environment.local.dart`.
- If API keys were ever committed or pushed, rotate them in the provider dashboard.
- Backend media files and Python cache files should stay out of future commits.