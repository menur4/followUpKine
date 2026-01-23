import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/session.dart';

class IcsCalendarService {
  /// Parse un fichier ICS et retourne les sessions correspondantes
  Future<List<Session>> parseIcsContent(String icsContent, String eventPattern) async {
    final sessions = <Session>[];
    final patterns = eventPattern.toLowerCase().split('|');

    // Parser les événements VEVENT
    final eventRegex = RegExp(r'BEGIN:VEVENT(.*?)END:VEVENT', dotAll: true);
    final matches = eventRegex.allMatches(icsContent);

    for (final match in matches) {
      final eventContent = match.group(1) ?? '';

      // Extraire le titre (SUMMARY)
      final summaryMatch = RegExp(r'SUMMARY[^:]*:(.+?)(?:\r?\n|$)').firstMatch(eventContent);
      final summary = summaryMatch?.group(1)?.trim() ?? '';

      // Vérifier si le titre correspond au pattern
      final summaryLower = summary.toLowerCase();
      bool matchesPattern = false;
      String? practitioner;

      for (final pattern in patterns) {
        if (summaryLower.contains(pattern.trim())) {
          matchesPattern = true;
          // Extraire le nom du praticien après le pattern
          final patternIndex = summaryLower.indexOf(pattern.trim());
          if (patternIndex != -1) {
            practitioner = summary.substring(patternIndex + pattern.trim().length).trim();
            // Nettoyer le nom
            if (practitioner.startsWith(':')) {
              practitioner = practitioner.substring(1).trim();
            }
          }
          break;
        }
      }

      if (!matchesPattern || practitioner == null || practitioner.isEmpty) {
        continue;
      }

      // Extraire la date (DTSTART)
      DateTime? startDate;
      final dtstartMatch = RegExp(r'DTSTART[^:]*:(\d{8}T?\d{0,6}Z?)').firstMatch(eventContent);
      if (dtstartMatch != null) {
        final dateStr = dtstartMatch.group(1) ?? '';
        startDate = _parseIcsDate(dateStr);
      }

      if (startDate == null) continue;

      // Extraire l'heure
      String? time;
      if (dtstartMatch != null) {
        final dateStr = dtstartMatch.group(1) ?? '';
        if (dateStr.contains('T') && dateStr.length >= 13) {
          final hour = dateStr.substring(9, 11);
          final minute = dateStr.substring(11, 13);
          time = '$hour:$minute';
        }
      }

      // Extraire le lieu (LOCATION)
      final locationMatch = RegExp(r'LOCATION[^:]*:(.+?)(?:\r?\n|$)').firstMatch(eventContent);
      final location = locationMatch?.group(1)?.trim();

      // Extraire l'UID comme identifiant
      final uidMatch = RegExp(r'UID[^:]*:(.+?)(?:\r?\n|$)').firstMatch(eventContent);
      final uid = uidMatch?.group(1)?.trim() ?? DateTime.now().millisecondsSinceEpoch.toString();

      sessions.add(Session(
        id: uid,
        date: startDate,
        practitioner: practitioner,
        paid: false,
        location: location,
        time: time,
      ));
    }

    // Trier par date
    sessions.sort((a, b) => a.date.compareTo(b.date));

    return sessions;
  }

  /// Télécharge et parse un calendrier ICS depuis une URL
  Future<List<Session>> fetchFromUrl(String url, String eventPattern) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return parseIcsContent(response.body, eventPattern);
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Impossible de récupérer le calendrier: $e');
    }
  }

  /// Parse un fichier ICS local
  Future<List<Session>> parseFromFile(File file, String eventPattern) async {
    try {
      final content = await file.readAsString();
      return parseIcsContent(content, eventPattern);
    } catch (e) {
      throw Exception('Impossible de lire le fichier: $e');
    }
  }

  DateTime? _parseIcsDate(String dateStr) {
    try {
      // Format: YYYYMMDD ou YYYYMMDDTHHMMSS ou YYYYMMDDTHHMMSSZ
      if (dateStr.length >= 8) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));

        int hour = 0;
        int minute = 0;

        if (dateStr.contains('T') && dateStr.length >= 13) {
          hour = int.parse(dateStr.substring(9, 11));
          minute = int.parse(dateStr.substring(11, 13));
        }

        return DateTime(year, month, day, hour, minute);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Extrait les praticiens uniques depuis les sessions
  Map<String, int> extractPractitioners(List<Session> sessions) {
    final counts = <String, int>{};
    for (final session in sessions) {
      counts[session.practitioner] = (counts[session.practitioner] ?? 0) + 1;
    }
    return counts;
  }
}
