import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/spotify_service.dart';
import 'common/app_card.dart';
import 'common/app_dialogs.dart';
import 'common/empty_state.dart';

class SpotifyPlayerWidget extends StatefulWidget {
  const SpotifyPlayerWidget({super.key});

  @override
  State<SpotifyPlayerWidget> createState() => _SpotifyPlayerWidgetState();
}

class _SpotifyPlayerWidgetState extends State<SpotifyPlayerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  final SpotifyService _spotifyService = SpotifyService();

  bool _isLoggedIn = false;
  bool _isLoading = true;
  Timer? _refreshTimer;

  String? _trackName;
  String _artistName = '';
  String? _albumImageUrl;
  String? _albumName;
  String? _releaseDate;
  bool _isPlaying = false;
  int _progressMs = 0;
  int _durationMs = 0;
  List<dynamic> _playlists = [];

  Timer? _localProgressTimer;

  bool get _appInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _spotifyService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });

    if (_isLoggedIn) {
      _startFetchingData();
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    await _spotifyService.login();
    await _checkLoginStatus();
  }

  void _startFetchingData() {
    _refreshTimer?.cancel();
    _localProgressTimer?.cancel();
    _fetchCurrentlyPlaying();
    _fetchPlaylists();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      // Pas d'appels réseau inutiles quand l'app est en arrière-plan.
      if (_appInForeground) _fetchCurrentlyPlaying();
    });
    _localProgressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isPlaying && _progressMs < _durationMs) {
        setState(() => _progressMs = (_progressMs + 1000).clamp(0, _durationMs));
      }
    });
  }

  Future<void> _fetchPlaylists() async {
    final lists = await _spotifyService.getUserPlaylists();
    if (!mounted) return;
    setState(() => _playlists = lists);
  }

  Future<void> _fetchCurrentlyPlaying() async {
    final data = await _spotifyService.getCurrentlyPlaying();
    if (!mounted) return;

    if (data == null || data['item'] == null) {
      setState(() {
        _trackName = null;
        _artistName = '';
        _albumImageUrl = null;
        _isPlaying = false;
        _durationMs = 0;
      });
      _rotationController.stop();
      return;
    }

    final item = data['item'];
    final images = (item['album']?['images'] as List?) ?? const [];

    setState(() {
      _trackName = item['name'];
      _artistName = ((item['artists'] as List?) ?? const []).map((a) => a['name']).join(', ');
      _albumImageUrl = images.isNotEmpty ? images[0]['url'] : null;
      _albumName = item['album']?['name'];

      final rawDate = item['album']?['release_date'] as String?;
      _releaseDate = (rawDate != null && rawDate.length >= 4) ? rawDate.substring(0, 4) : rawDate;

      _isPlaying = data['is_playing'] ?? false;
      _progressMs = data['progress_ms'] ?? 0;
      _durationMs = item['duration_ms'] ?? 0;
    });

    if (_isPlaying) {
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  void _setPlaying(bool playing) {
    setState(() => _isPlaying = playing);
    if (playing) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  Future<void> _togglePlayback() async {
    HapticFeedback.lightImpact();
    final wasPlaying = _isPlaying;
    _setPlaying(!wasPlaying);

    final success = await _spotifyService.togglePlayback(wasPlaying);
    if (!mounted) return;
    if (!success) {
      _setPlaying(wasPlaying);
      showAppSnackBar(context, 'Commande refusée (Spotify Premium et un appareil actif sont requis)', isError: true);
    } else {
      _fetchCurrentlyPlaying();
    }
  }

  Future<void> _skip({required bool next}) async {
    HapticFeedback.lightImpact();
    final ok = next ? await _spotifyService.skipToNext() : await _spotifyService.skipToPrevious();
    if (!mounted) return;
    if (!ok) {
      showAppSnackBar(context, 'Commande refusée (Spotify Premium requis)', isError: true);
      return;
    }
    await Future.delayed(const Duration(milliseconds: 500));
    _fetchCurrentlyPlaying();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _localProgressTimer?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonCard(height: 168);

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

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : source + statut + playlists
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.spotify, color: AppColors.spotify, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Text('SPOTIFY', style: theme.textTheme.labelSmall),
              const SizedBox(width: AppSpacing.md),
              if (hasTrack) ...[
                MiniWaveform(isPlaying: _isPlaying, color: _isPlaying ? AppColors.spotify : AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  _isPlaying ? 'En lecture' : 'En pause',
                  style: TextStyle(
                    color: _isPlaying ? AppColors.spotify : AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Spacer(),
              if (_playlists.isNotEmpty)
                TextButton.icon(
                  onPressed: _showPlaylistsModal,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.queue_music_rounded, size: 18),
                  label: const Text('Playlists'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // Pochette façon vinyle : tap pour les détails du titre.
              GestureDetector(
                onTap: hasTrack ? _showTrackProfileModal : null,
                child: RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceHighest,
                      border: Border.all(color: Colors.black87, width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6))],
                      image: _albumImageUrl != null
                          ? DecorationImage(image: NetworkImage(_albumImageUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _albumImageUrl == null
                        ? const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 30)
                        : Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surface,
                                border: Border.all(color: Colors.black54),
                              ),
                            ),
                          ),
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
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasTrack ? _artistName : 'Lancez un titre ou une playlist',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Précédent',
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: () => _skip(next: false),
                        ),
                        IconButton.filled(
                          tooltip: _isPlaying ? 'Pause' : 'Lecture',
                          style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                          onPressed: _togglePlayback,
                        ),
                        IconButton(
                          tooltip: 'Suivant',
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
          if (_durationMs > 0) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_progressMs / _durationMs).clamp(0.0, 1.0),
                color: AppColors.spotify,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_progressMs), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0)),
                Text(_formatDuration(_durationMs), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showTrackProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(_trackName ?? '', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _artistName,
                style: const TextStyle(color: AppColors.spotify, fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppCard(
                color: Colors.white.withValues(alpha: 0.04),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                child: Row(
                  children: [
                    _buildDetailStat(Icons.album_rounded, 'Album', _albumName ?? '-'),
                    Container(width: 1, height: 40, color: AppColors.border),
                    _buildDetailStat(Icons.calendar_today_rounded, 'Année', _releaseDate ?? '-'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailStat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  void _showPlaylistsModal() {
    showAppSheet<void>(
      context,
      title: 'Vos playlists',
      builder: (sheetContext) => SizedBox(
        height: 170,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _playlists.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.lg),
          itemBuilder: (context, index) {
            final playlist = _playlists[index];
            final images = playlist['images'] as List?;
            final imageUrl = images?.isNotEmpty == true ? images![0]['url'] as String? : null;
            return InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () async {
                final uri = playlist['uri'] as String?;
                if (uri == null) return;
                Navigator.pop(sheetContext);
                showAppSnackBar(this.context, 'Lancement de « ${playlist['name']} »…');
                final success = await _spotifyService.playPlaylist(uri);
                if (!mounted) return;
                if (!success) {
                  showAppSnackBar(this.context, 'Impossible de lancer la playlist (Premium requis)', isError: true);
                } else {
                  await Future.delayed(const Duration(seconds: 1));
                  _fetchCurrentlyPlaying();
                }
              },
              child: SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: imageUrl != null
                          ? Image.network(imageUrl, width: 110, height: 110, fit: BoxFit.cover)
                          : Container(
                              width: 110,
                              height: 110,
                              color: AppColors.surfaceHighest,
                              child: const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 30),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      playlist['name'] ?? 'Sans titre',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MiniWaveform extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  const MiniWaveform({super.key, required this.isPlaying, required this.color});

  @override
  State<MiniWaveform> createState() => _MiniWaveformState();
}

class _MiniWaveformState extends State<MiniWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MiniWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar(0.3, 0.9),
          _buildBar(0.5, 1.0),
          _buildBar(0.2, 0.7),
        ],
      ),
    );
  }

  Widget _buildBar(double minScale, double maxScale) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = widget.isPlaying ? (minScale + (maxScale - minScale) * _controller.value) : 0.3;
        return Container(
          width: 3,
          height: 12 * val,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
