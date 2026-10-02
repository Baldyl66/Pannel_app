import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'settings_page.dart';

class SoundItem {
  final String id;
  final String name;
  final String path;
  final int colorValue;

  SoundItem({
    required this.id,
    required this.name,
    required this.path,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'colorValue': colorValue,
  };

  factory SoundItem.fromJson(Map<String, dynamic> json) => SoundItem(
    id: json['id'],
    name: json['name'],
    path: json['path'],
    colorValue: json['colorValue'],
  );
}

class SoundboardTab extends StatefulWidget {
  const SoundboardTab({super.key});

  @override
  State<SoundboardTab> createState() => _SoundboardTabState();
}

class _SoundboardTabState extends State<SoundboardTab> {
  List<SoundItem> _sounds = [];
  bool _isLoading = true;
  final Map<String, AudioPlayer> _players = {};

  final List<Color> _availableColors = [
    const Color(0xFFF44336), // Red
    const Color(0xFFE91E63), // Pink
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF3F51B5), // Indigo
    const Color(0xFF2196F3), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFF9800), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('soundboard_items');
    if (data != null) {
      final List<dynamic> decoded = json.decode(data);
      _sounds = decoded.map((e) => SoundItem.fromJson(e)).toList();
      
      // Initialiser un lecteur audio pour chaque son
      for (var sound in _sounds) {
        _players[sound.id] = AudioPlayer();
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_sounds.map((e) => e.toJson()).toList());
    await prefs.setString('soundboard_items', encoded);
  }

  Future<void> _playSound(SoundItem sound) async {
    final player = _players[sound.id];
    if (player != null) {
      // Arrête le son s'il est déjà en cours et le relance
      if (player.state == PlayerState.playing) {
        await player.stop();
      }
      await player.play(DeviceFileSource(sound.path));
    }
  }

  Future<void> _deleteSound(String id) async {
    final sound = _sounds.firstWhere((s) => s.id == id);
    
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: const Color(0xFF151515),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Supprimer le son', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text('Voulez-vous vraiment supprimer "${sound.name}" ?', style: const TextStyle(color: Colors.white70)),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      final player = _players.remove(id);
      await player?.dispose();
      setState(() {
        _sounds.removeWhere((s) => s.id == id);
      });
      await _saveSounds();
    }
  }

  Future<void> _showAddSoundDialog() async {
    String name = "";
    String? path;
    Color selectedColor = _availableColors.first;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151515),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
              ),
              titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
              title: const Text(
                'Ajouter un Son',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                textAlign: TextAlign.center,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                        hintText: 'Nom du bouton (ex: Clap)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        const XTypeGroup typeGroup = XTypeGroup(
                          label: 'Audio',
                          extensions: <String>['mp3', 'wav', 'ogg'],
                        );
                        final XFile? file = await openFile(
                          acceptedTypeGroups: <XTypeGroup>[typeGroup],
                        );
                        if (file != null) {
                          setDialogState(() {
                            path = file.path;
                          });
                        }
                      },
                      icon: Icon(
                        path == null ? Icons.audio_file_outlined : Icons.check_circle,
                        color: path == null ? Colors.white54 : Colors.greenAccent,
                      ),
                      label: Text(
                        path == null ? 'Choisir un fichier audio' : 'Fichier sélectionné',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Couleur du bouton',
                      style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: _availableColors.map((c) {
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == c ? Colors.white : Colors.transparent,
                                width: selectedColor == c ? 3 : 0,
                              ),
                              boxShadow: selectedColor == c
                                  ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 16),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    if (name.isNotEmpty && path != null) {
                      Navigator.pop(context, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez entrer un nom et choisir un fichier.')),
                      );
                    }
                  },
                  child: const Text('Créer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            );
          },
        );
      },
    ).then((confirmed) async {
      if (confirmed == true && path != null) {
        final newId = DateTime.now().millisecondsSinceEpoch.toString();
        final newSound = SoundItem(
          id: newId,
          name: name,
          path: path!,
          colorValue: selectedColor.toARGB32(),
        );
        setState(() {
          _sounds.add(newSound);
          _players[newId] = AudioPlayer();
        });
        await _saveSounds();
      }
    });
  }

  @override
  void dispose() {
    for (var player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72.0),
        child: FloatingActionButton(
          onPressed: _showAddSoundDialog,
          backgroundColor: Colors.white,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
          // En-tête centré avec paramètres
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Équilibre avec le bouton à droite
                const Text(
                  'Soundboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white54),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _sounds.isEmpty
                ? const Center(
                    child: Text(
                      "Aucun son enregistré.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _sounds.length,
                    itemBuilder: (context, index) {
                      final sound = _sounds[index];
                      return Buzzer3DWidget(
                        sound: sound,
                        onTap: () => _playSound(sound),
                        onLongPress: () => _deleteSound(sound.id),
                      );
                    },
                  ),
          ),

        ],
      ),
    ),
    );
  }
}

class Buzzer3DWidget extends StatefulWidget {
  final SoundItem sound;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const Buzzer3DWidget({
    super.key,
    required this.sound,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<Buzzer3DWidget> createState() => _Buzzer3DWidgetState();
}

class _Buzzer3DWidgetState extends State<Buzzer3DWidget> {
  bool _isPressed = false;

  void _handleTapDown(_) => setState(() => _isPressed = true);
  
  void _handleTapUp(_) {
    setState(() => _isPressed = false);
    widget.onTap();
  }
  
  void _handleTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.sound.colorValue);
    final darkColor = HSLColor.fromColor(color).withLightness(0.2).toColor();

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Base du buzzer (profondeur 3D)
          Container(
            decoration: BoxDecoration(
              color: darkColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          // Le bouton principal animé
          AnimatedPositioned(
            duration: const Duration(milliseconds: 60),
            curve: Curves.easeOutQuad,
            top: _isPressed ? 6 : 0,
            bottom: _isPressed ? 0 : 6,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withValues(alpha: 0.7), color],
                  center: const Alignment(-0.3, -0.3),
                  radius: 0.8,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.volume_up, color: Colors.white, size: 28),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      widget.sound.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))
                        ]
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
