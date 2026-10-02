import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/thumbnail.dart';
import '../links_controller.dart';

/// Formulaire de création / modification d'un lien.
class LinkForm extends StatefulWidget {
  final LinkItem? initial;
  final List<String> groups;
  const LinkForm({super.key, this.initial, this.groups = const []});

  @override
  State<LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends State<LinkForm> {
  final _formKey = GlobalKey<FormState>();
  late final _url = TextEditingController(text: widget.initial?.url ?? '');
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _group = TextEditingController(text: widget.initial?.group ?? '');
  late String? _image = widget.initial?.hasImage == true ? widget.initial!.imageUrl : null;

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _group.dispose();
    super.dispose();
  }

  bool get _urlValid {
    final uri = Uri.tryParse(normalizeUrl(_url.text));
    return uri != null && uri.host.contains('.');
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1080);
    if (image != null) setState(() => _image = image.path);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      Haptics.medium();
      return;
    }
    final url = normalizeUrl(_url.text);
    final title = _title.text.trim();
    final group = _group.text.trim();
    Navigator.pop(
      context,
      LinkItem(
        id: widget.initial?.id,
        title: title.isEmpty ? capitalize(displayHost(url).split('.').first) : title,
        url: url,
        imageUrl: _image ?? '',
        group: group.isEmpty ? null : group,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _url,
            autofocus: widget.initial == null,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Adresse du site',
              hintText: 'youtube.com',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10),
                child: _urlValid
                    ? Thumbnail(path: faviconUrl(_url.text), fallbackIcon: Icons.public_rounded, size: 24, radius: 6, background: Colors.white)
                    : const Icon(Icons.link_rounded),
              ),
            ),
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return 'Adresse requise';
              if (!_urlValid) return 'Adresse invalide';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nom (optionnel)',
              hintText: 'Par défaut : le nom du site',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _group,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Groupe (optionnel)',
              hintText: 'Travail, Divertissement…',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
          ),
          if (widget.groups.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final g in widget.groups)
                  ChoiceChip(
                    label: Text(g),
                    selected: _group.text.trim() == g,
                    showCheckmark: false,
                    onSelected: (_) {
                      Haptics.selection();
                      setState(() => _group.text = _group.text.trim() == g ? '' : g);
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text('IMAGE DE FOND (OPTIONNEL)', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _pickImage,
              child: SizedBox(
                height: 96,
                child: _image == null
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: AppColors.textTertiary),
                          SizedBox(width: AppSpacing.sm),
                          Text('Choisir dans la galerie', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(image: imageProviderFor(_image!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton.filledTonal(
                              tooltip: 'Retirer l\'image',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() => _image = null),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.initial == null ? 'Ajouter le lien' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}
