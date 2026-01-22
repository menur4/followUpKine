import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/session.dart';
import '../models/app_settings.dart';

class LocalCalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  /// Request calendar permissions
  Future<bool> requestPermissions() async {
    var status = await Permission.calendar.status;
    debugPrint('Calendar permission status: $status');

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      debugPrint('Permission permanently denied, opening settings...');
      await openAppSettings();
      status = await Permission.calendar.status;
      return status.isGranted;
    }

    status = await Permission.calendar.request();
    debugPrint('Permission request result: $status');
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

  /// Fetch events from calendars between two dates
  Future<List<Event>> fetchEvents(
    DateTime startDate,
    DateTime endDate, {
    String? calendarId,
  }) async {
    final hasPerms = await hasPermissions();
    if (!hasPerms) {
      final granted = await requestPermissions();
      if (!granted) {
        debugPrint('Calendar permission denied');
        return [];
      }
    }

    final List<Event> allEvents = [];

    if (calendarId != null) {
      // Fetch from specific calendar
      final result = await _deviceCalendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: startDate, endDate: endDate),
      );
      if (result.isSuccess && result.data != null) {
        allEvents.addAll(result.data!);
      }
    } else {
      // Fetch from all calendars
      final calendars = await getCalendars();
      debugPrint('Found ${calendars.length} calendars');

      for (final calendar in calendars) {
        debugPrint('Checking calendar: ${calendar.name} (${calendar.id})');

        final result = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(startDate: startDate, endDate: endDate),
        );

        if (result.isSuccess && result.data != null) {
          allEvents.addAll(result.data!);
          debugPrint('  Found ${result.data!.length} events');
        }
      }
    }

    debugPrint('Total events found: ${allEvents.length}');
    return allEvents;
  }

  /// Extract practitioner name from event title using the given pattern
  String? extractPractitionerName(String? title, RegExp pattern) {
    if (title == null) return null;
    final match = pattern.firstMatch(title);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)?.trim();
    }
    return null;
  }

  /// Discover all unique practitioner names from calendar events
  Future<Map<String, int>> discoverPractitioners({
    required DateTime startDate,
    required DateTime endDate,
    required String eventPattern,
    String? calendarId,
    List<String>? accountFilter,
  }) async {
    final regex = _buildEventRegex(eventPattern);

    // Si un filtre de compte est spécifié, récupérer les calendriers pour faire le mapping
    Map<String, String>? calendarToAccount;
    if (accountFilter != null && accountFilter.isNotEmpty) {
      final calendars = await getCalendars();
      calendarToAccount = {};
      for (final cal in calendars) {
        if (cal.id != null && cal.accountName != null) {
          calendarToAccount[cal.id!] = cal.accountName!;
        }
      }
      debugPrint('Calendar to account mapping: $calendarToAccount');
    }

    final events = await fetchEvents(startDate, endDate, calendarId: calendarId);

    final Map<String, int> practitioners = {};

    for (final event in events) {
      // Filter by account if specified
      if (accountFilter != null && accountFilter.isNotEmpty && calendarToAccount != null) {
        final eventCalendarId = event.calendarId;
        if (eventCalendarId == null) continue;

        final accountName = calendarToAccount[eventCalendarId];
        if (accountName == null || !accountFilter.any(
          (a) => accountName.toLowerCase() == a.toLowerCase()
        )) {
          continue;
        }
      }

      final name = extractPractitionerName(event.title, regex);
      if (name != null && name.isNotEmpty) {
        practitioners[name] = (practitioners[name] ?? 0) + 1;
      }
    }

    // Sort by count descending
    final sortedEntries = practitioners.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries);
  }

  /// Discover all unique organizers/creators from matching calendar events
  /// Note: This method relies on event attendee data which may not be available
  /// for all calendar providers. For Google Calendar, use calendar account filtering instead.
  Future<Map<String, int>> discoverOrganizers({
    required DateTime startDate,
    required DateTime endDate,
    required String eventPattern,
    String? calendarId,
  }) async {
    final regex = _buildEventRegex(eventPattern);
    final events = await fetchEvents(startDate, endDate, calendarId: calendarId);

    final Map<String, int> organizers = {};

    for (final event in events) {
      // Only consider events that match the pattern
      if (!_matchesPattern(event, regex)) continue;

      final organizer = _getEventOrganizer(event);
      if (organizer != null && organizer.isNotEmpty) {
        organizers[organizer] = (organizers[organizer] ?? 0) + 1;
      }
    }

    debugPrint('Organizer discovery: ${organizers.length} unique organizers found');

    // Sort by count descending
    final sortedEntries = organizers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries);
  }

  /// Extract organizer email or name from event attendees
  String? _getEventOrganizer(Event event) {
    // Find the organizer in the attendees list
    if (event.attendees != null && event.attendees!.isNotEmpty) {
      for (final attendee in event.attendees!) {
        if (attendee != null && attendee.isOrganiser) {
          // Prefer name over email if available
          if (attendee.name != null && attendee.name!.isNotEmpty) {
            return attendee.name;
          }
          if (attendee.emailAddress != null && attendee.emailAddress!.isNotEmpty) {
            return attendee.emailAddress;
          }
        }
      }
    }
    return null;
  }

  /// Check if event matches the pattern
  bool _matchesPattern(Event event, RegExp pattern) {
    final title = event.title;
    if (title == null) return false;
    return pattern.hasMatch(title);
  }

  /// Check if event practitioner is in the selected list
  bool _isPractitionerSelected(
    Event event,
    RegExp pattern,
    List<String> selectedPractitioners,
  ) {
    if (selectedPractitioners.isEmpty) return true;

    final name = extractPractitionerName(event.title, pattern);
    if (name == null) return false;

    return selectedPractitioners.any(
      (selected) => name.toLowerCase() == selected.toLowerCase(),
    );
  }

  bool _isPaid(DateTime eventDate, DateTime today) {
    return eventDate.isBefore(today) ||
        (eventDate.year == today.year &&
            eventDate.month == today.month &&
            eventDate.day == today.day);
  }

  RegExp _buildEventRegex(String eventPattern) {
    final patterns = eventPattern
        .split('|')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    final regexPattern = '^(?:${patterns.join('|')})\\s+(.+)\$';
    return RegExp(regexPattern, caseSensitive: false);
  }

  /// Convert calendar events to Session objects with configurable filtering
  List<Session> parseEventsToSessions(
    List<Event> events, {
    required String eventPattern,
    required List<String> selectedPractitioners,
    List<String> selectedAccounts = const [],
    Map<String, String>? calendarToAccount,
  }) {
    final today = DateTime.now();
    final regex = _buildEventRegex(eventPattern);

    debugPrint('Filtering events with pattern: $eventPattern');
    debugPrint('Selected practitioners: $selectedPractitioners');
    debugPrint('Selected accounts: $selectedAccounts');
    debugPrint('Total events received: ${events.length}');

    final filteredEvents = events.where((event) {
      final matchesPattern = _matchesPattern(event, regex);
      if (!matchesPattern) return false;

      // Filter by account if specified
      if (selectedAccounts.isNotEmpty && calendarToAccount != null) {
        final eventCalendarId = event.calendarId;
        if (eventCalendarId == null) return false;

        final accountName = calendarToAccount[eventCalendarId];
        if (accountName == null || !selectedAccounts.any(
          (a) => accountName.toLowerCase() == a.toLowerCase()
        )) {
          return false;
        }
      }

      final practitionerSelected =
          _isPractitionerSelected(event, regex, selectedPractitioners);
      if (practitionerSelected) {
        debugPrint('Found matching session: ${event.title}');
      }
      return practitionerSelected;
    }).toList();

    debugPrint(
        'Found ${filteredEvents.length} matching sessions out of ${events.length} total events');

    final sessions = filteredEvents.map((event) {
      final date = event.start ?? DateTime.now();
      final paid = _isPaid(date, today);
      final practitionerName = extractPractitionerName(event.title, regex) ?? 'Inconnu';

      String? time;
      if (event.start != null) {
        time =
            '${event.start!.hour.toString().padLeft(2, '0')}:${event.start!.minute.toString().padLeft(2, '0')}';
      }

      return Session(
        id: event.eventId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date: date,
        practitioner: practitionerName,
        paid: paid,
        paidDate: paid ? today : null,
        location: event.location,
        time: time,
      );
    }).toList();

    sessions.sort((a, b) => a.date.compareTo(b.date));
    return sessions;
  }

  /// Fetch and parse sessions with configurable settings
  Future<List<Session>> fetchSessions(
    DateTime startDate,
    DateTime endDate, {
    required AppSettings settings,
  }) async {
    // Build calendar to account mapping if account filter is active
    Map<String, String>? calendarToAccount;
    if (settings.selectedOrganizers.isNotEmpty) {
      final calendars = await getCalendars();
      calendarToAccount = {};
      for (final cal in calendars) {
        if (cal.id != null && cal.accountName != null) {
          calendarToAccount[cal.id!] = cal.accountName!;
        }
      }
    }

    final events = await fetchEvents(
      startDate,
      endDate,
      calendarId: settings.selectedCalendarId,
    );
    return parseEventsToSessions(
      events,
      eventPattern: settings.eventPattern,
      selectedPractitioners: settings.selectedPractitioners,
      selectedAccounts: settings.selectedOrganizers,
      calendarToAccount: calendarToAccount,
    );
  }
}
