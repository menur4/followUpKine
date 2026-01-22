import 'dart:convert';

class AppSettings {
  final String eventPattern;
  final String? selectedCalendarId;
  final String? selectedCalendarName;
  final List<String> selectedPractitioners;
  final List<String> selectedOrganizers; // Filter by event creator/organizer
  final bool hasCompletedSetup;

  static const String defaultPattern = 'rendez-vous chez|rdv chez';

  AppSettings({
    required this.eventPattern,
    this.selectedCalendarId,
    this.selectedCalendarName,
    required this.selectedPractitioners,
    this.selectedOrganizers = const [],
    required this.hasCompletedSetup,
  });

  factory AppSettings.defaults() {
    return AppSettings(
      eventPattern: defaultPattern,
      selectedCalendarId: null,
      selectedCalendarName: null,
      selectedPractitioners: [],
      selectedOrganizers: [],
      hasCompletedSetup: false,
    );
  }

  AppSettings copyWith({
    String? eventPattern,
    String? selectedCalendarId,
    String? selectedCalendarName,
    List<String>? selectedPractitioners,
    List<String>? selectedOrganizers,
    bool? hasCompletedSetup,
  }) {
    return AppSettings(
      eventPattern: eventPattern ?? this.eventPattern,
      selectedCalendarId: selectedCalendarId ?? this.selectedCalendarId,
      selectedCalendarName: selectedCalendarName ?? this.selectedCalendarName,
      selectedPractitioners: selectedPractitioners ?? this.selectedPractitioners,
      selectedOrganizers: selectedOrganizers ?? this.selectedOrganizers,
      hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventPattern': eventPattern,
      'selectedCalendarId': selectedCalendarId,
      'selectedCalendarName': selectedCalendarName,
      'selectedPractitioners': selectedPractitioners,
      'selectedOrganizers': selectedOrganizers,
      'hasCompletedSetup': hasCompletedSetup,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      eventPattern: json['eventPattern'] ?? defaultPattern,
      selectedCalendarId: json['selectedCalendarId'],
      selectedCalendarName: json['selectedCalendarName'],
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
}
