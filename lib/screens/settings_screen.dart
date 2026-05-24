import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../theme.dart';

/// Settings screen for configuring the Tailscale IP and auth token.
///
/// This is the first screen shown when nothing is configured yet.
class SettingsScreen extends StatefulWidget {
  final StorageService storage;

  const SettingsScreen({super.key, required this.storage});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ip = await widget.storage.getTailscaleIp();
    final token = await widget.storage.getToken();
    if (mounted) {
      setState(() {
        _ipController.text = ip ?? '';
        _tokenController.text = token ?? '';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ip = _ipController.text.trim();
      final token = _tokenController.text.trim();

      if (ip.isEmpty || token.isEmpty) {
        setState(() => _error = 'Veuillez remplir tous les champs.');
        return;
      }

      await widget.storage.setTailscaleIp(ip);
      await widget.storage.setToken(token);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/chat');
      }
    } catch (e) {
      setState(() => _error = 'Erreur: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / title
                const Icon(
                  Icons.mic_rounded,
                  size: 56,
                  color: osiaAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'OSIA Mobile',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Configurez la connexion à votre serveur OSIA.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: osiaTextMuted,
                      ),
                ),
                const SizedBox(height: 40),

                // IP field
                Text(
                  'Adresse IP Tailscale du PC',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Ex: 100.64.0.42',
                  ),
                  style: const TextStyle(color: osiaTextPrimary, fontSize: 15),
                ),
                const SizedBox(height: 20),

                // Token field
                Text(
                  'Token d\'authentification',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenController,
                  textInputAction: TextInputAction.done,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Token trouvé sur le serveur PC',
                  ),
                  style: const TextStyle(color: osiaTextPrimary, fontSize: 15),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 8),

                // Paste hint
                GestureDetector(
                  onTap: () async {
                    final data =
                        await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.length >= 32) {
                      if (data.text!.length == 64 &&
                          RegExp(r'^[a-f0-9]+$').hasMatch(data.text!)) {
                        _tokenController.text = data.text!;
                      } else {
                        _ipController.text = data.text!;
                      }
                    }
                  },
                  child: Text(
                    'Coller depuis le presse-papier',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: osiaAccent.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: osiaError.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: osiaError.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: osiaError, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Save button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Se connecter'),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
