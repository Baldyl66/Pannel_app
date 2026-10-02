import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/local_store.dart';
import '../../data/models/models.dart';
import '../widgets/common/app_dialogs.dart';
import '../widgets/common/color_swatch_picker.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_header.dart';

final _store = JsonListStore<SoundItem>(
  key: 'soundboard_items',
  fromJson: SoundItem.fromJson,
  toJson: (s) => s.toJson(),
);

class SoundboardTab extends StatefulWidget {
  const SoundboardTab({super.key});

  @override
  State<SoundboardTab> createState() => _SoundboardTabState();
}

class _SoundboardTabState extends State<SoundboardTab> {
  List<SoundItem> _sounds = [];
  bool _isLoading = true;
  final Map<String, AudioPlayer> _players = {};
  final Set<String> _playing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _store.load();
    if (!mounted) return;
    setState(() {
      _sounds = items;
      _isLoading = false;
    });
  }

  Future<void> _persist() => _store.save(_sounds);

  AudioPlayer _playerFor(SoundItem sound) {
    return _players.putIfAbsent(sound.id, () {
      final player = AudioPlayer();
      player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() {
          if (state == PlayerState.playing) {
            _playing.add(sound.id);
          } else {
            _playing.remove(sound.id);
          }
        });
      });
      return player;
    });
  }

  Future<void> _play(SoundItem sound) async {
    HapticFeedback.lightImpact();
    final player = _playerFor(sound);
    try {
      // Relance depuis le début si le son est déjà en cours.
      await player.stop();
      await player.play(DeviceFileSource(sound.path));
    } catch (e) {
      if (!mounted) return;
      final missing = !File(sound.path).existsSync();
      showAppSnackBar(
        context,
        missing ? 'Fichier introuvable : modifiez le son pour en choisir un autre.' : 'Lecture impossible',
        isError: true,
      );
    }
  }

  Future<void> _stopAll() async {
    HapticFeedback.mediumImpact();
    await Future.wait(_players.values.map((p) => p.stop()));
  }

  Future<void> _openForm([SoundItem? existing]) async {
    final result = await showAppSheet<SoundItem>(
      context,
      title: existing == null ? 'Nouveau son' : 'Modifier le son',
      builder: (_) => _SoundForm(initial: existing),
    );
    if (result == null) return;
    setState(() {
      final index = _sounds.indexWhere((s) => s.id == result.id);
      if (index >= 0) {
        if (_sounds[index].path != result.path) _players.remove(result.id)?.dispose();
        _sounds[index] = result;
      } else {
        _sounds.add(result);
      }
    });
    await _persist();
  }

  Future<void> _delete(SoundItem sound) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer le son ?',
      message: '« ${sound.name} » sera retiré de la soundboard. Le fichier audio n\'est pas supprimé.',
      confirmLabel: 'Supprimer',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!confirmed) return;
    await _players.remove(sound.id)?.dispose();
    setState(() {
      _sounds.removeWhere((s) => s.id == sound.id);
      _playing.remove(sound.id);
    });
    await _persist();
  }

  Future<void> _showActions(SoundItem sound) async {
    HapticFeedback.mediumImpact();
    final action = await showActionSheet<String>(
      context,
      title: sound.name,
      actions: const [
        SheetAction(value: 'edit', label: 'Modifier', icon: Icons.edit_outlined),
        SheetAction(value: 'delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (action == 'edit') _openForm(sound);
    if (action == 'delete') _delete(sound);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _sounds.isEmpty
          ? null
          : FloatingActionButton(
              heroTag: null,
              tooltip: 'Ajouter un son',
              onPressed: () => _openForm(),
              child: const Icon(Icons.add_rounded),
            ),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          maxWidth: 960,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Soundboard',
                subtitle: _sounds.isEmpty ? 'Sons' : 'Appui long pour modifier',
                actions: [
                  AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: _playing.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton.filledTonal(
                            key: const ValueKey('stop'),
                            tooltip: 'Tout arrêter',
                            icon: const Icon(Icons.stop_rounded),
                            onPressed: _stopAll,
                          ),
                  ),
                ],
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_sounds.isEmpty) {
      return EmptyState(
        icon: Icons.graphic_eq_rounded,
        title: 'Aucun son',
        message: 'Ajoutez des fichiers MP3, WAV ou OGG pour les déclencher d\'une simple pression.',
        actionLabel: 'Ajouter un son',
        onAction: () => _openForm(),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        crossAxisSpacing: AppSpacing.xl,
        mainAxisSpacing: AppSpacing.xl,
      ),
      itemCount: _sounds.length,
      itemBuilder: (context, index) {
        final sound = _sounds[index];
        return Buzzer3DWidget(
          sound: sound,
          isPlaying: _playing.contains(sound.id),
          onTap: () => _play(sound),
          onLongPress: () => _showActions(sound),
        );
      },
    );
  }
}

