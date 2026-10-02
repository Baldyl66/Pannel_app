import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import 'discord_service.dart';

/// Carte de profil Discord.
class DiscordCard extends StatefulWidget {
  final VoidCallback? onAccountChanged;
  const DiscordCard({super.key, this.onAccountChanged});

  @override
  State<DiscordCard> createState() => _DiscordCardState();
}

class _DiscordCardState extends State<DiscordCard> {
  final _service = DiscordService();
  DiscordProfile? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    DiscordProfile? profile;
    try {
      profile = await _service.fetchProfile();
    } catch (e) {
      debugPrint('Discord : $e');
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await _service.login();
      if (!mounted) return;
      setState(() => _profile = profile);
      widget.onAccountChanged?.call();
    } catch (e) {
      debugPrint('Connexion Discord : $e');
      if (mounted) setState(() => _error = 'Connexion impossible, réessayez.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonBox(height: 150);
    final profile = _profile;
    if (profile == null) {
      return ConnectServiceCard(
        icon: const FaIcon(FontAwesomeIcons.discord),
        brandColor: AppColors.discord,
        service: 'Discord',
        description: 'Affichez votre carte de profil.',
        error: _error,
        onConnect: _login,
      );
    }

    final theme = Theme.of(context);
    final bannerColor = profile.accentColor != null ? Color(0xFF000000 | profile.accentColor!) : AppColors.discord;
    const bannerHeight = 88.0;
    const avatarRadius = 34.0;
    const ring = 4.0;
    final avatarBox = avatarRadius * 2 + ring * 2;

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: bannerHeight,
                  width: double.infinity,
                  child: profile.bannerUrl != null
                      ? Image.network(profile.bannerUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: bannerColor))
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [bannerColor, Color.lerp(bannerColor, Colors.black, 0.5)!]),
                          ),
                        ),
                ),
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                    child: const FaIcon(FontAwesomeIcons.discord, size: 14, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: AppSpacing.lg,
                  top: bannerHeight - avatarRadius - ring,
                  child: SizedBox.square(
                    dimension: avatarBox + 16,
                    child: Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(ring),
                          decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: bannerColor,
                            backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                            child: profile.avatarUrl == null ? const Icon(Icons.person_rounded, size: 32, color: Colors.white) : null,
                          ),
                        ),
                        if (profile.decorationUrl != null)
                          Positioned(
                            left: -8,
                            top: -8,
                            child: IgnorePointer(
                              child: Image.network(
                                profile.decorationUrl!,
                                width: avatarBox + 16,
                                height: avatarBox + 16,
                                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        // Pastille « en ligne »
                        Positioned(
                          left: avatarBox - 22,
                          top: avatarBox - 22,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg + avatarBox + AppSpacing.md, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          style: theme.textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.hasNitro) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const AppTag(label: 'Nitro', color: Color(0xFFF47FFF), icon: Icons.diamond_rounded),
                      ],
                    ],
                  ),
                  Text('@${profile.username}', style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
