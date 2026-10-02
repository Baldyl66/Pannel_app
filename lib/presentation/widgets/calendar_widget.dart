import 'package:flutter/material.dart';
import '../../services/google_calendar_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  bool _isLoggedIn = false;
  bool _isLoading = true;
  List<dynamic> _events = [];
  Timer? _refreshTimer;
  DateTime _selectedDate = DateTime.now();

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return "Demain";
    if (diff == -1) return "Hier";
    return DateFormat('dd/MM').format(date);
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _calendarService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });

    if (loggedIn) {
      _fetchEvents();
      _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchEvents());
    }
  }

  Future<void> _fetchEvents() async {
    if (!_isLoggedIn) return;
    final events = await _calendarService.getEventsForDate(_selectedDate);
    if (!mounted) return;
    setState(() {
      _events = events;
    });
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final error = await _calendarService.login();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $error'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
      return;
    }
    await _checkLoginStatus();
  }
  
  Future<void> _showAddReminderDialog() async {
    String title = "";
    DateTime selectedDate = _selectedDate;
    TimeOfDay selectedTime = TimeOfDay.now();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 16 : 32, left: 24, right: 24, top: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(child: Text('Nouveau Rappel', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 24),
                  TextField(
                    autofocus: false,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Que devez-vous faire ?',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 18),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => title = val,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setSheetState(() => selectedDate = date);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFF4285F4), size: 20),
                                const SizedBox(width: 8),
                                Text(DateFormat('dd/MM').format(selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) setSheetState(() => selectedTime = time);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.access_time, color: Color(0xFF4285F4), size: 20),
                                const SizedBox(width: 8),
                                Text(selectedTime.format(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Créer l\'événement', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    
    if (confirmed == true && title.isNotEmpty) {
        final finalDateTime = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day,
          selectedTime.hour, selectedTime.minute,
        );
        setState(() => _isLoading = true);
        await _calendarService.createReminder(title, finalDateTime);
        await _fetchEvents();
        setState(() => _isLoading = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Rappel ajouté au calendrier !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF4285F4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
  }
  
  Future<void> _showEditEventDialog(Map<String, dynamic> event) async {
    final eventId = event['id'];
    if (eventId == null) return;
    
    String title = event['summary'] ?? '';
    final startStr = event['start']['dateTime'] ?? event['start']['date'];
    DateTime selectedDate = startStr != null ? DateTime.parse(startStr).toLocal() : _selectedDate;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    bool shouldDelete = false;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 16 : 32, left: 24, right: 24, top: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Modifier', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                        onPressed: () {
                          shouldDelete = true;
                          Navigator.pop(context, true);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: TextEditingController(text: title)..selection = TextSelection.fromPosition(TextPosition(offset: title.length)),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Quoi faire ?',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 18),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => title = val,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setSheetState(() => selectedDate = date);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_today, color: Color(0xFF4285F4), size: 20),
                                const SizedBox(width: 8),
                                Text(DateFormat('dd/MM').format(selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) setSheetState(() => selectedTime = time);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.access_time, color: Color(0xFF4285F4), size: 20),
                                const SizedBox(width: 8),
                                Text(selectedTime.format(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    
    if (confirmed == true) {
      setState(() => _isLoading = true);
      if (shouldDelete) {
        await _calendarService.deleteEvent(eventId);
      } else if (title.isNotEmpty) {
        final finalDateTime = DateTime(
          selectedDate.year, selectedDate.month, selectedDate.day,
          selectedTime.hour, selectedTime.minute,
        );
        await _calendarService.updateEvent(eventId, title, finalDateTime);
      }
      await _fetchEvents();
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bentoBackground = Color(0xFF151515);
    final bentoBorder = Border.all(color: Colors.white10, width: 1);

    if (_isLoading) {
      return Container(
        height: 160,
        decoration: BoxDecoration(color: bentoBackground, borderRadius: BorderRadius.circular(24), border: bentoBorder),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF4285F4))),
      );
    }

    if (!_isLoggedIn) {
      return InkWell(
        onTap: _login,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 120,
          decoration: BoxDecoration(color: bentoBackground, borderRadius: BorderRadius.circular(24), border: bentoBorder),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, color: Colors.white),
              SizedBox(width: 16),
              Text('Connecter Google Agenda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bentoBackground,
        borderRadius: BorderRadius.circular(24),
        border: bentoBorder,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white54),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                        });
                        _fetchEvents();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDateLabel(_selectedDate),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white54),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.add(const Duration(days: 1));
                        });
                        _fetchEvents();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.white54),
                onPressed: _showAddReminderDialog,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Rien de prévu !', style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            )
          else
            ..._events.map((event) {
              final start = event['start']['dateTime'] ?? event['start']['date'];
              final timeStr = start != null 
                  ? DateFormat('HH:mm').format(DateTime.parse(start).toLocal())
                  : 'Journée';
                  
              return InkWell(
                onTap: () => _showEditEventDialog(event),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          timeStr,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event['summary'] ?? 'Sans titre',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
