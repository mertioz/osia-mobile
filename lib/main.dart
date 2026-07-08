import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'l10n.dart';
import 'nav.dart';
import 'screens/chat_screen.dart';
import 'screens/connection_screen.dart';
import 'services/background_connection_service.dart';
import 'services/connection_lifecycle_service.dart';
import 'services/storage_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Sweep any stale temp files left behind by previous picker sessions so
  // the plugin's internal cache stays in a clean state.
  FilePicker.platform
      .clearTemporaryFiles()
      .then((cleared) {
        debugPrint('[OSIA] FilePicker.clearTemporaryFiles -> $cleared');
      })
      .catchError((Object e) {
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
  final LanguageController _languageController = LanguageController();
  late final BackgroundConnectionService _backgroundConnection;
  late final ConnectionLifecycleService _connectionLifecycle;

  bool? _configured;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _backgroundConnection = BackgroundConnectionService(storage: _storage);
    _connectionLifecycle = ConnectionLifecycleService(
      backgroundConnectionService: _backgroundConnection,
    );
    WidgetsBinding.instance.addObserver(_connectionLifecycle);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_connectionLifecycle);
    super.dispose();
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

    // Restore the saved language; on first launch, auto-detect it from the
    // device locale (EN default, FR/ZH/JA/DE/ES supported).
    try {
      final saved = await _storage.getLanguageCode();
      if (saved != null) {
        _languageController.setLanguageByCode(saved);
      } else {
        final detected = LanguageController.detectDeviceLanguage();
        _languageController.setLanguageByCode(detected);
        await _storage.setLanguageCode(detected);
      }
    } catch (_) {
      // Keep default language (English) on any storage error.
    }

    var configured = false;
    try {
      configured = await _storage.isConfigured().timeout(
        const Duration(seconds: 3),
      );
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
      animation: Listenable.merge([_themeController, _languageController]),
      builder: (context, _) {
        final palette = _themeController.palette;
        final strings = _languageController.strings;
        return OsiaTheme(
          palette: palette,
          child: OsiaL10n(
            strings: strings,
            child: MaterialApp(
              title: 'OSIA Mobile',
              debugShowCheckedModeBanner: false,
              theme: buildOsiaTheme(palette),
              builder: (context, child) => OsiaTheme(
                palette: palette,
                child: OsiaL10n(
                  strings: strings,
                  child: child ?? const SizedBox(),
                ),
              ),
              home: _buildHome(palette),
              onGenerateRoute: _generateRoute,
            ),
          ),
        );
      },
    );
  }

  /// Named routes, each wrapped in a smooth slide-up + fade transition.
  ///
  /// Note: there is intentionally no '/settings' route — settings is only
  /// reachable from the chat screen (i.e. after a successful connection),
  /// which pushes it directly with the live WebSocket service.
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/connection':
        return slideFadeRoute(ConnectionScreen(storage: _storage), settings);
      case '/chat':
        // The connection screen passes its live, validated connection here so
        // the chat screen reuses it instead of opening a new one.
        final handoff = settings.arguments is ChatHandoff
            ? settings.arguments as ChatHandoff
            : null;
        return slideFadeRoute(_buildChatScreen(handoff: handoff), settings);
    }
    return null;
  }

  ChatScreen _buildChatScreen({ChatHandoff? handoff}) {
    return ChatScreen(
      storage: _storage,
      themeController: _themeController,
      languageController: _languageController,
      connectionLifecycle: _connectionLifecycle,
      backgroundConnectionService: _backgroundConnection,
      handoff: handoff,
    );
  }

  Widget _buildHome(OsiaPalette palette) {
    if (_loading) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(child: CircularProgressIndicator(color: palette.accent)),
      );
    }
    if (_configured == true) {
      return _buildChatScreen();
    }
    return ConnectionScreen(storage: _storage);
  }
}
