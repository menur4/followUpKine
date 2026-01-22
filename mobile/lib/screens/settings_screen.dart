import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/local_calendar_service.dart';
import '../models/app_settings.dart';
import '../providers/session_provider.dart';
import 'calendar_selection_screen.dart';
import 'practitioner_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final SettingsService _settingsService = SettingsService();
  final LocalCalendarService _calendarService = LocalCalendarService();
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _loading = true;
  AppSettings _appSettings = AppSettings.defaults();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final available = await _authService.isBiometricAvailable();
    final enabled = await _authService.isBiometricEnabled();
    final appSettings = await _settingsService.loadSettings();

    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _appSettings = appSettings;
      _loading = false;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Test authentication before enabling
      final authenticated = await _authService.authenticate();
      if (!authenticated) {
        return;
      }
    }

    await _authService.setBiometricEnabled(value);
    setState(() {
      _biometricEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Authentification biométrique activée'
                : 'Authentification biométrique désactivée',
          ),
        ),
      );
    }
  }

  Future<void> _changeCalendar() async {
    setState(() => _loading = true);

    final calendars = await _calendarService.getCalendars();

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarSelectionScreen(
          calendars: calendars,
          preselectedCalendarId: _appSettings.selectedCalendarId,
          onSelectionConfirmed: (calendarId, calendarName) async {
            await _settingsService.updateSelectedCalendar(calendarId, calendarName);
            await _loadSettings();

            if (mounted) {
              Navigator.pop(context);
              // Recharger les sessions avec le nouveau calendrier
              final provider = context.read<SessionProvider>();
              await provider.loadSessions();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calendrier mis à jour'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _changePractitioners() async {
    final provider = context.read<SessionProvider>();
    await provider.rediscoverPractitioners();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: PractitionerSelectionScreen(
            discoveredPractitioners: provider.discoveredPractitioners,
            preselectedPractitioners: _appSettings.selectedPractitioners,
            onSelectionConfirmed: (selected) async {
              await provider.confirmPractitionerSelection(selected);
              if (mounted) {
                Navigator.pop(context);
                _loadSettings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Praticiens mis à jour'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _resetSetup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser'),
        content: const Text(
          'Cela va effacer vos paramètres et relancer la sélection des praticiens. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _settingsService.resetSettings();

      if (mounted) {
        final provider = context.read<SessionProvider>();
        await provider.loadSessions();
        Navigator.pop(context);
      }
    }
  }

  Future<void> _editEventPattern() async {
    final controller = TextEditingController(text: _appSettings.eventPattern);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motif des événements'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entrez le motif pour détecter les événements de kiné. '
              'Utilisez | pour séparer plusieurs motifs.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'rdv chez|rendez-vous chez',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _settingsService.updateEventPattern(result);
      await _loadSettings();

      if (mounted) {
        final provider = context.read<SessionProvider>();
        await provider.loadSessions();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Motif mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Section Filtres
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Filtres',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Calendrier'),
                  subtitle: Text(
                    _appSettings.selectedCalendarName ?? 'Tous les calendriers',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changeCalendar,
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Praticiens suivis'),
                  subtitle: Text(
                    _appSettings.selectedPractitioners.isEmpty
                        ? 'Aucun praticien sélectionné'
                        : _appSettings.selectedPractitioners.join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePractitioners,
                ),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('Motif des événements'),
                  subtitle: Text(
                    _appSettings.eventPattern,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: _editEventPattern,
                ),
                const Divider(),

                // Section Données
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Données',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.orange),
                  title: const Text('Réinitialiser la configuration'),
                  subtitle: const Text('Relancer la sélection des praticiens'),
                  onTap: _resetSetup,
                ),
                const Divider(),

                // Section Sécurité
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Sécurité',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Authentification biométrique'),
                  subtitle: Text(
                    _biometricAvailable
                        ? 'Utiliser Face ID ou empreinte digitale'
                        : 'Non disponible sur cet appareil',
                  ),
                  value: _biometricEnabled,
                  onChanged: _biometricAvailable ? _toggleBiometric : null,
                  secondary: Icon(
                    Icons.fingerprint,
                    color: _biometricAvailable ? null : Colors.grey,
                  ),
                ),
                if (!_biometricAvailable)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'L\'authentification biométrique n\'est pas configurée sur cet appareil.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