class _SoundForm extends StatefulWidget {
  final SoundItem? initial;
  const _SoundForm({this.initial});

  @override
  State<_SoundForm> createState() => _SoundFormState();
}

class _SoundFormState extends State<_SoundForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late String? _path = widget.initial?.path;
  late Color _color = widget.initial != null ? Color(widget.initial!.colorValue) : AppColors.swatches[5];
  bool _missingFile = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(label: 'Audio', extensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return;
    setState(() {
      _path = file.path;
      _missingFile = false;
      if (_name.text.trim().isEmpty) {
        // Propose le nom du fichier sans extension.
        final base = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
        _name.text = base;
      }
    });
  }

  void _submit() {
    final validForm = _formKey.currentState!.validate();
    setState(() => _missingFile = _path == null);
    if (!validForm || _path == null) return;
    Navigator.pop(
      context,
      SoundItem(
        id: widget.initial?.id ?? newId(),
        name: _name.text.trim(),
        path: _path!,
        colorValue: _color.toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = _path?.split(RegExp(r'[\\/]')).last;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 110,
              height: 110,
              child: Buzzer3DWidget(
                sound: SoundItem(
                  id: 'preview',
                  name: _name.text.isEmpty ? 'Aperçu' : _name.text,
                  path: '',
                  colorValue: _color.toARGB32(),
                ),
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: _pickFile,
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              side: BorderSide(color: _missingFile ? AppColors.danger : AppColors.borderStrong),
            ),
            icon: Icon(
              _path == null ? Icons.audio_file_outlined : Icons.check_circle_rounded,
              color: _path == null ? null : AppColors.success,
            ),
            label: Text(
              fileName ?? 'Choisir un fichier audio',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_missingFile)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.lg),
              child: Text('Fichier requis', style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _name,
            maxLength: 24,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nom du bouton',
              hintText: 'Applaudissements',
              prefixIcon: Icon(Icons.label_outline_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('COULEUR', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.md),
          ColorSwatchPicker(selected: _color, onChanged: (c) => setState(() => _color = c)),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.initial == null ? 'Créer le bouton' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}

/// Gros bouton « buzzer » avec effet d'enfoncement.
class Buzzer3DWidget extends StatefulWidget {
  final SoundItem sound;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isPlaying;

  const Buzzer3DWidget({
    super.key,
    required this.sound,
    required this.onTap,
    required this.onLongPress,
    this.isPlaying = false,
  });

  @override
  State<Buzzer3DWidget> createState() => _Buzzer3DWidgetState();
}

class _Buzzer3DWidgetState extends State<Buzzer3DWidget> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.sound.colorValue);
    final hsl = HSLColor.fromColor(color);
    final darkColor = hsl.withLightness((hsl.lightness * 0.45).clamp(0.0, 1.0)).toColor();
    final lightColor = hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();

    return Semantics(
      button: true,
      label: widget.sound.name,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) {
          _setPressed(false);
          widget.onTap();
        },
        onTapCancel: () => _setPressed(false),
        onLongPress: () {
          _setPressed(false);
          widget.onLongPress();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Socle du buzzer (profondeur 3D) + halo pendant la lecture.
            Positioned.fill(
              top: 6,
              child: AnimatedContainer(
                duration: AppDurations.medium,
                decoration: BoxDecoration(
                  color: darkColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: widget.isPlaying ? 0.7 : 0.25),
                      blurRadius: widget.isPlaying ? 28 : 12,
                      spreadRadius: widget.isPlaying ? 2 : 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOutQuad,
              top: _isPressed ? 6 : 0,
              bottom: _isPressed ? 0 : 6,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [lightColor, color],
                    center: const Alignment(-0.35, -0.35),
                    radius: 0.9,
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isPlaying ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(height: 4),
                    // Les mots longs sont réduits plutôt que coupés en deux.
                    LayoutBuilder(
                      builder: (context, constraints) => FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: constraints.maxWidth * 1.4,
                          child: Text(
                            widget.sound.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1))],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
