import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const String _settingsKey = 'app_settings';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);

    if (jsonString == null) {
      return AppSettings.defaults();
    }

    try {
      return AppSettings.fromJsonString(jsonString);
    } catch (e) {
      return AppSettings.defaults();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, settings.toJsonString());
  }

  Future<void> updateEventPattern(String pattern) async {
    final settings = await loadSettings();
    await saveSettings(settings.copyWith(eventPattern: pattern));
  }

  Future<void> updateSelectedCalendar(String? calendarId, String? calendarName) async {
    final settings = await loadSettings();
    await saveSettings(settings.copyWith(
      selectedCalendarId: calendarId,
      selectedCalendarName: calendarName,
    ));
  }

  Future<void> updateSelectedPractitioners(List<String> practitioners) async {
    final settings = await loadSettings();
    await saveSettings(settings.copyWith(
      selectedPractitioners: practitioners,
      hasCompletedSetup: true,
    ));
  }

  Future<void> markSetupCompleted() async {
    final settings = await loadSettings();
    await saveSettings(settings.copyWith(hasCompletedSetup: true));
  }

  Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
  }
}
