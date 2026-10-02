import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage/json_store.dart';

/// Icônes proposées pour les boutons (stockées par nom, pas par code point,
/// pour rester compatibles avec l'optimisation des polices d'icônes).
const soundIcons = <String, IconData>{
  'volume': Icons.volume_up_rounded,
  'music': Icons.music_note_rounded,
  'clap': Icons.back_hand_rounded,
  'laugh': Icons.sentiment_very_satisfied_rounded,
  'sad': Icons.sentiment_dissatisfied_rounded,
  'bell': Icons.notifications_rounded,
  'drum': Icons.album_rounded,
  'horn': Icons.campaign_rounded,
  'fire': Icons.local_fire_department_rounded,
  'star': Icons.star_rounded,
  'heart': Icons.favorite_rounded,
  'bolt': Icons.bolt_rounded,
  'party': Icons.celebration_rounded,
  'skull': Icons.dangerous_rounded,
  'mic': Icons.mic_rounded,
  'game': Icons.sports_esports_rounded,
};

class SoundItem {
  final String id;
  final String name;
  final String path;
  final int colorValue;
  final String icon;
  final double volume;
  final bool loop;

  const SoundItem({
    required this.id,
    required this.name,
    required this.path,
    required this.colorValue,
    this.icon = 'volume',
    this.volume = 1,
    this.loop = false,
  });

  Color get color => Color(colorValue);
  IconData get iconData => soundIcons[icon] ?? Icons.volume_up_rounded;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'colorValue': colorValue,
        'icon': icon,
        'volume': volume,
        'loop': loop,
      };

  factory SoundItem.fromJson(Map<String, dynamic> json) => SoundItem(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        colorValue: json['colorValue'] as int? ?? 0xFF1DB954,
        icon: json['icon'] as String? ?? 'volume',
        volume: (json['volume'] as num?)?.toDouble() ?? 1,
        loop: json['loop'] as bool? ?? false,
      );
}

/// Sons enregistrés + lecture audio.
class SoundboardController extends ChangeNotifier {
  SoundboardController({JsonListStore<SoundItem>? store})
      : _store = store ??
            JsonListStore<SoundItem>(key: 'soundboard_items', fromJson: SoundItem.fromJson, toJson: (s) => s.toJson());

  final JsonListStore<SoundItem> _store;
  final Map<String, AudioPlayer> _players = {};
  final Set<String> _playing = {};

  List<SoundItem> _items = [];
  bool _loaded = false;
  double _masterVolume = 1;

  bool get isLoaded => _loaded;
  bool get isEmpty => _items.isEmpty;
  int get count => _items.length;
  List<SoundItem> get all => List.unmodifiable(_items);
  double get masterVolume => _masterVolume;
  bool isPlaying(String id) => _playing.contains(id);
  int get playingCount => _playing.length;

  Future<void> load() async {
    _items = await _store.load();
    final prefs = await SharedPreferences.getInstance();
    _masterVolume = prefs.getDouble('soundboard_volume') ?? 1;
    _loaded = true;
    notifyListeners();
  }

  AudioPlayer _playerFor(SoundItem sound) {
    return _players.putIfAbsent(sound.id, () {
      final player = AudioPlayer();
      player.onPlayerStateChanged.listen((state) {
        final changed = state == PlayerState.playing ? _playing.add(sound.id) : _playing.remove(sound.id);
        if (changed) notifyListeners();
      });
      return player;
    });
  }

  /// Lance le son (depuis le début s'il était déjà en cours). Renvoie `false`
  /// si la lecture a échoué (fichier déplacé ou supprimé…).
  Future<bool> play(SoundItem sound) async {
    final player = _playerFor(sound);
    try {
      await player.stop();
      await player.setReleaseMode(sound.loop ? ReleaseMode.loop : ReleaseMode.stop);
      await player.setVolume((sound.volume * _masterVolume).clamp(0.0, 1.0));
      await player.play(DeviceFileSource(sound.path));
      return true;
    } catch (e) {
      debugPrint('Lecture impossible (${sound.path}) : $e');
      return false;
    }
  }

  Future<void> stop(SoundItem sound) async => _players[sound.id]?.stop();

  Future<void> stopAll() async {
    await Future.wait(_players.values.map((p) => p.stop()));
  }

  Future<void> setMasterVolume(double value, {bool persist = false}) async {
    _masterVolume = value;
    notifyListeners();
    for (final sound in _items) {
      _players[sound.id]?.setVolume((sound.volume * value).clamp(0.0, 1.0));
    }
    if (persist) await (await SharedPreferences.getInstance()).setDouble('soundboard_volume', value);
  }

  Future<void> _persist() => _store.save(_items);

  Future<void> save(SoundItem sound) async {
    final index = _items.indexWhere((s) => s.id == sound.id);
    if (index >= 0) {
      if (_items[index].path != sound.path) {
        await _players.remove(sound.id)?.dispose();
        _playing.remove(sound.id);
      }
      _items[index] = sound;
    } else {
      _items.add(sound);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> remove(SoundItem sound) async {
    await _players.remove(sound.id)?.dispose();
    _playing.remove(sound.id);
    _items.removeWhere((s) => s.id == sound.id);
    notifyListeners();
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    _items.insert(newIndex, _items.removeAt(oldIndex));
    notifyListeners();
    await _persist();
  }

  @override
  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    super.dispose();
  }
}
