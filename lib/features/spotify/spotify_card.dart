import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import 'spotify_service.dart';

/// Lecteur Spotify de l'accueil : pochette, titre, contrôles, progression
/// et accès aux playlists.
class SpotifyCard extends StatefulWidget {
  final VoidCallback? onAccountChanged;
  const SpotifyCard({super.key, this.onAccountChanged});

  @override
  State<SpotifyCard> createState() => _SpotifyCardState();
}

class _SpotifyCardState extends State<SpotifyCard> {
  final SpotifyService _spotify = SpotifyService();

  bool _isLoggedIn = false;
  bool _isLoading = true;
  Timer? _refreshTimer;
  Timer? _progressTimer;

  String? _trackName;
  String _artistName = '';
  String? _albumImageUrl;
  String? _albumName;
  String? _releaseDate;
  bool _isPlaying = false;
  int _progressMs = 0;
  int _durationMs = 0;
  List<dynamic> _playlists = [];

  bool get _appInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  static String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _spotify.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });
    if (loggedIn) _startPolling();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await _spotify.login();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Connexion Spotify impossible', isError: true);
    }
    await _checkLoginStatus();
    if (_isLoggedIn) widget.onAccountChanged?.call();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _progressTimer?.cancel();
    _fetchCurrentlyPlaying();
    _fetchPlaylists();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      // Pas d'appels réseau inutiles quand l'app est en arrière-plan.
      if (_appInForeground) _fetchCurrentlyPlaying();
    });
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isPlaying && _progressMs < _durationMs) {
        setState(() => _progressMs = (_progressMs + 1000).clamp(0, _durationMs));
      }
    });
  }

  Future<void> _fetchPlaylists() async {
    final lists = await _spotify.getUserPlaylists();
    if (mounted) setState(() => _playlists = lists);
  }

  Future<void> _fetchCurrentlyPlaying() async {
    final data = await _spotify.getCurrentlyPlaying();
    if (!mounted) return;
    if (data == null || data['item'] == null) {
      setState(() {
        _trackName = null;
        _artistName = '';
        _albumImageUrl = null;
        _isPlaying = false;
        _durationMs = 0;
      });
      return;
    }
    final item = data['item'];
    final images = (item['album']?['images'] as List?) ?? const [];
    final rawDate = item['album']?['release_date'] as String?;
    setState(() {
      _trackName = item['name'];
      _artistName = ((item['artists'] as List?) ?? const []).map((a) => a['name']).join(', ');
      _albumImageUrl = images.isNotEmpty ? images[0]['url'] : null;
      _albumName = item['album']?['name'];
      _releaseDate = (rawDate != null && rawDate.length >= 4) ? rawDate.substring(0, 4) : rawDate;
      _isPlaying = data['is_playing'] ?? false;
      _progressMs = data['progress_ms'] ?? 0;
      _durationMs = item['duration_ms'] ?? 0;
    });
  }

  Future<void> _togglePlayback() async {
    Haptics.light();
    final wasPlaying = _isPlaying;
    setState(() => _isPlaying = !wasPlaying);
    final ok = await _spotify.togglePlayback(wasPlaying);
    if (!mounted) return;
    if (!ok) {
      setState(() => _isPlaying = wasPlaying);
      showAppSnackBar(context, 'Commande refusée : Spotify Premium et un appareil actif sont requis', isError: true);
    } else {
      _fetchCurrentlyPlaying();
    }
  }

  Future<void> _skip({required bool next}) async {
    Haptics.light();
    final ok = next ? await _spotify.skipToNext() : await _spotify.skipToPrevious();
    if (!mounted) return;
    if (!ok) {
      showAppSnackBar(context, 'Commande refusée : Spotify Premium requis', isError: true);
      return;
    }
    await Future.delayed(const Duration(milliseconds: 500));
    _fetchCurrentlyPlaying();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonBox(height: 196);
    if (!_isLoggedIn) {
      return ConnectServiceCard(
        icon: const FaIcon(FontAwesomeIcons.spotify),
        brandColor: AppColors.spotify,
        service: 'Spotify',
        description: 'Contrôlez votre musique et vos playlists.',
        onConnect: _login,
      );
    }

    final theme = Theme.of(context);
    final hasTrack = _trackName != null;
    final progress = _durationMs > 0 ? (_progressMs / _durationMs).clamp(0.0, 1.0) : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        children: [
          // Fond : pochette floutée
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: AppDurations.slow,
              child: _albumImageUrl == null
                  ? const ColoredBox(color: AppColors.surface, child: SizedBox.expand())
                  : ImageFiltered(
                      key: ValueKey(_albumImageUrl),
                      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Image.network(_albumImageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                    ),
            ),
          ),
          Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: _albumImageUrl == null ? 0 : 0.55))),
          AppCard(
            color: Colors.transparent,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.spotify, color: AppColors.spotify, size: 15),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      hasTrack ? (_isPlaying ? 'EN LECTURE' : 'EN PAUSE') : 'SPOTIFY',
                      style: theme.textTheme.labelSmall?.copyWith(color: _isPlaying ? AppColors.spotify : null),
                    ),
                    if (_isPlaying) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const MiniWaveform(isPlaying: true, color: AppColors.spotify),
                    ],
                    const Spacer(),
                    if (_playlists.isNotEmpty)
                      _GlassButton(icon: Icons.queue_music_rounded, label: 'Playlists', onTap: _showPlaylists),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    GestureDetector(
                      onTap: hasTrack ? _showTrackDetails : null,
                      child: AnimatedScale(
                        scale: _isPlaying ? 1 : 0.92,
                        duration: AppDurations.slow,
                        curve: AppCurves.emphasized,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHighest,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
                            image: _albumImageUrl == null
                                ? null
                                : DecorationImage(image: NetworkImage(_albumImageUrl!), fit: BoxFit.cover),
                          ),
                          child: _albumImageUrl == null
                              ? const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 32)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _trackName ?? 'Rien en lecture',
                            style: theme.textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasTrack ? _artistName : 'Lancez un titre ou une playlist',
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(_formatDuration(_progressMs), style: _timeStyle(theme)),
                    const Spacer(),
                    Text(_durationMs > 0 ? _formatDuration(_durationMs) : '–:––', style: _timeStyle(theme)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Précédent',
                      iconSize: 32,
                      color: Colors.white,
                      icon: const Icon(Icons.skip_previous_rounded),
                      onPressed: () => _skip(next: false),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    IconButton.filled(
                      tooltip: _isPlaying ? 'Pause' : 'Lecture',
                      iconSize: 32,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(60, 60),
                      ),
                      icon: AnimatedSwitcher(
                        duration: AppDurations.fast,
                        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          key: ValueKey(_isPlaying),
                        ),
                      ),
                      onPressed: _togglePlayback,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    IconButton(
                      tooltip: 'Suivant',
                      iconSize: 32,
                      color: Colors.white,
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: () => _skip(next: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle? _timeStyle(ThemeData theme) => theme.textTheme.labelMedium?.copyWith(
        color: AppColors.textTertiary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  void _showTrackDetails() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl),
          child: Column(
            children: [
              if (_albumImageUrl != null)
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 32, offset: Offset(0, 16))],
                    image: DecorationImage(image: NetworkImage(_albumImageUrl!), fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
              Text(_trackName ?? '', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _artistName,
                style: theme.textTheme.titleMedium?.copyWith(color: AppColors.spotify),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                child: Row(
                  children: [
                    _DetailStat(icon: Icons.album_rounded, label: 'Album', value: _albumName ?? '–'),
                    Container(width: 1, height: 40, color: AppColors.border),
                    _DetailStat(icon: Icons.calendar_today_rounded, label: 'Année', value: _releaseDate ?? '–'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPlaylists() {
    showAppSheet<void>(
      context,
      title: 'Vos playlists',
      subtitle: 'Touchez pour lancer la lecture',
      builder: (sheetContext) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 170,
          mainAxisSpacing: AppSpacing.lg,
          crossAxisSpacing: AppSpacing.lg,
          childAspectRatio: 0.78,
        ),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final playlist = _playlists[index];
          final images = playlist['images'] as List?;
          final imageUrl = images?.isNotEmpty == true ? images![0]['url'] as String? : null;
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () async {
              final uri = playlist['uri'] as String?;
              if (uri == null) return;
              Haptics.light();
              Navigator.pop(sheetContext);
              final ok = await _spotify.playPlaylist(uri);
              if (!mounted) return;
              if (!ok) {
                showAppSnackBar(this.context, 'Impossible de lancer la playlist (Premium requis)', isError: true);
              } else {
                showAppSnackBar(this.context, 'Lecture de « ${playlist['name']} »');
                await Future.delayed(const Duration(seconds: 1));
                _fetchCurrentlyPlaying();
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surfaceHighest))
                        : const ColoredBox(
                            color: AppColors.surfaceHighest,
                            child: Center(child: Icon(Icons.music_note_rounded, color: AppColors.textTertiary)),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  playlist['name'] ?? 'Sans titre',
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Petit égaliseur animé.
class MiniWaveform extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  const MiniWaveform({super.key, required this.isPlaying, required this.color});

  @override
  State<MiniWaveform> createState() => _MiniWaveformState();
}

class _MiniWaveformState extends State<MiniWaveform> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MiniWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      widget.isPlaying ? _controller.repeat(reverse: true) : _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double min, double max) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Container(
            width: 3,
            height: 12 * (widget.isPlaying ? min + (max - min) * _controller.value : 0.3),
            decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
          ),
        );
    return SizedBox(
      width: 14,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [bar(0.3, 0.9), bar(0.5, 1.0), bar(0.2, 0.7)],
      ),
    );
  }
}
