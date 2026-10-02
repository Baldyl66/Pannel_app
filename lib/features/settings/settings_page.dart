import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_section.dart';
import '../../core/widgets/feedback.dart';
import '../calendar/google_calendar_service.dart';
import '../discord/discord_service.dart';
import '../spotify/spotify_service.dart';
import '../weather/weather_card.dart';
import 'appearance_page.dart';
import 'backup_service.dart';
import 'settings_controller.dart';
import 'wifi_page.dart';

class _Account {
  final String name;
  final String description;
  final Widget icon;
  final Color color;
  final Future<bool> Function() isConnected;
  final Future<void> Function() login;
  final Future<void> Function() logout;

  const _Account({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isConnected,
    required this.login,
    required this.logout,
  });
}

final _accounts = <_Account>[
  _Account(
    name: 'Spotify',
    description: 'Lecteur et playlists',
    icon: const FaIcon(FontAwesomeIcons.spotify),
    color: AppColors.spotify,
    isConnected: () => SpotifyService().isLoggedIn(),
    login: () => SpotifyService().login(),
    logout: () => SpotifyService().logout(),
  ),
  _Account(
    name: 'Google Agenda',
    description: 'Événements et rappels',
    icon: const Icon(Icons.event_rounded),
    color: AppColors.google,
    isConnected: () => GoogleCalendarService().isLoggedIn(),
    login: () async {
      final error = await GoogleCalendarService().login();
      if (error != null) throw Exception(error);
    },
    logout: () => GoogleCalendarService().logout(),
  ),
  _Account(
    name: 'Discord',
    description: 'Carte de profil',
    icon: const FaIcon(FontAwesomeIcons.discord),
    color: AppColors.discord,
    isConnected: () => DiscordService().isLoggedIn(),
    login: () => DiscordService().login(),
    logout: () => DiscordService().logout(),
  ),
];

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<List<bool>> _statuses = _loadStatuses();
  final Set<String> _busy = {};

  Future<List<bool>> _loadStatuses() => Future.wait(_accounts.map((a) async {
        try {
          return await a.isConnected();
        } catch (_) {
          return false;
        }
      }));

  Future<void> _toggleAccount(_Account account, bool connected) async {
    final app = context.app;
    if (connected) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Déconnecter ${account.name} ?',
        message: 'La carte ${account.name} de l\'accueil vous proposera de vous reconnecter.',
        confirmLabel: 'Déconnecter',
        icon: Icons.logout_rounded,
        destructive: true,
      );
      if (!confirmed) return;
    }
    setState(() => _busy.add(account.name));
    try {
      connected ? await account.logout() : await account.login();
      if (mounted) showAppSnackBar(context, connected ? '${account.name} déconnecté' : '${account.name} connecté');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Connexion à ${account.name} impossible', isError: true);
    }
    app.notifyAccountsChanged();
    if (!mounted) return;
    setState(() {
      _busy.remove(account.name);
      _statuses = _loadStatuses();
    });
  }

  Future<void> _export() async {
    final json = await BackupService().export();
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      showAppSnackBar(context, 'Sauvegarde copiée. Collez-la dans une note ou un e-mail pour la conserver.');
    }
  }

  Future<void> _import() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final controller = TextEditingController(text: clipboard?.text ?? '');
    final raw = await showAppSheet<String>(
      context,
      title: 'Restaurer une sauvegarde',
      subtitle: 'Collez le texte copié avec « Exporter »',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            maxLines: 6,
            minLines: 4,
            style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            decoration: const InputDecoration(hintText: '{ "format": "panel-backup", … }'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Vos abonnements, liens, sons et réglages actuels seront remplacés.',
            style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: () => Navigator.pop(sheetContext, controller.text), child: const Text('Restaurer')),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || !mounted) return;
    final app = context.app;
    try {
      final count = await BackupService().import(raw);
      await app.load();
      if (mounted) showAppSnackBar(context, 'Sauvegarde restaurée ($count éléments)');
    } on FormatException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Tout effacer ?',
      message: 'Abonnements, liens, sons et réglages seront supprimés de cet appareil. Pensez à exporter une sauvegarde avant.',
      confirmLabel: 'Tout effacer',
      icon: Icons.delete_forever_rounded,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final app = context.app;
    await BackupService().reset();
    await app.load();
    if (mounted) showAppSnackBar(context, 'Données effacées');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.app.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        final hiddenCount = HomeCard.values.where((c) => !settings.isVisible(c)).length;
        return AppPage(
          title: 'Paramètres',
          slivers: [
            SliverToBoxAdapter(
              child: AppSection(
                title: 'Personnalisation',
                children: [
                  AppTile(
                    icon: Icons.palette_rounded,
                    title: 'Apparence',
                    subtitle: 'Couleur, fond d\'écran',
                    trailing: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: settings.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                    ),
                    chevron: true,
                    onTap: () => _push(context, const AppearancePage()),
                  ),
                  AppTile(
                    icon: Icons.dashboard_customize_rounded,
                    title: 'Écran d\'accueil',
                    subtitle: hiddenCount == 0 ? 'Toutes les cartes affichées' : '$hiddenCount carte${hiddenCount > 1 ? 's' : ''} masquée${hiddenCount > 1 ? 's' : ''}',
                    chevron: true,
                    onTap: () => _push(context, const _HomeCardsPage()),
                  ),
                  AppTile(
                    icon: Icons.location_city_rounded,
                    title: 'Ville pour la météo',
                    subtitle: settings.weather?.label ?? 'Non définie',
                    chevron: true,
                    onTap: () => pickWeatherCity(context),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: FutureBuilder<List<bool>>(
                future: _statuses,
                builder: (context, snapshot) => AppSection(
                  title: 'Comptes connectés',
                  footer: 'Les connexions restent sur cet appareil.',
                  children: [
                    for (var i = 0; i < _accounts.length; i++)
                      _AccountTile(
                        account: _accounts[i],
                        connected: snapshot.data?[i],
                        busy: _busy.contains(_accounts[i].name),
                        onTap: snapshot.data == null ? null : () => _toggleAccount(_accounts[i], snapshot.data![i]),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AppSection(
                title: 'Général',
                children: [
                  AppSwitchTile(
                    icon: Icons.vibration_rounded,
                    title: 'Vibrations',
                    subtitle: 'Retour tactile sur les boutons',
                    value: settings.haptics,
                    onChanged: settings.setHaptics,
                  ),
                  AppSwitchTile(
                    icon: Icons.schedule_rounded,
                    title: 'Horloge 24 h',
                    value: settings.use24h,
                    onChanged: settings.setUse24h,
                  ),
                  AppTile(
                    icon: Icons.wifi_rounded,
                    title: 'Wi-Fi invités',
                    subtitle: 'Partager votre réseau par QR code',
                    chevron: true,
                    onTap: () => _push(context, const WifiPage()),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: AppSection(
                title: 'Données',
                footer: 'La sauvegarde contient vos abonnements, liens, sons et réglages, sans vos identifiants de connexion.',
                children: [
                  AppTile(
                    icon: Icons.upload_rounded,
                    title: 'Exporter une sauvegarde',
                    subtitle: 'Copiée dans le presse-papiers',
                    onTap: _export,
                  ),
                  AppTile(
                    icon: Icons.download_rounded,
                    title: 'Restaurer une sauvegarde',
                    onTap: _import,
                  ),
                  AppTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Tout effacer',
                    destructive: true,
                    onTap: _reset,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.asset('assets/app_icon.png', width: 56, height: 56, errorBuilder: (_, _, _) => const SizedBox()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Panel', style: theme.textTheme.titleMedium),
                  Text('Version 2.0.0', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AccountTile extends StatelessWidget {
  final _Account account;
  final bool? connected;
  final bool busy;
  final VoidCallback? onTap;

  const _AccountTile({required this.account, required this.connected, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    if (connected == null || busy) {
      trailing = const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (connected!) {
      trailing = const AppTag(label: 'Connecté', color: AppColors.success, icon: Icons.check_rounded);
    } else {
      trailing = Text(
        'Connecter',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
      );
    }
    return AppTile(
      leading: IconBadge(icon: account.icon, color: account.color),
      title: account.name,
      subtitle: connected == true ? '${account.description} · Toucher pour déconnecter' : account.description,
      trailing: trailing,
      onTap: busy ? null : onTap,
    );
  }
}

/// Choix des cartes affichées sur l'accueil.
class _HomeCardsPage extends StatelessWidget {
  const _HomeCardsPage();

  @override
  Widget build(BuildContext context) {
    final settings = context.app.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => AppPage(
        title: 'Écran d\'accueil',
        slivers: [
          SliverToBoxAdapter(
            child: AppSection(
              title: 'Cartes affichées',
              footer: 'Les cartes masquées restent connectées et réapparaissent dès que vous les réactivez.',
              children: [
                for (final card in HomeCard.values)
                  AppSwitchTile(
                    icon: card.icon,
                    title: card.label,
                    value: settings.isVisible(card),
                    onChanged: (v) => settings.setCardVisible(card, v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
