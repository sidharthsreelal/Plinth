import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:plinth/providers/library_provider.dart';
import 'package:plinth/providers/player_provider.dart';
import 'package:plinth/providers/theme_provider.dart';
import 'package:plinth/screens/home_screen.dart';
import 'package:plinth/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const PlinthApp());
}

Future<void> _requestPermissions() async {
  if (!kIsWeb && Platform.isAndroid) {
    final androidVersion = await _getAndroidVersion();
    
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()..init()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
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
}
