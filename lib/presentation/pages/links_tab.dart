import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/local_store.dart';
import '../../data/models/models.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_dialogs.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_header.dart';
import '../widgets/common/thumbnail.dart';

final _store = JsonListStore<LinkItem>(
  key: 'saved_links',
  fromJson: LinkItem.fromJson,
  toJson: (l) => l.toJson(),
);

String _faviconFor(String url) =>
    'https://www.google.com/s2/favicons?sz=128&domain=${Uri.encodeComponent(displayHost(url))}';

class LinksTab extends StatefulWidget {
  const LinksTab({super.key});

  @override
  State<LinksTab> createState() => _LinksTabState();
}

class _LinksTabState extends State<LinksTab> {
  List<LinkItem> _links = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _store.load();
    if (!mounted) return;
    setState(() {
      _links = items;
      _isLoading = false;
    });
  }

  Future<void> _persist() => _store.save(_links);

  Future<void> _open(LinkItem link) async {
    final uri = Uri.tryParse(normalizeUrl(link.url));
    bool opened = false;
    try {
      opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && mounted) {
      showAppSnackBar(context, 'Impossible d\'ouvrir ce lien', isError: true);
    }
  }

  Future<void> _openForm([int? index]) async {
    final result = await showAppSheet<LinkItem>(
      context,
      title: index == null ? 'Nouveau lien' : 'Modifier le lien',
      builder: (_) => _LinkForm(initial: index == null ? null : _links[index]),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _links[index] = result;
      } else {
        _links.add(result);
      }
    });
    await _persist();
  }

  Future<void> _delete(int index) async {
    final link = _links[index];
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer le lien ?',
      message: '« ${link.title} » sera retiré de vos liens rapides.',
      confirmLabel: 'Supprimer',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _links.removeAt(index));
    await _persist();
  }

  Future<void> _showActions(int index) async {
    HapticFeedback.mediumImpact();
    final link = _links[index];
    final action = await showActionSheet<String>(
      context,
      title: link.title,
      subtitle: displayHost(link.url),
      actions: const [
        SheetAction(value: 'open', label: 'Ouvrir', icon: Icons.open_in_new_rounded),
        SheetAction(value: 'copy', label: 'Copier le lien', icon: Icons.copy_rounded),
        SheetAction(value: 'edit', label: 'Modifier', icon: Icons.edit_outlined),
        SheetAction(value: 'delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'open':
        _open(link);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: link.url));
        if (mounted) showAppSnackBar(context, 'Lien copié');
      case 'edit':
        _openForm(index);
      case 'delete':
        _delete(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _links.isEmpty
          ? null
          : FloatingActionButton(
              heroTag: null,
              tooltip: 'Ajouter un lien',
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
                title: 'Liens',
                subtitle: _links.isEmpty ? 'Accès rapide' : '${_links.length} favori${_links.length > 1 ? 's' : ''}',
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
    if (_links.isEmpty) {
      return EmptyState(
        icon: Icons.bookmarks_outlined,
        title: 'Aucun lien',
        message: 'Gardez vos sites préférés à portée de main. Appui long sur un lien pour le modifier.',
        actionLabel: 'Ajouter un lien',
        onAction: () => _openForm(),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.25,
      ),
      itemCount: _links.length,
      itemBuilder: (context, index) => _LinkCard(
        link: _links[index],
        onTap: () => _open(_links[index]),
        onMore: () => _showActions(index),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final LinkItem link;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _LinkCard({required this.link, required this.onTap, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = displayHost(link.url);

    final moreButton = Align(
      alignment: Alignment.topRight,
      child: IconButton(
        tooltip: 'Options',
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.more_horiz_rounded, color: link.hasImage ? Colors.white : null),
        onPressed: onMore,
      ),
    );

    if (link.hasImage) {
      return AppCard(
        onTap: onTap,
        onLongPress: onMore,
        padding: EdgeInsets.zero,
        image: DecorationImage(
          image: imageProviderFor(link.imageUrl!),
          fit: BoxFit.cover,
          onError: (_, _) {},
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.8)],
            ),
          ),
          child: Stack(
            children: [
              moreButton,
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: _Labels(title: link.title, host: host),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(
      onTap: onTap,
      onLongPress: onMore,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, 0, AppSpacing.md),
      child: Stack(
        children: [
          moreButton,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Thumbnail(
                path: _faviconFor(link.url),
                fallbackIcon: Icons.public_rounded,
                size: 40,
                fit: BoxFit.contain,
                background: Colors.white.withValues(alpha: 0.9),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: _Labels(title: link.title, host: host, hostColor: theme.textTheme.bodyMedium?.color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Labels extends StatelessWidget {
  final String title;
  final String host;
  final Color? hostColor;
  const _Labels({required this.title, required this.host, this.hostColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          host,
          style: TextStyle(fontSize: 12, color: hostColor ?? Colors.white70),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _LinkForm extends StatefulWidget {
  final LinkItem? initial;
  const _LinkForm({this.initial});

  @override
  State<_LinkForm> createState() => _LinkFormState();
}

class _LinkFormState extends State<_LinkForm> {
  final _formKey = GlobalKey<FormState>();
  late final _url = TextEditingController(text: widget.initial?.url ?? '');
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _image = TextEditingController(text: widget.initial?.imageUrl ?? '');

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _image.text = image.path);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final url = normalizeUrl(_url.text);
    final title = _title.text.trim();
    Navigator.pop(
      context,
      LinkItem(
        title: title.isEmpty ? displayHost(url) : title,
        url: url,
        imageUrl: _image.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            decoration: const InputDecoration(
              labelText: 'Adresse',
              hintText: 'youtube.com',
              prefixIcon: Icon(Icons.link_rounded),
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Adresse requise';
              final uri = Uri.tryParse(normalizeUrl(value));
              if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return 'Adresse invalide';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Titre (optionnel)',
              hintText: 'Par défaut : le nom du site',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _image,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Image de fond (optionnel)',
              hintText: 'URL ou image de la galerie',
              prefixIcon: const Icon(Icons.image_outlined),
              suffixIcon: IconButton(
                tooltip: 'Choisir dans la galerie',
                icon: const Icon(Icons.photo_library_outlined),
                onPressed: _pickImage,
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
