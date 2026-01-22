import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/session.dart';

class LocalCalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  static const Map<String, String> _practitioners = {
    'GIGOUX': 'C. Gigoux',
    'TINDANO': 'L. Tindano',
  };

  static const List<String> _allowedPractitioners = [
    'tindano',
    'léonard',
    'gigoux',
    'corentin'
  ];

  // Pattern pour identifier les séances de kiné : "Rendez-vous chez [nom]" ou "RDV chez [nom]"
  static final RegExp _kinePattern =
      RegExp(r'^(?:rendez-vous|rdv) chez\s+(.+)$', caseSensitive: false);

  /// Request calendar permissions
  Future<bool> requestPermissions() async {
    final status = await Permission.calendar.request();
    return status.isGranted;
  }

  /// Check if calendar permissions are granted
  Future<bool> hasPermissions() async {
    final status = await Permission.calendar.status;
    return status.isGranted;
  }

  /// Fetch all calendars from the device
  Future<List<Calendar>> getCalendars() async {
    final hasPerms = await hasPermissions();
    if (!hasPerms) {
      final granted = await requestPermissions();
      if (!granted) return [];
    }

    final result = await _deviceCalendarPlugin.retrieveCalendars();
    if (result.isSuccess && result.data != null) {
      return result.data!;
    }
    return [];
  }

  /// Fetch events from all calendars between two dates
  Future<List<Event>> fetchEvents(DateTime startDate, DateTime endDate) async {
    final hasPerms = await hasPermissions();
    if (!hasPerms) {
      final granted = await requestPermissions();
      if (!granted) {
        debugPrint('Calendar permission denied');
        return [];
      }
    }

    final calendars = await getCalendars();
    debugPrint('Found ${calendars.length} calendars');

    final List<Event> allEvents = [];

    for (final calendar in calendars) {
      debugPrint('Checking calendar: ${calendar.name} (${calendar.id})');

      final result = await _deviceCalendarPlugin.retrieveEvents(
        calendar.id,
        RetrieveEventsParams(
          startDate: startDate,
          endDate: endDate,
        ),
      );

      if (result.isSuccess && result.data != null) {
        allEvents.addAll(result.data!);
        debugPrint('  Found ${result.data!.length} events');
      }
    }

    debugPrint('Total events found: ${allEvents.length}');
    return allEvents;
  }

  String? _extractPractitionerName(String? title) {
    if (title == null) return null;
    final match = _kinePattern.firstMatch(title);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }

  String _detectPractitioner(String? title) {
    final practitionerName = _extractPractitionerName(title);

    if (practitionerName != null) {
      final nameLower = practitionerName.toLowerCase();

      if (nameLower.contains('tindano') || nameLower.contains('léonard')) {
        return _practitioners['TINDANO']!;
      }
      if (nameLower.contains('gigoux') || nameLower.contains('corentin')) {
        return _practitioners['GIGOUX']!;
      }
    }

    return _practitioners['TINDANO']!;
  }

  bool _isAllowedPractitioner(String? title) {
    final practitionerName = _extractPractitionerName(title);
    if (practitionerName == null) return false;

    final nameLower = practitionerName.toLowerCase();
    return _allowedPractitioners.any((p) => nameLower.contains(p));
  }

  bool _isKineSession(Event event) {
    final title = event.title;
    if (title == null) return false;

    final matchesPattern = _kinePattern.hasMatch(title);
    final allowedPractitioner = _isAllowedPractitioner(title);

    return matchesPattern && allowedPractitioner;
  }

  bool _isPaid(DateTime eventDate, DateTime today) {
    return eventDate.isBefore(today) ||
        eventDate.year == today.year &&
            eventDate.month == today.month &&
            eventDate.day == today.day;
  }

  /// Convert calendar events to Session objects
  List<Session> parseEventsToSessions(List<Event> events) {
    final today = DateTime.now();

    debugPrint('Filtering events...');
    debugPrint('Total events received: ${events.length}');

    // Debug: show first few events
    if (events.isNotEmpty) {
      debugPrint('Sample events:');
      for (final e in events.take(10)) {
        debugPrint('  - ${e.title} (${e.start})');
      }
    }

    final kineEvents = events.where((event) {
      final isKine = _isKineSession(event);
      if (isKine) {
        debugPrint('Found kiné session: ${event.title}');
      }
      return isKine;
    }).toList();

    debugPrint(
        'Found ${kineEvents.length} kiné sessions out of ${events.length} total events');

    final sessions = kineEvents.map((event) {
      final date = event.start ?? DateTime.now();
      final paid = _isPaid(date, today);

      String? time;
      if (event.start != null) {
        time =
            '${event.start!.hour.toString().padLeft(2, '0')}:${event.start!.minute.toString().padLeft(2, '0')}';
      }

      return Session(
        id: event.eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date: date,
        practitioner: _detectPractitioner(event.title),
        paid: paid,
        paidDate: paid ? today : null,
        location: event.location,
        time: time,
      );
    }).toList();

    sessions.sort((a, b) => a.date.compareTo(b.date));
    return sessions;
  }

  /// Fetch and parse sessions from the device calendar
  Future<List<Session>> fetchSessions(DateTime startDate, DateTime endDate) async {
    final events = await fetchEvents(startDate, endDate);
    return parseEventsToSessions(events);
  }
}
