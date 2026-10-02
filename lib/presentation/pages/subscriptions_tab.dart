import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/local_store.dart';
import '../../data/models/models.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_dialogs.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_header.dart';
import '../widgets/common/thumbnail.dart';

final _store = JsonListStore<Subscription>(
  key: 'saved_subscriptions',
  fromJson: Subscription.fromJson,
  toJson: (s) => s.toJson(),
);

class _Template {
  final String name;
  final String? image;
  const _Template(this.name, this.image);
}

const _templates = [
  _Template('Spotify', 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/spotify.png'),
  _Template('Netflix', 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/netflix.png'),
  _Template('Amazon Prime', 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/amazon.png'),
  _Template('YouTube', 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/youtube.png'),
  _Template('Discord Nitro', 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/discord.png'),
  _Template('Snapchat', 'https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/snapchat.png'),
  _Template('Railway', 'https://avatars.githubusercontent.com/u/74384995'),
];

class SubscriptionsTab extends StatefulWidget {
  const SubscriptionsTab({super.key});

  @override
  State<SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<SubscriptionsTab> {
  List<Subscription> _subscriptions = [];
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
      _subscriptions = items;
      _isLoading = false;
    });
  }

  Future<void> _persist() => _store.save(_subscriptions);

  List<Subscription> get _sorted => [..._subscriptions]..sort((a, b) => b.price.compareTo(a.price));

  double get _monthlyTotal => _subscriptions.fold(0.0, (sum, s) => sum + s.price);

  Future<void> _openForm([Subscription? existing]) async {
    final result = await showAppSheet<Subscription>(
      context,
      title: existing == null ? 'Nouvel abonnement' : 'Modifier',
      builder: (_) => _SubscriptionForm(initial: existing),
    );
    if (result == null) return;
    setState(() {
      final index = _subscriptions.indexWhere((s) => s.id == result.id);
      if (index >= 0) {
        _subscriptions[index] = result;
      } else {
        _subscriptions.add(result);
      }
    });
    await _persist();
  }

  Future<void> _delete(Subscription sub) async {
    final index = _subscriptions.indexWhere((s) => s.id == sub.id);
    if (index < 0) return;
    setState(() => _subscriptions.removeAt(index));
    await _persist();
    if (!mounted) return;
    showAppSnackBar(
      context,
      '« ${sub.name} » supprimé',
      actionLabel: 'Annuler',
      onAction: () {
        setState(() => _subscriptions.insert(index.clamp(0, _subscriptions.length), sub));
        _persist();
      },
    );
  }

  Future<void> _showActions(Subscription sub) async {
    HapticFeedback.mediumImpact();
    final action = await showActionSheet<String>(
      context,
      title: sub.name,
      subtitle: '${formatEuro(sub.price)} / mois',
      actions: const [
        SheetAction(value: 'edit', label: 'Modifier', icon: Icons.edit_outlined),
        SheetAction(value: 'delete', label: 'Supprimer', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (action == 'edit') _openForm(sub);
    if (action == 'delete') _delete(sub);
  }

  @override
  Widget build(BuildContext context) {
    final count = _subscriptions.length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: count == 0
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter'),
            ),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Dépenses',
                subtitle: count == 0 ? 'Abonnements' : '$count abonnement${count > 1 ? 's' : ''} actif${count > 1 ? 's' : ''}',
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(children: [SkeletonCard(height: 140), SizedBox(height: AppSpacing.md), SkeletonCard(height: 76)]),
      );
    }
    if (_subscriptions.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Aucun abonnement',
        message: 'Ajoutez vos abonnements pour suivre ce qu\'ils vous coûtent chaque mois et chaque année.',
        actionLabel: 'Ajouter un abonnement',
        onAction: () => _openForm(),
      );
    }

    final sorted = _sorted;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 96),
      children: [
        _SummaryCard(monthly: _monthlyTotal, top: sorted.first),
        const SectionLabel('Abonnements', trailing: Text('Balayez pour supprimer', style: TextStyle(fontSize: 11, color: AppColors.textTertiary))),
        for (final sub in sorted) ...[
          Dismissible(
            key: ValueKey(sub.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            ),
            onDismissed: (_) => _delete(sub),
            child: _SubscriptionTile(
              sub: sub,
              share: _monthlyTotal == 0 ? 0 : sub.price / _monthlyTotal,
              onTap: () => _openForm(sub),
              onLongPress: () => _showActions(sub),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double monthly;
  final Subscription top;
  const _SummaryCard({required this.monthly, required this.top});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent.withValues(alpha: 0.28), AppColors.surface],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total mensuel', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatEuro(monthly),
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 40),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Par an', value: formatEuro(monthly * 12))),
              Container(width: 1, height: 32, color: AppColors.border),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: _Stat(label: 'Le plus cher', value: top.name)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final Subscription sub;
  final double share;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SubscriptionTile({required this.sub, required this.share, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Thumbnail(
                path: sub.imagePath,
                fallbackIcon: Icons.receipt_long_rounded,
                fit: BoxFit.contain,
                background: sub.imagePath == null ? null : Colors.transparent,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (sub.description?.isNotEmpty ?? false)
                      Text(
                        sub.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatEuro(sub.price), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text('/ mois', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Part de cet abonnement dans le total mensuel.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: share, minHeight: 3),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionForm extends StatefulWidget {
  final Subscription? initial;
  const _SubscriptionForm({this.initial});

  @override
  State<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends State<_SubscriptionForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _price = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.price.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late String? _imagePath = widget.initial?.imagePath;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  void _applyTemplate(_Template t) {
    HapticFeedback.selectionClick();
    setState(() {
      _name.text = t.name;
      _imagePath = t.image;
    });
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imagePath = image.path);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final description = _description.text.trim();
    Navigator.pop(
      context,
      Subscription(
        id: widget.initial?.id ?? newId(),
        name: _name.text.trim(),
        price: parsePrice(_price.text)!,
        description: description.isEmpty ? null : description,
        imagePath: _imagePath,
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
          if (widget.initial == null) ...[
            Text('SUGGESTIONS', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final t = _templates[i];
                  return ActionChip(
                    avatar: Thumbnail(path: t.image, fallbackIcon: Icons.receipt_long, size: 20, radius: 4, fit: BoxFit.contain, background: Colors.transparent),
                    label: Text(t.name),
                    onPressed: () => _applyTemplate(t),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Row(
            children: [
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Stack(
                  children: [
                    Thumbnail(
                      path: _imagePath,
                      fallbackIcon: Icons.add_photo_alternate_outlined,
                      size: 64,
                      radius: AppRadius.md,
                      fit: BoxFit.contain,
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                        child: Icon(Icons.edit, size: 12, color: theme.colorScheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nom', hintText: 'Netflix'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(
              labelText: 'Prix mensuel',
              hintText: '12,99',
              suffixText: '€',
              prefixIcon: Icon(Icons.euro_rounded),
            ),
            validator: (v) {
              final price = parsePrice(v ?? '');
              if (price == null) return 'Prix invalide';
              if (price < 0) return 'Le prix doit être positif';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Note (optionnel)',
              hintText: 'Forfait famille, renouvellement le 12…',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.initial == null ? 'Ajouter l\'abonnement' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}
