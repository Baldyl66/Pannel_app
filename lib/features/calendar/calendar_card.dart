import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import 'google_calendar_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/empty_state.dart';

class CalendarCard extends StatefulWidget {
  const CalendarCard({super.key});

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  bool _isLoggedIn = false;
  bool _isLoading = true;
  bool _isFetching = false;
  List<dynamic> _events = [];
  Timer? _refreshTimer;
  DateTime _selectedDate = DateTime.now();

  bool get _isToday => DateUtils.isSameDay(_selectedDate, DateTime.now());

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _calendarService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });

    if (loggedIn) {
      await _fetchEvents();
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchEvents());
    }
  }

  Future<void> _fetchEvents() async {
    if (!_isLoggedIn) return;
    setState(() => _isFetching = true);
    final requested = _selectedDate;
    List<dynamic> events = [];
    try {
      events = await _calendarService.getEventsForDate(requested);
    } catch (e) {
      debugPrint('Erreur agenda : $e');
    }
    // Ignore une réponse arrivée après un changement de jour.
    if (!mounted || !DateUtils.isSameDay(requested, _selectedDate)) return;
    setState(() {
      _events = events;
      _isFetching = false;
    });
  }

  void _changeDay(DateTime date) {
    setState(() => _selectedDate = date);
    _fetchEvents();
  }

  Future<void> _pickDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) _changeDay(date);
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final error = await _calendarService.login();
    if (!mounted) return;
    if (error != null) {
      setState(() => _isLoading = false);
      showAppSnackBar(context, 'Connexion Google impossible : $error', isError: true);
      return;
    }
    await _checkLoginStatus();
  }

  Future<void> _openForm([Map<String, dynamic>? event]) async {
    DateTime initial;
    if (event != null) {
      final start = event['start']?['dateTime'] ?? event['start']?['date'];
      initial = start != null ? DateTime.parse(start).toLocal() : _selectedDate;
    } else {
      final now = DateTime.now();
      // Prochaine heure pleine pour un nouveau rappel.
      initial = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, now.hour + 1);
    }

    final result = await showAppSheet<_EventFormResult>(
      context,
      title: event == null ? 'Nouveau rappel' : 'Modifier l\'événement',
      builder: (_) => _EventForm(initialTitle: event?['summary'] ?? '', initialDate: initial, canDelete: event != null),
    );
    if (result == null || !mounted) return;

    setState(() => _isFetching = true);
    try {
      if (result.delete) {
        await _calendarService.deleteEvent(event!['id']);
        if (mounted) showAppSnackBar(context, 'Événement supprimé');
      } else if (event == null) {
        await _calendarService.createReminder(result.title, result.date);
        if (mounted) showAppSnackBar(context, 'Rappel ajouté à votre agenda');
      } else {
        await _calendarService.updateEvent(event['id'], result.title, result.date);
        if (mounted) showAppSnackBar(context, 'Événement mis à jour');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Opération impossible, réessayez.', isError: true);
    }
    // Affiche le jour de l'événement créé / modifié.
    if (!result.delete && mounted) _selectedDate = result.date;
    await _fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SkeletonBox(height: 180);

    if (!_isLoggedIn) {
      return ConnectServiceCard(
        icon: const Icon(Icons.event_rounded),
        brandColor: AppColors.google,
        service: 'Google Agenda',
        description: 'Vos événements du jour et rappels rapides.',
        onConnect: _login,
      );
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.event_rounded, size: 16, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Text('AGENDA', style: theme.textTheme.labelSmall),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: InkWell(
                  onTap: _pickDay,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            capitalize(DateFormat('MMMM yyyy', 'fr_FR').format(_selectedDate)),
                            style: theme.textTheme.labelMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (!_isToday)
                TextButton(
                  onPressed: () => _changeDay(DateTime.now()),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Aujourd\'hui'),
                ),
              IconButton.filledTonal(
                tooltip: 'Nouveau rappel',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _openForm(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _WeekStrip(
            selected: _selectedDate,
            onSelect: _changeDay,
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedOpacity(
            duration: AppDurations.fast,
            opacity: _isFetching ? 1 : 0,
            child: const LinearProgressIndicator(minHeight: 2),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: [
                  const Icon(Icons.wb_sunny_outlined, color: AppColors.textTertiary),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Rien de prévu', style: theme.textTheme.bodyMedium),
                ],
              ),
            )
          else
            for (final event in _events) _EventRow(event: event, accent: accent, onTap: () => _openForm(event)),
        ],
      ),
    );
  }
}

