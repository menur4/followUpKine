import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';

class CalendarSelectionScreen extends StatefulWidget {
  final List<Calendar> calendars;
  final String? preselectedCalendarId;
  final Function(String? calendarId, String? calendarName) onSelectionConfirmed;

  const CalendarSelectionScreen({
    super.key,
    required this.calendars,
    this.preselectedCalendarId,
    required this.onSelectionConfirmed,
  });

  @override
  State<CalendarSelectionScreen> createState() =>
      _CalendarSelectionScreenState();
}

class _CalendarSelectionScreenState extends State<CalendarSelectionScreen> {
  String? _selectedCalendarId;

  @override
  void initState() {
    super.initState();
    _selectedCalendarId = widget.preselectedCalendarId;
  }

  void _selectCalendar(String? id) {
    setState(() {
      _selectedCalendarId = id;
    });
  }

  void _confirmSelection() {
    if (_selectedCalendarId == null) {
      // "Tous les calendriers" selected
      widget.onSelectionConfirmed(null, null);
    } else {
      final calendar = widget.calendars.firstWhere(
        (c) => c.id == _selectedCalendarId,
      );
      widget.onSelectionConfirmed(calendar.id, calendar.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélection du calendrier'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Choisissez le calendrier contenant vos rendez-vous de kinésithérapie :',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Option "Tous les calendriers"
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _selectCalendar(null),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Radio<String?>(
                            value: null,
                            groupValue: _selectedCalendarId,
                            onChanged: _selectCalendar,
                            activeColor: Colors.black,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tous les calendriers',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Rechercher dans tous vos calendriers',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedCalendarId == null)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Individual calendars
                ...widget.calendars.map((calendar) {
                  final isSelected = _selectedCalendarId == calendar.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _selectCalendar(calendar.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Radio<String?>(
                              value: calendar.id,
                              groupValue: _selectedCalendarId,
                              onChanged: _selectCalendar,
                              activeColor: Colors.black,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    calendar.name ?? 'Sans nom',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (calendar.accountName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      calendar.accountName!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Continuer',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
