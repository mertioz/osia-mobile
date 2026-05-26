import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OsiaApp());
}

class OsiaApp extends StatefulWidget {
  const OsiaApp({super.key});

  @override
  State<OsiaApp> createState() => _OsiaAppState();
}

class _OsiaAppState extends State<OsiaApp> {
  final StorageService _storage = StorageService();
  final ThemeController _themeController = ThemeController();

  bool? _configured;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Restore the saved palette before the first paint so the UI doesn't
    // briefly flash the default theme.
    try {
      final themeKey = await _storage.getThemeKey();
      if (themeKey != null) {
        _themeController.setPaletteByKey(themeKey);
      }
    } catch (_) {
      // Keep default palette on any storage error.
    }

    var configured = false;
    try {
      configured = await _storage
          .isConfigured()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      configured = false;
    }

    if (mounted) {
      setState(() {
        _configured = configured;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        final palette = _themeController.palette;
        return OsiaTheme(
          palette: palette,
          child: MaterialApp(
            title: 'OSIA Mobile',
            debugShowCheckedModeBanner: false,
            theme: buildOsiaTheme(palette),
            builder: (context, child) =>
                OsiaTheme(palette: palette, child: child ?? const SizedBox()),
            home: _buildHome(palette),
            routes: {
              '/settings': (_) => SettingsScreen(
                    storage: _storage,
                    themeController: _themeController,
                  ),
              '/chat': (_) => ChatScreen(storage: _storage),
            },
          ),
        );
      },
    );
  }

  Widget _buildHome(OsiaPalette palette) {
    if (_loading) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: CircularProgressIndicator(color: palette.accent),
        ),
      );
    }
    if (_configured == true) {
      return ChatScreen(storage: _storage);
    }
    return SettingsScreen(
      storage: _storage,
      themeController: _themeController,
    );
  }
}