/// Pastilles des 7 jours de la semaine, avec flèches semaine précédente /
/// suivante.
class _WeekStrip extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  const _WeekStrip({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final monday = DateUtils.dateOnly(selected).subtract(Duration(days: selected.weekday - 1));
    final today = DateUtils.dateOnly(DateTime.now());

    return Row(
      children: [
        _arrow(Icons.chevron_left_rounded, 'Semaine précédente', () => onSelect(selected.subtract(const Duration(days: 7)))),
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (context) {
              final day = monday.add(Duration(days: i));
              final isSelected = DateUtils.isSameDay(day, selected);
              final isToday = DateUtils.isSameDay(day, today);
              return GestureDetector(
                onTap: () {
                  Haptics.selection();
                  onSelect(day);
                },
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E', 'fr_FR').format(day).substring(0, 1).toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected ? theme.colorScheme.onPrimary.withValues(alpha: 0.8) : AppColors.textTertiary,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.day}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isSelected ? theme.colorScheme.onPrimary : (isToday ? accent : AppColors.textPrimary),
                          fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        _arrow(Icons.chevron_right_rounded, 'Semaine suivante', () => onSelect(selected.add(const Duration(days: 7)))),
      ],
    );
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback onTap) => SizedBox(
        width: 28,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 20),
          onPressed: () {
            Haptics.selection();
            onTap();
          },
        ),
      );
}

class _EventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final Color accent;
  final VoidCallback onTap;

  const _EventRow({required this.event, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateTime = event['start']?['dateTime'] as String?;
    final time = dateTime != null ? DateFormat('HH:mm').format(DateTime.parse(dateTime).toLocal()) : 'Journée';
    final isPast = dateTime != null && DateTime.parse(dateTime).toLocal().isBefore(DateTime.now());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Opacity(
          opacity: isPast ? 0.5 : 1,
          child: Row(
            children: [
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 58,
                child: Text(
                  time,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              Expanded(
                child: Text(
                  event['summary'] ?? 'Sans titre',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventFormResult {
  final String title;
  final DateTime date;
  final bool delete;
  const _EventFormResult({required this.title, required this.date, this.delete = false});
}

class _EventForm extends StatefulWidget {
  final String initialTitle;
  final DateTime initialDate;
  final bool canDelete;

  const _EventForm({required this.initialTitle, required this.initialDate, required this.canDelete});

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initialTitle);
  late DateTime _date = widget.initialDate;
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.initialDate);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null) setState(() => _time = time);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _EventFormResult(
        title: _title.text.trim(),
        date: DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Supprimer l\'événement ?',
      message: 'Il sera aussi supprimé de votre Google Agenda.',
      confirmLabel: 'Supprimer',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (confirmed && mounted) {
      Navigator.pop(context, _EventFormResult(title: '', date: _date, delete: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _title,
            autofocus: widget.initialTitle.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Titre',
              hintText: 'Appeler le médecin',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(formatRelativeDay(_date)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(_time.format(context)),
                ),
              ),
            ],
          ),
          if (!widget.canDelete) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Une notification vous sera envoyée 15 minutes avant.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              if (widget.canDelete) ...[
                IconButton.outlined(
                  tooltip: 'Supprimer',
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _delete,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(widget.canDelete ? 'Enregistrer' : 'Créer le rappel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
