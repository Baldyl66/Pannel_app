import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/google_calendar_service.dart';
import '../../services/spotify_service.dart';
import '../../services/theme_service.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_dialogs.dart';
import '../widgets/common/color_swatch_picker.dart';
import '../widgets/common/page_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _AccountInfo {
  final String name;
  final String description;
  final Widget icon;
  final Color color;
  final Future<bool> Function() isConnected;
  final Future<void> Function() logout;

  const _AccountInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isConnected,
    required this.logout,
  });
}

Future<bool> _hasPref(String key) async => (await SharedPreferences.getInstance()).getString(key) != null;

Future<void> _removePref(String key) async => (await SharedPreferences.getInstance()).remove(key);

final _accounts = <_AccountInfo>[
  _AccountInfo(
    name: 'Spotify',
    description: 'Lecteur et playlists',
    icon: const FaIcon(FontAwesomeIcons.spotify),
    color: AppColors.spotify,
    isConnected: () => _hasPref('spotify_token'),
    logout: () => SpotifyService().logout(),
  ),
  _AccountInfo(
    name: 'Google Agenda',
    description: 'Événements et rappels',
    icon: const Icon(Icons.event_rounded),
    color: AppColors.google,
    isConnected: () => GoogleCalendarService().isLoggedIn(),
    logout: () => GoogleCalendarService().logout(),
  ),
  _AccountInfo(
    name: 'Discord',
    description: 'Carte de profil',
    icon: const FaIcon(FontAwesomeIcons.discord),
    color: AppColors.discord,
    isConnected: () => _hasPref('discord_access_token'),
    logout: () => _removePref('discord_access_token'),
  ),
];

class _SettingsPageState extends State<SettingsPage> {
  late Future<List<bool>> _statuses = _loadStatuses();

  Future<List<bool>> _loadStatuses() => Future.wait(_accounts.map((a) async {
        try {
          return await a.isConnected();
        } catch (_) {
          return false;
        }
      }));

