import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';

/// Contenu du QR code Wi-Fi (format standard reconnu par les appareils photo).
String wifiQrData({required String ssid, required String password, required String security}) {
  String escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll(':', '\\:')
      .replaceAll('"', '\\"');
  final pass = security == 'nopass' ? '' : escape(password);
  return 'WIFI:T:$security;S:${escape(ssid.trim())};P:$pass;;';
}

/// Partage du Wi-Fi aux invités par QR code.
class WifiPage extends StatefulWidget {
  const WifiPage({super.key});

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  final _formKey = GlobalKey<FormState>();
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  String _security = 'WPA';
  bool _isEditing = false;
  bool _isLoading = true;
  bool _obscure = true;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _ssid.text = prefs.getString('wifi_ssid') ?? '';
      _password.text = prefs.getString('wifi_password') ?? '';
      _security = prefs.getString('wifi_security') ?? 'WPA';
      _hasSaved = _ssid.text.trim().isNotEmpty;
      _isEditing = !_hasSaved;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      Haptics.medium();
      return;
    }
    FocusScope.of(context).unfocus();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wifi_ssid', _ssid.text.trim());
    await prefs.setString('wifi_password', _security == 'nopass' ? '' : _password.text);
    await prefs.setString('wifi_security', _security);
    if (!mounted) return;
    Haptics.medium();
    setState(() {
      _hasSaved = true;
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Wi-Fi invités',
      actions: [
        if (_hasSaved && !_isEditing)
          IconButton(
            tooltip: 'Modifier le réseau',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => setState(() => _isEditing = true),
          ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: _isLoading
                ? const SkeletonBox(height: 360)
                : AnimatedSwitcher(
                    duration: AppDurations.medium,
                    child: _isEditing ? _buildForm() : _buildQr(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQr() {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('qr'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: QrImageView(
                  data: wifiQrData(ssid: _ssid.text, password: _password.text, security: _security),
                  size: 230,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Colors.black),
                  errorStateBuilder: (context, error) => const Center(
                    child: Text('QR code impossible à générer', textAlign: TextAlign.center, style: TextStyle(color: Colors.black)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(_ssid.text.trim(), style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ouvrez l\'appareil photo et visez le code pour rejoindre le réseau.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (_security != 'nopass' && _password.text.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _password.text));
              if (mounted) showAppSnackBar(context, 'Mot de passe copié');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copier le mot de passe'),
          ),
        ],
      ],
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ces informations restent sur votre appareil. Elles servent uniquement à générer le QR code.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: _ssid,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nom du réseau', prefixIcon: Icon(Icons.wifi_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom du réseau requis' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('SÉCURITÉ', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'WPA', label: Text('WPA / WPA2')),
              ButtonSegment(value: 'WEP', label: Text('WEP')),
              ButtonSegment(value: 'nopass', label: Text('Aucune')),
            ],
            selected: {_security},
            onSelectionChanged: (s) {
              Haptics.selection();
              setState(() => _security = s.first);
            },
            showSelectedIcon: false,
          ),
          if (_security != 'nopass') ...[
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Afficher' : 'Masquer',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.qr_code_2_rounded), label: const Text('Générer le QR code')),
          if (_hasSaved) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: _load, child: const Text('Annuler')),
          ],
        ],
      ),
    );
  }
}
