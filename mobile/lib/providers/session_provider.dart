import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../models/app_settings.dart';
import '../services/local_calendar_service.dart';
import '../services/settings_service.dart';

class SessionProvider extends ChangeNotifier {
  final LocalCalendarService _calendarService = LocalCalendarService();
  final SettingsService _settingsService = SettingsService();

  List<Session> _sessions = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastUpdated;
  bool _permissionDenied = false;
  AppSettings _settings = AppSettings.defaults();
  bool _needsPractitionerSelection = false;
  Map<String, int> _discoveredPractitioners = {};

  static const String _cacheKey = 'kine_sessions_cache';
  static const String _cacheTimestampKey = 'kine_sessions_cache_timestamp';
  static const int _cacheExpirationMinutes = 60; // 1 heure

  List<Session> get sessions => _sessions;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;
  bool get permissionDenied => _permissionDenied;
  AppSettings get settings => _settings;
  bool get needsPractitionerSelection => _needsPractitionerSelection;
  Map<String, int> get discoveredPractitioners => _discoveredPractitioners;

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
    final practitioners = _settings.selectedPractitioners;

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
      final monthData = <String, int>{};
      for (final p in practitioners) {
        monthData[p.toLowerCase()] = 0;
      }
      statsByMonth[key] = monthData;
      current = DateTime(current.year, current.month + 1, 1);
    }

    // Compter les séances par mois
    for (final session in _sessions) {
      final key =
          '${session.date.year}-${session.date.month.toString().padLeft(2, '0')}';
      if (statsByMonth.containsKey(key)) {
        for (final p in practitioners) {
          if (session.practitioner.toLowerCase().contains(p.toLowerCase())) {
            statsByMonth[key]![p.toLowerCase()] =
                (statsByMonth[key]![p.toLowerCase()] ?? 0) + 1;
            break;
          }
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

      final countByPractitioner = <String, int>{};
      int total = 0;
      for (final p in practitioners) {
        final count = statsByMonth[key]![p.toLowerCase()] ?? 0;
        countByPractitioner[p] = count;
        total += count;
      }

      return MonthlyStats(
        month: monthFormat.format(date),
        sortKey: year * 100 + month,
        countByPractitioner: countByPractitioner,
        total: total,
      );
    }).toList();
  }

  List<PractitionerStats> get practitionerStats {
    final practitioners = _settings.selectedPractitioners;
    final counts = <String, int>{};

    for (final p in practitioners) {
      counts[p] = 0;
    }

    for (final session in _sessions) {
      for (final p in practitioners) {
        if (session.practitioner.toLowerCase().contains(p.toLowerCase())) {
          counts[p] = (counts[p] ?? 0) + 1;
          break;
        }
      }
    }

    final total = counts.values.fold(0, (sum, count) => sum + count);
    if (total == 0) return [];

    return practitioners.map((p) {
      final count = counts[p] ?? 0;
      return PractitionerStats(
        name: p,
        count: count,
        percentage: (count / total) * 100,
      );
    }).toList();
  }

  Future<void> loadSessions() async {
    _loading = true;
    _error = null;
    _permissionDenied = false;
    _needsPractitionerSelection = false;
    notifyListeners();

    try {
      // Charger les paramètres
      _settings = await _settingsService.loadSettings();
      debugPrint('Settings loaded: hasCompletedSetup=${_settings.hasCompletedSetup}');
      debugPrint('Selected practitioners: ${_settings.selectedPractitioners}');

      // Si le setup est complété, essayer de charger depuis le cache
      if (_settings.hasCompletedSetup) {
        final cached = await _loadFromCache();
        if (cached != null && cached.isNotEmpty) {
          _sessions = cached;
          _loading = false;
          notifyListeners();

          // Rafraîchir en arrière-plan si le cache est expiré
          if (_isCacheExpired()) {
            _refreshInBackground();
          }
          return;
        }
      }

      // Vérifier les permissions
      final hasPermission = await _calendarService.hasPermissions();
      if (!hasPermission) {
        final granted = await _calendarService.requestPermissions();
        if (!granted) {
          _permissionDenied = true;
          _error = 'Permission d\'accès au calendrier refusée';
          _loading = false;
          notifyListeners();
          return;
        }
      }

      // Si le setup n'est pas complété, déclencher la découverte des praticiens
      if (!_settings.hasCompletedSetup) {
        await _discoverPractitioners();
        return;
      }

      // Charger depuis le calendrier local
      await _fetchFromCalendar();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading sessions: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Découvrir les praticiens dans le calendrier
  Future<void> _discoverPractitioners() async {
    final startDate = DateTime(2025, 3, 1);
    final endDate = DateTime(2026, 12, 31);

    debugPrint('Discovering practitioners...');
    _discoveredPractitioners = await _calendarService.discoverPractitioners(
      startDate: startDate,
      endDate: endDate,
      eventPattern: _settings.eventPattern,
      calendarId: _settings.selectedCalendarId,
    );

    debugPrint('Found ${_discoveredPractitioners.length} practitioners');
    _needsPractitionerSelection = true;
    _loading = false;
    notifyListeners();
  }

  /// Confirmer la sélection des praticiens et charger les sessions
  Future<void> confirmPractitionerSelection(List<String> selectedPractitioners) async {
    _loading = true;
    _needsPractitionerSelection = false;
    notifyListeners();

    try {
      // Sauvegarder les praticiens sélectionnés
      await _settingsService.updateSelectedPractitioners(selectedPractitioners);
      _settings = await _settingsService.loadSettings();

      // Charger les sessions
      await _fetchFromCalendar();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error confirming selection: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Déclencher une nouvelle découverte des praticiens (depuis les paramètres)
  Future<void> rediscoverPractitioners() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _discoverPractitioners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error rediscovering practitioners: $e');
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _refreshing = true;
    _error = null;
    notifyListeners();

    try {
      await _fetchFromCalendar();
    } catch (e) {
      _error = e.toString();
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> _fetchFromCalendar() async {
    final startDate = DateTime(2025, 3, 1);
    final endDate = DateTime(2026, 12, 31);

    _sessions = await _calendarService.fetchSessions(
      startDate,
      endDate,
      settings: _settings,
    );

    _lastUpdated = DateTime.now();
    await _saveToCache();
  }

  Future<void> _refreshInBackground() async {
    _refreshing = true;
    notifyListeners();

    try {
      await _fetchFromCalendar();
    } catch (e) {
      debugPrint('Background refresh failed: $e');
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
        _lastUpdated!.add(const Duration(minutes: _cacheExpirationMinutes));
    return DateTime.now().isAfter(expiration);
  }

  /// Request calendar permissions manually
  Future<bool> requestCalendarPermission() async {
    final granted = await _calendarService.requestPermissions();
    if (granted) {
      _permissionDenied = false;
      notifyListeners();
      await loadSessions();
    }
    return granted;
  }
}
