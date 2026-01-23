import 'dart:convert';

enum CalendarSourceType {
  none,
  internal,  // Calendrier du téléphone
  url,       // URL ICS distant
  file,      // Fichier ICS local
}

class AppSettings {
  final String eventPattern;
  final CalendarSourceType calendarSourceType;
  final String? selectedCalendarId;
  final String? selectedCalendarName;
  final String? icsUrl;           // URL du calendrier ICS distant
  final String? icsFilePath;      // Chemin du fichier ICS local
  final List<String> selectedPractitioners;
  final List<String> selectedOrganizers;
  final bool hasCompletedSetup;

  static const String defaultPattern = 'rendez-vous chez|rdv chez';

  AppSettings({
    required this.eventPattern,
    this.calendarSourceType = CalendarSourceType.none,
    this.selectedCalendarId,
    this.selectedCalendarName,
    this.icsUrl,
    this.icsFilePath,
    required this.selectedPractitioners,
    this.selectedOrganizers = const [],
    required this.hasCompletedSetup,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      eventPattern: defaultPattern,
      calendarSourceType: CalendarSourceType.none,
      selectedCalendarId: null,
      selectedCalendarName: null,
      icsUrl: null,
      icsFilePath: null,
      selectedPractitioners: [],
      selectedOrganizers: [],
      hasCompletedSetup: false,
    );
  }

  AppSettings copyWith({
    String? eventPattern,
    CalendarSourceType? calendarSourceType,
    String? selectedCalendarId,
    String? selectedCalendarName,
    String? icsUrl,
    String? icsFilePath,
    List<String>? selectedPractitioners,
    List<String>? selectedOrganizers,
    bool? hasCompletedSetup,
    bool clearCalendarId = false,
    bool clearIcsUrl = false,
    bool clearIcsFilePath = false,
  }) {
    return AppSettings(
      eventPattern: eventPattern ?? this.eventPattern,
      calendarSourceType: calendarSourceType ?? this.calendarSourceType,
      selectedCalendarId: clearCalendarId ? null : (selectedCalendarId ?? this.selectedCalendarId),
      selectedCalendarName: clearCalendarId ? null : (selectedCalendarName ?? this.selectedCalendarName),
      icsUrl: clearIcsUrl ? null : (icsUrl ?? this.icsUrl),
      icsFilePath: clearIcsFilePath ? null : (icsFilePath ?? this.icsFilePath),
      selectedPractitioners: selectedPractitioners ?? this.selectedPractitioners,
      selectedOrganizers: selectedOrganizers ?? this.selectedOrganizers,
      hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventPattern': eventPattern,
      'calendarSourceType': calendarSourceType.index,
      'selectedCalendarId': selectedCalendarId,
      'selectedCalendarName': selectedCalendarName,
      'icsUrl': icsUrl,
      'icsFilePath': icsFilePath,
      'selectedPractitioners': selectedPractitioners,
      'selectedOrganizers': selectedOrganizers,
      'hasCompletedSetup': hasCompletedSetup,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      eventPattern: json['eventPattern'] ?? defaultPattern,
      calendarSourceType: CalendarSourceType.values[json['calendarSourceType'] ?? 0],
      selectedCalendarId: json['selectedCalendarId'],
      selectedCalendarName: json['selectedCalendarName'],
      icsUrl: json['icsUrl'],
      icsFilePath: json['icsFilePath'],
      selectedPractitioners: List<String>.from(json['selectedPractitioners'] ?? []),
      selectedOrganizers: List<String>.from(json['selectedOrganizers'] ?? []),
      hasCompletedSetup: json['hasCompletedSetup'] ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AppSettings.fromJsonString(String jsonString) {
    return AppSettings.fromJson(jsonDecode(jsonString));
  }

  /// Build regex from pattern string (e.g., "rdv chez|rendez-vous chez")
  RegExp buildEventRegex() {
    final patterns = eventPattern.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty);
    final regexPattern = '^(?:${patterns.join('|')})\\s+(.+)\$';
    return RegExp(regexPattern, caseSensitive: false);
  }

  String get calendarSourceDescription {
    switch (calendarSourceType) {
      case CalendarSourceType.internal:
        return selectedCalendarName ?? 'Calendrier interne';
      case CalendarSourceType.url:
        return 'Calendrier distant (URL)';
      case CalendarSourceType.file:
        return 'Fichier ICS';
      case CalendarSourceType.none:
        return 'Non configuré';
    }
  }
}
