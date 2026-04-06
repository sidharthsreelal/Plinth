# Plinth

A local music player for Android that doesn't touch your folder structure. You pick a root folder, it scans recursively, and shows your music exactly how you've organized it.

I built this because I hate when mp3 players flatten my meticulously organized folders into a single giant "All Songs" list. If you organize by folders, Plinth just lets you use your folders.

## Tech stack
- **Flutter / Dart**
- `just_audio` for playback
- `audio_metadata_reader` for grabbing ID3 tags

## Running it

```bash
flutter pub get
flutter run
```

Or build an APK:
```bash
flutter build apk --release
```

## Structure
- `lib/services/` - Scans folders and extracts metadata
- `lib/providers/` - State management (`just_audio` wrappers and library state)
- `lib/models/` - Data models 
- `lib/screens/` - UI

## Known issues
- The "Play All" button on the home screen folder options is currently a stub (it just closes the sheet). It works fine inside the actual folder view though.
- The FFT visualizer on the now playing screen is faked. It's seeded by the track position because getting raw audio data cross-platform was a pain.
- Android storage permissions are a bit of a mess across API levels, so the app tries to guess the right permission to ask for.