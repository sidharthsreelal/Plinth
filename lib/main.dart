import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/audio_file.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/providers/favourites_provider.dart';
import 'package:plinth/providers/history_provider.dart';
import 'package:plinth/providers/library_provider.dart';
import 'package:plinth/providers/pins_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/home_screen.dart';
import 'package:plinth/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.plinth.audio.channel',
    androidNotificationChannelName: 'Plinth – Now Playing',
    androidNotificationIcon: 'mipmap/ic_launcher',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    preloadArtwork: true,
  );

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  await _requestPermissions();
  runApp(const PlinthApp());
}

Future<void> _requestPermissions() async {
  if (!kIsWeb && Platform.isAndroid) {
    final androidVersion = await _getAndroidVersion();
    if (androidVersion >= 33) await Permission.notification.request();
    if (androidVersion >= 13) {
      await Permission.audio.request();
    } else if (androidVersion >= 11) {
      await Permission.manageExternalStorage.request();
    } else {
      await Permission.storage.request();
    }
  }
}

Future<int> _getAndroidVersion() async {
  try {
    final process = await Process.run('getprop', ['ro.build.version.release']);
    return int.tryParse(process.stdout.toString().trim().split('.').first) ?? 10;
  } catch (e) {
    return 10;
  }
}

class PlinthApp extends StatelessWidget {
  const PlinthApp({super.key});

  @override
  Widget build(BuildContext context) {
    final historyProvider = HistoryProvider()..init();
    final pinsProvider = PinsProvider()..init();
    final libraryProvider = LibraryProvider();
    final playerProvider = PlayerProvider();

    // A track only counts as "played" when naturally completed (not on skip).
    playerProvider.onTrackCompleted =
        (track) => historyProvider.recordCompletion(track);

    // Hydrate pins as soon as the library finishes loading from cache.
    // This ensures pinned folders are navigable on first startup without
    // waiting for the HomeScreen's addPostFrameCallback.
    void hydrateAll() {
      final root = libraryProvider.rootFolder;
      if (root == null) return;
      final allTracks = _collectAllAudio(root);
      historyProvider.hydrate(allTracks);
      pinsProvider.hydrateAudio(allTracks);
      pinsProvider.hydrateFolder(root);
    }

    libraryProvider.addListener(() {
      // Called whenever library changes (init done, scan done).
      if (libraryProvider.isInitialized && !libraryProvider.isScanning) {
        hydrateAll();
      }
    });

    libraryProvider.init();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => libraryProvider),
        ChangeNotifierProvider(create: (_) => playerProvider),
        ChangeNotifierProvider(create: (_) => FavouritesProvider()..init()),
        ChangeNotifierProvider(create: (_) => historyProvider),
        ChangeNotifierProvider(create: (_) => pinsProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Plinth',
            debugShowCheckedModeBanner: false,
            theme: appTheme(accent: themeProvider.accentColor),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }

  List<AudioFile> _collectAllAudio(FolderNode node) {
    final result = <AudioFile>[...node.audioFiles];
    for (final sub in node.subFolders) {
      result.addAll(_collectAllAudio(sub));
    }
    return result;
  }
}