  Future<void> _pickBackgroundImage() async {
    const typeGroup = XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file != null) themeNotifier.setBackgroundImage(file.path);
  }

  Future<void> _showCustomColorDialog() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => _HexColorDialog(initial: themeNotifier.accentColor),
    );
    if (color != null) themeNotifier.setAccentColor(color);
  }

  Future<void> _logout(_AccountInfo account) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Déconnecter ${account.name} ?',
      message: 'Vous pourrez vous reconnecter à tout moment depuis le Panel.',
      confirmLabel: 'Déconnecter',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (!confirmed) return;
    await account.logout();
    notifyAccountsChanged();
    if (!mounted) return;
    setState(() => _statuses = _loadStatuses());
    showAppSnackBar(context, '${account.name} déconnecté');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Paramètres')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAppearance(),
                  _buildAccounts(),
                  const SectionLabel('Outils'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: _SettingsTile(
                      icon: Icons.wifi_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      title: 'Wi-Fi invités',
                      subtitle: 'QR code à scanner pour rejoindre le réseau',
                      trailing: const Icon(Icons.qr_code_2_rounded),
                      onTap: () => showAppSheet<void>(
                        context,
                        title: 'Wi-Fi invités',
                        builder: (_) => const _WifiSheet(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: Text(
                      'Panel · v1.0.0',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearance() {
    final accent = themeNotifier.accentColor;
    final bgPath = themeNotifier.backgroundImagePath;
    final isCustom = !AppColors.swatches.any((c) => c.toARGB32() == accent.toARGB32());
    final hex = accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Apparence'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconBadge(icon: const Icon(Icons.palette_outlined), color: accent),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Couleur d\'accent', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                              Text('#$hex', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _showCustomColorDialog,
                          style: TextButton.styleFrom(foregroundColor: isCustom ? accent : null),
                          child: const Text('Personnaliser'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ColorSwatchPicker(selected: accent, onChanged: themeNotifier.setAccentColor, size: 32),
                  ],
                ),
              ),
              const Divider(),
              _SettingsTile(
                icon: Icons.wallpaper_rounded,
                color: Colors.white,
                title: 'Image de fond',
                subtitle: bgPath == null ? 'Fond noir OLED' : 'Image personnalisée',
                onTap: _pickBackgroundImage,
                trailing: bgPath == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(bgPath),
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const SizedBox(width: 36, height: 36),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Retirer l\'image',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => themeNotifier.setBackgroundImage(null),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Comptes connectés'),
        FutureBuilder<List<bool>>(
          future: _statuses,
          builder: (context, snapshot) {
            final statuses = snapshot.data;
            return AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _accounts.length; i++) ...[
                    if (i > 0) const Divider(indent: 72),
                    _AccountTile(
                      account: _accounts[i],
                      connected: statuses?[i],
                      onLogout: () => _logout(_accounts[i]),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.sm, AppSpacing.xs, 0),
          child: Text(
            'Pour connecter un compte, utilisez sa carte sur l\'écran Panel.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: IconBadge(icon: Icon(icon), color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}

class _AccountTile extends StatelessWidget {
  final _AccountInfo account;
  final bool? connected;
  final VoidCallback onLogout;

  const _AccountTile({required this.account, required this.connected, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final Widget status;
    if (connected == null) {
      status = const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (connected!) {
      status = TextButton(
        onPressed: onLogout,
        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        child: const Text('Déconnecter'),
      );
    } else {
      status = const Text('Non connecté', style: TextStyle(color: AppColors.textTertiary, fontSize: 13));
    }

    return ListTile(
      leading: IconBadge(icon: account.icon, color: account.color),
      title: Row(
        children: [
          Flexible(child: Text(account.name, overflow: TextOverflow.ellipsis)),
          if (connected == true) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
      subtitle: Text(account.description),
      trailing: status,
    );
  }
}

class _HexColorDialog extends StatefulWidget {
  final Color initial;
  const _HexColorDialog({required this.initial});

  @override
  State<_HexColorDialog> createState() => _HexColorDialogState();
}

class _HexColorDialogState extends State<_HexColorDialog> {
  late final _controller = TextEditingController(
    text: widget.initial.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color? get _parsed {
    final value = _controller.text.trim();
    if (value.length != 6) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }

  @override
  Widget build(BuildContext context) {
    final color = _parsed;
    return AlertDialog(
      title: const Text('Couleur personnalisée'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppDurations.fast,
            height: 56,
            decoration: BoxDecoration(
              color: color ?? AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]'))],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (color != null) Navigator.pop(context, color);
            },
            style: const TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 2),
            decoration: const InputDecoration(prefixText: '#  ', hintText: '1DB954'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: color == null ? null : () => Navigator.pop(context, color),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

/// Configuration et affichage du QR code Wi-Fi invités.
class _WifiSheet extends StatefulWidget {
  const _WifiSheet();

  @override
  State<_WifiSheet> createState() => _WifiSheetState();
}

class _WifiSheetState extends State<_WifiSheet> {
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
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wifi_ssid', _ssid.text.trim());
    await prefs.setString('wifi_password', _security == 'nopass' ? '' : _password.text);
    await prefs.setString('wifi_security', _security);
    if (!mounted) return;
    setState(() {
      _hasSaved = true;
      _isEditing = false;
    });
  }

  String get _qrData {
    String escape(String s) =>
        s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll(':', '\\:').replaceAll('"', '\\"');
    final pass = _security == 'nopass' ? '' : escape(_password.text);
    return 'WIFI:T:$_security;S:${escape(_ssid.text.trim())};P:$pass;;';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: Center(child: CircularProgressIndicator()));
    }
    return AnimatedSwitcher(
      duration: AppDurations.medium,
      child: _isEditing ? _buildForm() : _buildQr(),
    );
  }

  Widget _buildQr() {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('qr'),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: QrImageView(
            data: _qrData,
            size: 220,
            backgroundColor: Colors.white,
            errorStateBuilder: (context, error) => const Center(
              child: Text('QR code impossible à générer', textAlign: TextAlign.center, style: TextStyle(color: Colors.black)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(_ssid.text.trim(), style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text('Scannez avec l\'appareil photo pour rejoindre', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Modifier le réseau'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _ssid,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nom du réseau (SSID)', prefixIcon: Icon(Icons.wifi_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom du réseau requis' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'WPA', label: Text('WPA/WPA2')),
              ButtonSegment(value: 'WEP', label: Text('WEP')),
              ButtonSegment(value: 'nopass', label: Text('Ouvert')),
            ],
            selected: {_security},
            onSelectionChanged: (s) => setState(() => _security = s.first),
            showSelectedIcon: false,
          ),
          if (_security != 'nopass') ...[
            const SizedBox(height: AppSpacing.md),
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
          Row(
            children: [
              if (_hasSaved) ...[
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _load();
                    },
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(child: FilledButton(onPressed: _save, child: const Text('Générer le QR code'))),
            ],
          ),
        ],
      ),
    );
  }
}
