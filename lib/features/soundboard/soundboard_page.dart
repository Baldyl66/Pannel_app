import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import 'soundboard_controller.dart';
import 'widgets/buzzer.dart';
import 'widgets/sound_form.dart';

class SoundboardPage extends StatefulWidget {
  const SoundboardPage({super.key});

  @override
  State<SoundboardPage> createState() => _SoundboardPageState();
}

class _SoundboardPageState extends State<SoundboardPage> {
  bool _reordering = false;

  SoundboardController get _controller => context.app.soundboard;

  Future<void> _play(SoundItem sound) async {
    Haptics.light();
    final c = _controller;
    // Un son en boucle se coupe d'un second appui.
    if (sound.loop && c.isPlaying(sound.id)) {
      await c.stop(sound);
      return;
    }
    final ok = await c.play(sound);
    if (!ok && mounted) {
      final missing = !File(sound.path).existsSync();
      showAppSnackBar(
        context,
        missing ? 'Fichier introuvable : modifiez le son pour en choisir un autre.' : 'Lecture impossible',
        isError: true,
        actionLabel: 'Modifier',
        onAction: () => _openForm(sound),
      );
    }
  }

  Future<void> _openForm([SoundItem? existing]) async {
    final result = await showAppSheet<SoundItem>(
      context,
      title: existing == null ? 'Nouveau son' : 'Modifier le son',
      builder: (_) => SoundForm(initial: existing),
    );
    if (result != null) await _controller.save(result);
  }

  Future<void> _delete(SoundItem sound) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer « ${sound.name} » ?',
      message: 'Le bouton sera retiré de la soundboard. Le fichier audio reste sur votre appareil.',
      confirmLabel: 'Supprimer',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (confirmed) await _controller.remove(sound);
  }

  Future<void> _showActions(SoundItem sound) async {
    final action = await showActionSheet<String>(
      context,
      title: sound.name,
      subtitle: sound.loop ? 'Lecture en boucle' : null,
      leading: SizedBox.square(dimension: 40, child: Buzzer(sound: sound, onTap: () {})),
      actions: const [
        SheetAction(value: 'edit', label: 'Modifier', icon: Icons.edit_outlined),
        SheetAction(value: 'delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (!mounted) return;
    if (action == 'edit') _openForm(sound);
    if (action == 'delete') _delete(sound);
  }

  void _showVolume() {
    showAppSheet<void>(
      context,
      title: 'Volume général',
      subtitle: 'S\'applique à tous les boutons',
      builder: (_) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Row(
          children: [
            const Icon(Icons.volume_mute_rounded),
            Expanded(
              child: Slider(
                value: _controller.masterVolume,
                onChanged: (v) => _controller.setMasterVolume(v),
                onChangeEnd: (v) => _controller.setMasterVolume(v, persist: true),
              ),
            ),
            const Icon(Icons.volume_up_rounded),
            SizedBox(
              width: 48,
              child: Text(
                '${(_controller.masterVolume * 100).round()} %',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        if (_reordering && c.count < 2) _reordering = false;
        final playing = c.playingCount;
        return Stack(
          children: [
            AppPage(
              title: _reordering ? 'Réorganiser' : 'Sons',
              overline: c.isEmpty ? 'Soundboard' : '${c.count} bouton${c.count > 1 ? 's' : ''} · appui long pour modifier',
              inShell: true,
              actions: [
                if (!c.isEmpty && !_reordering)
                  IconButton(
                    tooltip: 'Volume général',
                    icon: Icon(c.masterVolume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                    onPressed: _showVolume,
                  ),
                if (c.count > 1)
                  _reordering
                      ? TextButton(onPressed: () => setState(() => _reordering = false), child: const Text('Terminé'))
                      : IconButton(
                          tooltip: 'Réorganiser',
                          icon: const Icon(Icons.swap_vert_rounded),
                          onPressed: () => setState(() => _reordering = true),
                        ),
              ],
              floatingActionButton: c.isEmpty || _reordering || playing > 0
                  ? null
                  : FloatingActionButton(
                      heroTag: null,
                      tooltip: 'Ajouter un son',
                      onPressed: () => _openForm(),
                      child: const Icon(Icons.add_rounded),
                    ),
              slivers: _buildSlivers(c),
            ),
            // Bouton « Tout arrêter » quand des sons jouent.
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: Center(
                child: AnimatedSlide(
                  offset: playing > 0 ? Offset.zero : const Offset(0, 2),
                  duration: AppDurations.medium,
                  curve: AppCurves.standard,
                  child: AnimatedOpacity(
                    opacity: playing > 0 ? 1 : 0,
                    duration: AppDurations.medium,
                    child: FilledButton.icon(
                      onPressed: playing > 0
                          ? () {
                              Haptics.medium();
                              c.stopAll();
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      ),
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(playing > 1 ? 'Tout arrêter ($playing)' : 'Arrêter'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildSlivers(SoundboardController c) {
    if (!c.isLoaded) return const [SliverToBoxAdapter(child: SizedBox.shrink())];
    if (c.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.graphic_eq_rounded,
            title: 'Votre soundboard',
            message: 'Transformez vos MP3, WAV ou OGG en gros boutons colorés à déclencher d\'une pression.',
            actionLabel: 'Ajouter un son',
            onAction: () => _openForm(),
          ),
        ),
      ];
    }

    final items = c.all;
    if (_reordering) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverReorderableList(
            itemCount: items.length,
            onReorderStart: (_) => Haptics.medium(),
            onReorderItem: c.reorder,
            itemBuilder: (context, i) {
              final sound = items[i];
              return Padding(
                key: ValueKey(sound.id),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      IconBadge(icon: Icon(sound.iconData), color: sound.color, circle: true, solid: true),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(sound.name, style: Theme.of(context).textTheme.titleSmall)),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(padding: EdgeInsets.all(AppSpacing.sm), child: Icon(Icons.drag_indicator_rounded)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 128,
            crossAxisSpacing: AppSpacing.xl,
            mainAxisSpacing: AppSpacing.xl,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => Buzzer(
            sound: items[i],
            isPlaying: c.isPlaying(items[i].id),
            onTap: () => _play(items[i]),
            onLongPress: () => _showActions(items[i]),
          ),
        ),
      ),
    ];
  }
}
