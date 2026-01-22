import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/calendar_event.dart';
import '../models/session.dart';

class GoogleCalendarService {
  static const String _userEmail = 'hamonfrancois@gmail.com';
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
  static final RegExp _kinePattern =
      RegExp(r'^(?:rendez-vous|rdv) chez\s+(.+)$', caseSensitive: false);

  String? get _apiKey => dotenv.env['GOOGLE_API_KEY'];
  String? get _calendarId => dotenv.env['GOOGLE_CALENDAR_ID'];

  Future<List<CalendarEvent>> fetchCalendarEvents(
    String timeMin,
    String timeMax,
  ) async {
    if (_apiKey == null || _calendarId == null) {
      print('Google Calendar API not configured');
      return [];
    }

    final List<CalendarEvent> allEvents = [];
    String? pageToken;
    int pageCount = 0;

    do {
      final uri = Uri.https(
        'www.googleapis.com',
        '/calendar/v3/calendars/${Uri.encodeComponent(_calendarId!)}/events',
        {
          'key': _apiKey!,
          'timeMin': timeMin,
          'timeMax': timeMax,
          'singleEvents': 'true',
          'orderBy': 'startTime',
          'maxResults': '250',
          if (pageToken != null) 'pageToken': pageToken,
        },
      );

      pageCount++;
      print('Fetching page $pageCount from Google Calendar API...');

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
            'Google Calendar API error: ${response.statusCode} - ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>?) ?? [];

      for (final item in items) {
        allEvents.add(CalendarEvent.fromJson(item as Map<String, dynamic>));
      }

      print(
          'Page $pageCount: received ${items.length} events (total: ${allEvents.length})');

      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);

    print('Finished fetching all ${allEvents.length} events in $pageCount page(s)');
    return allEvents;
  }

  String? _extractPractitionerName(CalendarEvent event) {
    final match = _kinePattern.firstMatch(event.summary ?? '');
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }

  String _detectPractitioner(CalendarEvent event) {
    final practitionerName = _extractPractitionerName(event);

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

  bool _isCreatedByUser(CalendarEvent event) {
    return event.creator?.email == _userEmail;
  }

  bool _isAllowedPractitioner(CalendarEvent event) {
    final practitionerName = _extractPractitionerName(event);
    if (practitionerName == null) return false;

    final nameLower = practitionerName.toLowerCase();
    return _allowedPractitioners.any((p) => nameLower.contains(p));
  }

  bool _isPaid(CalendarEvent event, DateTime today) {
    final eventDate = event.start.toDateTime();
    return eventDate.isBefore(today) || eventDate.isAtSameMomentAs(today);
  }

  List<Session> parseEventsToSessions(List<CalendarEvent> events) {
    final today = DateTime.now();

    print('Filtering events...');
    print('Total events received: ${events.length}');

    final kineEvents = events.where((event) {
      final matchesPattern = _kinePattern.hasMatch(event.summary ?? '');
      final createdByUser = _isCreatedByUser(event);
      final allowedPractitioner = _isAllowedPractitioner(event);

      return matchesPattern && createdByUser && allowedPractitioner;
    }).toList();

    print('Found ${kineEvents.length} kiné sessions out of ${events.length} total events');

    final sessions = kineEvents.map((event) {
      final date = event.start.toDateTime();
      final paid = _isPaid(event, today);

      String? time;
      if (event.start.dateTime != null) {
        final dt = DateTime.parse(event.start.dateTime!);
        time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }

      return Session(
        id: event.id,
        date: date,
        practitioner: _detectPractitioner(event),
        paid: paid,
        paidDate: paid ? today : null,
        location: event.location,
        time: time,
      );
    }).toList();

    sessions.sort((a, b) => a.date.compareTo(b.date));
    return sessions;
  }

  List<Session> getMockSessions() {
    final List<Session> sessions = [];
    final today = DateTime.now();

    final data = [
      {'month': 3, 'year': 2025, 'count': 5, 'practitioner': _practitioners['GIGOUX']!},
      {'month': 4, 'year': 2025, 'count': 5, 'practitioner': _practitioners['GIGOUX']!},
      {'month': 5, 'year': 2025, 'count': 6, 'practitioner': _practitioners['GIGOUX']!},
      {'month': 6, 'year': 2025, 'count': 4, 'practitioner': _practitioners['GIGOUX']!},
      {'month': 7, 'year': 2025, 'count': 6, 'practitioner': _practitioners['TINDANO']!},
      {'month': 8, 'year': 2025, 'count': 4, 'practitioner': _practitioners['TINDANO']!},
      {'month': 9, 'year': 2025, 'count': 5, 'practitioner': _practitioners['TINDANO']!},
      {'month': 10, 'year': 2025, 'count': 1, 'practitioner': _practitioners['TINDANO']!},
      {'month': 1, 'year': 2026, 'count': 4, 'practitioner': _practitioners['TINDANO']!},
      {'month': 2, 'year': 2026, 'count': 2, 'practitioner': _practitioners['TINDANO']!},
    ];

    int id = 1;

    for (final item in data) {
      final month = item['month'] as int;
      final year = item['year'] as int;
      final count = item['count'] as int;
      final practitioner = item['practitioner'] as String;

      for (int i = 0; i < count; i++) {
        final day = (1 + i * 4).clamp(1, 28);
        final date = DateTime(year, month, day, 12, 15);
        final isPaidSession = date.isBefore(today);

        sessions.add(Session(
          id: 'mock-${id++}',
          date: date,
          practitioner: practitioner,
          paid: isPaidSession,
          paidDate: isPaidSession ? DateTime(year, month, day + 5) : null,
          location: '24 Rue du Javelot, 75013 Paris',
          time: '12:15',
        ));
      }
    }

    return sessions;
  }
}
