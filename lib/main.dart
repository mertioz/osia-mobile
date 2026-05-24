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
  bool? _configured;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    final configured = await _storage.isConfigured();
    if (mounted) {
      setState(() {
        _configured = configured;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSIA Mobile',
      debugShowCheckedModeBanner: false,
      theme: buildOsiaTheme(),

      // Initial route depends on configuration
      initialRoute: _loading
          ? '/loading'
          : (_configured == true ? '/chat' : '/settings'),

      routes: {
        '/loading': (_) => const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: osiaAccent),
              ),
            ),
        '/settings': (_) => SettingsScreen(storage: _storage),
        '/chat': (_) => ChatScreen(storage: _storage),
      },
    );
  }
}
