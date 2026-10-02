import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/color_picker.dart';
import '../soundboard_controller.dart';
import 'buzzer.dart';

/// Formulaire de création / modification d'un son.
class SoundForm extends StatefulWidget {
  final SoundItem? initial;
  const SoundForm({super.key, this.initial});

  @override
  State<SoundForm> createState() => _SoundFormState();
}

class _SoundFormState extends State<SoundForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late String? _path = widget.initial?.path;
  late Color _color = widget.initial?.color ?? AppColors.swatches[1];
  late String _icon = widget.initial?.icon ?? 'volume';
  late double _volume = widget.initial?.volume ?? 1;
  late bool _loop = widget.initial?.loop ?? false;
  bool _missingFile = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(label: 'Audio', extensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac']);
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return;
    setState(() {
      _path = file.path;
      _missingFile = false;
      if (_name.text.trim().isEmpty) {
        final base = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
        _name.text = base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
      }
    });
  }

  void _submit() {
    final validForm = _formKey.currentState!.validate();
    setState(() => _missingFile = _path == null);
    if (!validForm || _path == null) {
      Haptics.medium();
      return;
    }
    Navigator.pop(
      context,
      SoundItem(
        id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        path: _path!,
        colorValue: _color.toARGB32(),
        icon: _icon,
        volume: _volume,
        loop: _loop,
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
            child: SizedBox.square(
              dimension: 120,
              child: ListenableBuilder(
                listenable: _name,
                builder: (context, _) => Buzzer(
                  sound: SoundItem(
                    id: 'preview',
                    name: _name.text.isEmpty ? 'Aperçu' : _name.text,
                    path: '',
                    colorValue: _color.toARGB32(),
                    icon: _icon,
                    loop: _loop,
                  ),
                  onTap: Haptics.light,
                ),
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
            label: Text(fileName ?? 'Choisir un fichier audio', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (_missingFile)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.lg),
              child: Text('Choisissez un fichier audio', style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _name,
            maxLength: 24,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nom du bouton', hintText: 'Applaudissements'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('ICÔNE', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final entry in soundIcons.entries)
                _IconChoice(
                  icon: entry.value,
                  selected: _icon == entry.key,
                  color: _color,
                  onTap: () {
                    Haptics.selection();
                    setState(() => _icon = entry.key);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('COULEUR', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.md),
          ColorSwatchPicker(selected: _color, size: 34, onChanged: (c) => setState(() => _color = c)),
          const SizedBox(height: AppSpacing.xl),
          AppSection(
            margin: EdgeInsets.zero,
            children: [
              AppTile(
                icon: Icons.volume_up_rounded,
                iconColor: _color,
                title: 'Volume',
                value: '${(_volume * 100).round()} %',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
                child: Slider(value: _volume, onChanged: (v) => setState(() => _volume = v)),
              ),
              AppSwitchTile(
                icon: Icons.repeat_rounded,
                iconColor: _color,
                title: 'Lecture en boucle',
                subtitle: 'Rejoue jusqu\'à ce que vous l\'arrêtiez',
                value: _loop,
                onChanged: (v) => setState(() => _loop = v),
              ),
            ],
          ),
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

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _IconChoice({required this.icon, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Icon(icon, size: 22, color: selected ? color : AppColors.textSecondary),
      ),
    );
  }
}
