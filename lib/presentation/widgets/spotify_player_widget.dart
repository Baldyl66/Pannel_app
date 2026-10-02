import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/spotify_service.dart';

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
  
  String _trackName = 'Aucune lecture en cours';
  String _artistName = '-';
  String? _albumImageUrl;
  String? _albumName;
  String? _releaseDate;
  bool _isPlaying = false;
  int _progressMs = 0;
  int _durationMs = 0;
  List<dynamic> _playlists = [];
  
  Timer? _localProgressTimer;

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
      duration: const Duration(seconds: 4),
    );
    _checkLoginStatus();
  }
  
  Future<void> _checkLoginStatus() async {
    final loggedIn = await _spotifyService.isLoggedIn();
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });
    
    if (_isLoggedIn) {
      _startFetchingData();
    }
  }
  
  void _startFetchingData() {
    _fetchCurrentlyPlaying();
    _fetchPlaylists();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchCurrentlyPlaying();
    });
    _localProgressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPlaying && _progressMs < _durationMs) {
        setState(() {
          _progressMs += 1000;
        });
      }
    });
  }
  
  Future<void> _fetchPlaylists() async {
    final lists = await _spotifyService.getUserPlaylists();
    if (!mounted) return;
    setState(() {
      _playlists = lists;
    });
  }

  Future<void> _fetchCurrentlyPlaying() async {
    final data = await _spotifyService.getCurrentlyPlaying();
    if (!mounted) return;
    
    if (data == null || data['item'] == null) {
      setState(() {
        _trackName = 'Aucune lecture en cours';
        _artistName = '-';
        _isPlaying = false;
        _rotationController.stop();
      });
      return;
    }
    
    final item = data['item'];
    final isPlaying = data['is_playing'] ?? false;
    
    setState(() {
      _trackName = item['name'];
      _artistName = (item['artists'] as List).map((a) => a['name']).join(', ');
      _albumImageUrl = (item['album']['images'] as List).isNotEmpty 
          ? item['album']['images'][0]['url'] 
          : null;
      _albumName = item['album']?['name'];
      
      final rawDate = item['album']?['release_date'];
      _releaseDate = (rawDate != null && rawDate.length >= 4) ? rawDate.substring(0, 4) : rawDate;
      
      _isPlaying = isPlaying;
      _progressMs = data['progress_ms'] ?? 0;
      _durationMs = item['duration_ms'] ?? 0;
    });
    
    if (_isPlaying) {
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
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
    if (_isLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: const Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }

    if (!_isLoggedIn) {
      return InkWell(
        onTap: () async {
          await _spotifyService.login();
          _checkLoginStatus();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10, width: 1),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Connecter Spotify',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          // Album Cover (Vinyl Style) with Play/Pause interaction
          GestureDetector(
            onTap: _showTrackProfileModal,
            child: RotationTransition(
              turns: _rotationController,
              child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222222),
                border: Border.all(color: Colors.black87, width: 4), // Bordure noire du vinyle
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
                image: _albumImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_albumImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _albumImageUrl == null
                  ? const Icon(Icons.music_note, color: Colors.white24, size: 32)
                  : Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF151515), // Trou au milieu
                          border: Border.all(color: Colors.black54, width: 1),
                        ),
                      ),
                    ),
            ),
          ),
          ), // Close GestureDetector
          const SizedBox(width: 16),
          
          // Track Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _trackName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _artistName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status ("En lecture")
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isPlaying 
                              ? const MiniWaveform(isPlaying: true, color: Color(0xFF1DB954))
                              : const Icon(Icons.pause, color: Colors.white24, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _isPlaying ? 'Lecture' : 'Pause',
                            style: TextStyle(
                              color: _isPlaying ? const Color(0xFF1DB954) : Colors.white24,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.skip_previous, color: Colors.white70, size: 22),
                            onPressed: () async {
                              await _spotifyService.skipToPrevious();
                              await Future.delayed(const Duration(milliseconds: 500));
                              _fetchCurrentlyPlaying();
                            },
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 24),
                            onPressed: () async {
                              final wasPlaying = _isPlaying;
                              setState(() {
                                _isPlaying = !_isPlaying;
                                if (_isPlaying) {
                                  _rotationController.repeat();
                                } else {
                                  _rotationController.stop();
                                }
                              });
                              
                              final success = await _spotifyService.togglePlayback(wasPlaying);
                              if (!success) {
                                setState(() {
                                  _isPlaying = wasPlaying;
                                  if (_isPlaying) {
                                    _rotationController.repeat();
                                  } else {
                                    _rotationController.stop();
                                  }
                                });
                              } else {
                                _fetchCurrentlyPlaying();
                              }
                            },
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.skip_next, color: Colors.white70, size: 22),
                            onPressed: () async {
                              await _spotifyService.skipToNext();
                              await Future.delayed(const Duration(milliseconds: 500));
                              _fetchCurrentlyPlaying();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                if (_durationMs > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatDuration(_progressMs),
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _durationMs > 0 ? (_progressMs / _durationMs).clamp(0.0, 1.0) : 0,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_durationMs),
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
          if (_playlists.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Bouton pour ouvrir la modale des playlists
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.queue_music, size: 20),
                label: const Text('Mes Playlists', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: _showPlaylistsModal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTrackProfileModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 32),
              if (_albumImageUrl != null)
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 32, offset: Offset(0, 16))],
                    image: DecorationImage(image: NetworkImage(_albumImageUrl!), fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 32),
              Text(
                _trackName,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _artistName,
                style: const TextStyle(color: Color(0xFF1DB954), fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Grille de détails
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDetailStat(Icons.album, 'Album', _albumName ?? '-'),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _buildDetailStat(Icons.date_range, 'Année', _releaseDate ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 48),
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
          Icon(icon, color: Colors.white54, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  void _showPlaylistsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Vos Playlists', 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = _playlists[index];
                    final imageUrl = (playlist['images'] as List?)?.isNotEmpty == true
                        ? playlist['images'][0]['url']
                        : null;
                    return GestureDetector(
                      onTap: () async {
                        if (playlist['uri'] != null) {
                          Navigator.pop(context); // Ferme la modale
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lancement de ${playlist['name']}...'), duration: const Duration(seconds: 1)),
                          );
                          final success = await _spotifyService.playPlaylist(playlist['uri']);
                          if (!success && context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Impossible de lancer (Premium requis ou erreur)')),
                             );
                          } else {
                             await Future.delayed(const Duration(milliseconds: 1000));
                             _fetchCurrentlyPlaying();
                          }
                        }
                      },
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: imageUrl != null 
                                    ? Image.network(imageUrl, width: 100, height: 100, fit: BoxFit.cover)
                                    : Container(width: 100, height: 100, color: Colors.white10, child: const Icon(Icons.music_note, color: Colors.white24, size: 30)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              playlist['name'] ?? 'Inconnu',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
      height: 14,
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
        // Vary height based on animation and the bar's specific scales
        final val = widget.isPlaying 
            ? (minScale + (maxScale - minScale) * _controller.value) 
            : 0.3; // Flat when paused
        return Container(
          width: 3,
          height: 14 * val,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
