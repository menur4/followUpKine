class CalendarEvent {
  final String id;
  final String? summary;
  final EventDateTime start;
  final EventDateTime end;
  final String? location;
  final String? description;
  final EventCreator? creator;

  CalendarEvent({
    required this.id,
    this.summary,
    required this.start,
    required this.end,
    this.location,
    this.description,
    this.creator,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      summary: json['summary'] as String?,
      start: EventDateTime.fromJson(json['start'] as Map<String, dynamic>),
      end: EventDateTime.fromJson(json['end'] as Map<String, dynamic>),
      location: json['location'] as String?,
      description: json['description'] as String?,
      creator: json['creator'] != null
          ? EventCreator.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
    );
  }
}

class EventDateTime {
  final String? dateTime;
  final String? date;

  EventDateTime({this.dateTime, this.date});

  factory EventDateTime.fromJson(Map<String, dynamic> json) {
    return EventDateTime(
      dateTime: json['dateTime'] as String?,
      date: json['date'] as String?,
    );
  }

  DateTime toDateTime() {
    return DateTime.parse(dateTime ?? date ?? DateTime.now().toIso8601String());
  }
}

class EventCreator {
  final String? email;
  final String? displayName;

  EventCreator({this.email, this.displayName});

  factory EventCreator.fromJson(Map<String, dynamic> json) {
    return EventCreator(
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
    );
  }
}
