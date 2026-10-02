import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/thumbnail.dart';
import '../subscription.dart';

/// Formulaire de création / modification d'un abonnement.
class SubscriptionForm extends StatefulWidget {
  final Subscription? initial;
  const SubscriptionForm({super.key, this.initial});

  @override
  State<SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends State<SubscriptionForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _price = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.price.toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _note = TextEditingController(text: widget.initial?.description ?? '');
  late String? _imagePath = widget.initial?.imagePath;
  late BillingCycle _cycle = widget.initial?.cycle ?? BillingCycle.monthly;
  late SubscriptionCategory _category = widget.initial?.category ?? SubscriptionCategory.streaming;
  late DateTime? _nextPayment = widget.initial?.nextPayment();

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  void _applyTemplate(SubscriptionTemplate t) {
    Haptics.selection();
    setState(() {
      _name.text = t.name;
      _imagePath = t.image;
      _category = t.category;
    });
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (image != null) setState(() => _imagePath = image.path);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _nextPayment ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      helpText: 'Date du prochain prélèvement',
    );
    if (date != null) setState(() => _nextPayment = date);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      Haptics.medium();
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
      context,
      Subscription(
        id: widget.initial?.id ?? newId(),
        name: _name.text.trim(),
        price: parsePrice(_price.text)!,
        cycle: _cycle,
        category: _category,
        billingDate: _nextPayment,
        description: note.isEmpty ? null : note,
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
                itemCount: subscriptionTemplates.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final t = subscriptionTemplates[i];
                  return ActionChip(
                    avatar: Thumbnail(path: t.image, fallbackText: t.name, size: 20, radius: 5, fit: BoxFit.contain),
                    label: Text(t.name),
                    onPressed: () => _applyTemplate(t),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Row(
            children: [
              Tooltip(
                message: 'Choisir un logo',
                child: InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ListenableBuilder(
                        listenable: _name,
                        builder: (context, _) => Thumbnail(
                          path: _imagePath,
                          fallbackText: _name.text.isEmpty ? null : _name.text,
                          fallbackIcon: Icons.add_photo_alternate_outlined,
                          fallbackColor: _category.color,
                          size: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surfaceHigh, width: 2),
                          ),
                          child: Icon(Icons.edit_rounded, size: 12, color: theme.colorScheme.onPrimary),
                        ),
                      ),
                    ],
                  ),
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
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
              labelText: 'Montant',
              hintText: '12,99',
              suffixText: '€ / ${_cycle.unit}',
            ),
            validator: (v) {
              final price = parsePrice(v ?? '');
              if (price == null) return 'Montant invalide';
              if (price < 0) return 'Le montant doit être positif';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<BillingCycle>(
            segments: [
              for (final c in BillingCycle.values) ButtonSegment(value: c, label: Text(c.label)),
            ],
            selected: {_cycle},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              Haptics.selection();
              setState(() => _cycle = s.first);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('CATÉGORIE', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final c in SubscriptionCategory.values)
                ChoiceChip(
                  avatar: Icon(c.icon, size: 16, color: c.color),
                  label: Text(c.label),
                  selected: _category == c,
                  showCheckmark: false,
                  onSelected: (_) {
                    Haptics.selection();
                    setState(() => _category = c);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Prochain prélèvement
          Material(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.event_repeat_rounded, color: AppColors.textTertiary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prochain prélèvement', style: theme.textTheme.bodySmall),
                          Text(
                            _nextPayment == null ? 'Non renseigné' : formatLongDate(_nextPayment!),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: _nextPayment == null ? AppColors.textTertiary : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_nextPayment != null)
                      IconButton(
                        tooltip: 'Retirer la date',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _nextPayment = null),
                      )
                    else
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (optionnel)',
              hintText: 'Forfait famille, partagé avec…',
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
