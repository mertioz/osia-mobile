import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Sweep any stale temp files left behind by previous picker sessions so
  // the plugin's internal cache stays in a clean state.
  FilePicker.platform.clearTemporaryFiles().then((cleared) {
    debugPrint('[OSIA] FilePicker.clearTemporaryFiles -> $cleared');
  }).catchError((Object e) {
    debugPrint('[OSIA] FilePicker.clearTemporaryFiles failed: $e');
  });
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
            onGenerateRoute: _generateRoute,
          ),
        );
      },
    );
  }

  /// Named routes, each wrapped in a smooth slide-up + fade transition.
  /// Same destinations as before — only the transition changed.
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/settings':
        return _slideFadeRoute(
          SettingsScreen(
            storage: _storage,
            themeController: _themeController,
          ),
          settings,
        );
      case '/chat':
        return _slideFadeRoute(ChatScreen(storage: _storage), settings);
    }
    return null;
  }

  static Route<dynamic> _slideFadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
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
