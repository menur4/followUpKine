import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../services/google_calendar_service.dart';

class SessionProvider extends ChangeNotifier {
  final GoogleCalendarService _calendarService = GoogleCalendarService();

  List<Session> _sessions = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastUpdated;

  static const String _cacheKey = 'kine_sessions_cache';
  static const String _cacheTimestampKey = 'kine_sessions_cache_timestamp';
  static const int _cacheExpirationHours = 1;

  List<Session> get sessions => _sessions;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;

  List<Session> get pastSessions =>
      _sessions.where((s) => !s.isFuture).toList();
  List<Session> get futureSessions =>
      _sessions.where((s) => s.isFuture).toList();

  PaymentStats get paymentStats {
    int paid2025 = 0;
    int paid2026 = 0;
    int pending = 0;

    for (final session in _sessions) {
      if (!session.paid) {
        pending++;
      } else if (session.date.year == 2025) {
        paid2025++;
      } else if (session.date.year == 2026) {
        paid2026++;
      }
    }

    return PaymentStats(
      paid2025: paid2025,
      paid2026: paid2026,
      pending: pending,
      total: _sessions.length,
    );
  }

  List<MonthlyStats> get monthlyStats {
    final Map<String, Map<String, int>> statsByMonth = {};
    final DateFormat monthFormat = DateFormat('MMM yyyy', 'fr_FR');

    // Générer tous les mois de mars 2025 jusqu'au mois actuel
    final startDate = DateTime(2025, 3, 1);
    final now = DateTime.now();

    // Trouver le dernier mois avec une séance
    DateTime? lastSessionMonth;
    for (final session in _sessions) {
      if (lastSessionMonth == null || session.date.isAfter(lastSessionMonth)) {
        lastSessionMonth = session.date;
      }
    }

    // Utiliser le max entre maintenant et le dernier mois avec séance
    final endDate = lastSessionMonth != null && lastSessionMonth.isAfter(now)
        ? lastSessionMonth
        : now;

    DateTime current = startDate;
    while (current.isBefore(endDate) ||
        (current.year == endDate.year && current.month == endDate.month)) {
      final key = '${current.year}-${current.month.toString().padLeft(2, '0')}';
      statsByMonth[key] = {'gigoux': 0, 'tindano': 0};
      current = DateTime(current.year, current.month + 1, 1);
    }

    // Compter les séances par mois
    for (final session in _sessions) {
      final key =
          '${session.date.year}-${session.date.month.toString().padLeft(2, '0')}';
      if (statsByMonth.containsKey(key)) {
        if (session.practitioner.contains('Gigoux')) {
          statsByMonth[key]!['gigoux'] = statsByMonth[key]!['gigoux']! + 1;
        } else if (session.practitioner.contains('Tindano')) {
          statsByMonth[key]!['tindano'] = statsByMonth[key]!['tindano']! + 1;
        }
      }
    }

    // Convertir en liste triée
    final sortedKeys = statsByMonth.keys.toList()..sort();

    return sortedKeys.map((key) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = DateTime(year, month, 1);

      final gigoux = statsByMonth[key]!['gigoux']!;
      final tindano = statsByMonth[key]!['tindano']!;

      return MonthlyStats(
        month: monthFormat.format(date),
        sortKey: year * 100 + month,
        gigoux: gigoux,
        tindano: tindano,
        total: gigoux + tindano,
      );
    }).toList();
  }

  List<PractitionerStats> get practitionerStats {
    int gigoux = 0;
    int tindano = 0;

    for (final session in _sessions) {
      if (session.practitioner.contains('Gigoux')) {
        gigoux++;
      } else if (session.practitioner.contains('Tindano')) {
        tindano++;
      }
    }

    final total = gigoux + tindano;
    if (total == 0) return [];

    return [
      PractitionerStats(
        name: 'C. Gigoux',
        count: gigoux,
        percentage: (gigoux / total) * 100,
      ),
      PractitionerStats(
        name: 'L. Tindano',
        count: tindano,
        percentage: (tindano / total) * 100,
      ),
    ];
  }

  Future<void> loadSessions() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Essayer de charger depuis le cache
      final cached = await _loadFromCache();
      if (cached != null) {
        _sessions = cached;
        _loading = false;
        notifyListeners();

        // Rafraîchir en arrière-plan si le cache est expiré
        if (_isCacheExpired()) {
          _refreshInBackground();
        }
        return;
      }

      // Pas de cache, charger depuis l'API
      await _fetchFromApi();
    } catch (e) {
      _error = e.toString();
      // En cas d'erreur, utiliser les données mock
      _sessions = _calendarService.getMockSessions();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _refreshing = true;
    _error = null;
    notifyListeners();

    try {
      await _fetchFromApi();
    } catch (e) {
      _error = e.toString();
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> _fetchFromApi() async {
    final timeMin = DateTime(2025, 3, 1).toUtc().toIso8601String();
    final timeMax = DateTime(2026, 12, 31).toUtc().toIso8601String();

    final events = await _calendarService.fetchCalendarEvents(timeMin, timeMax);

    if (events.isEmpty) {
      // API non configurée, utiliser les données mock
      _sessions = _calendarService.getMockSessions();
    } else {
      _sessions = _calendarService.parseEventsToSessions(events);
    }

    _lastUpdated = DateTime.now();
    await _saveToCache();
  }

  Future<void> _refreshInBackground() async {
    _refreshing = true;
    notifyListeners();

    try {
      await _fetchFromApi();
    } catch (e) {
      print('Background refresh failed: $e');
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<List<Session>?> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_cacheTimestampKey);

    if (cached == null || timestamp == null) return null;

    _lastUpdated = DateTime.fromMillisecondsSinceEpoch(timestamp);

    final List<dynamic> decoded = json.decode(cached);
    return decoded
        .map((item) => Session.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_cacheKey, encoded);
    await prefs.setInt(
        _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  bool _isCacheExpired() {
    if (_lastUpdated == null) return true;
    final expiration =
        _lastUpdated!.add(const Duration(hours: _cacheExpirationHours));
    return DateTime.now().isAfter(expiration);
  }
}
