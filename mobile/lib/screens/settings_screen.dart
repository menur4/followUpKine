import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/local_calendar_service.dart';
import '../services/ics_calendar_service.dart';
import '../services/practitioner_data_service.dart';
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
  final IcsCalendarService _icsService = IcsCalendarService();
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

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le cache'),
        content: const Text(
          'Cela va supprimer les données mises en cache (sessions, photos des praticiens). '
          'Les paramètres seront conservés. Continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Vider le cache'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);

      try {
        final prefs = await SharedPreferences.getInstance();

        // Supprimer les sessions en cache
        await prefs.remove('cached_sessions');
        await prefs.remove('cached_practitioners');
        await prefs.remove('last_updated');

        // Supprimer les données des praticiens (photos, etc.)
        await prefs.remove('practitioner_data');

        // Supprimer les fichiers photos
        final practitionerDataService = PractitionerDataService();
        final photosDir = await practitionerDataService.getPhotosDirectory();
        final dir = Directory(photosDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }

        if (mounted) {
          // Recharger les sessions
          final provider = context.read<SessionProvider>();
          await provider.loadSessions();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cache vidé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      setState(() => _loading = false);
    }
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

  Future<void> _showBulkPaymentDialog(int year, int count) async {
    final labelController = TextEditingController(
      text: 'Payé le ${DateFormat('dd/MM/yy', 'fr_FR').format(DateTime.now())}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Marquer $year comme payé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous allez marquer $count séance${count > 1 ? 's' : ''} de $year comme payée${count > 1 ? 's' : ''}.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label (optionnel)',
                hintText: 'Ex: Payé le 22/01/26',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<SessionProvider>();
      final sessions = provider.getUnpaidSessionsByYear(year);
      final label = labelController.text.trim().isEmpty
          ? null
          : labelController.text.trim();

      await provider.markMultipleSessionsAsPaid(
        sessions.map((s) => s.id).toList(),
        label: label,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count séance${count > 1 ? 's' : ''} marquée${count > 1 ? 's' : ''} comme payée${count > 1 ? 's' : ''}'),
            backgroundColor: Colors.green,
          ),
        );
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
              'Entrez le motif pour détecter les événements à suivre. '
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

  IconData _getSourceIcon() {
    switch (_appSettings.calendarSourceType) {
      case CalendarSourceType.internal:
        return Icons.phone_android;
      case CalendarSourceType.url:
        return Icons.link;
      case CalendarSourceType.file:
        return Icons.upload_file;
      case CalendarSourceType.none:
        return Icons.calendar_month;
    }
  }

  Future<void> _showChangeSourceDialog() async {
    final result = await showDialog<CalendarSourceType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Source du calendrier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Calendrier du téléphone'),
              subtitle: const Text('Utiliser un calendrier synchronisé'),
              selected: _appSettings.calendarSourceType == CalendarSourceType.internal,
              onTap: () => Navigator.pop(context, CalendarSourceType.internal),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('URL de calendrier'),
              subtitle: const Text('Entrer l\'URL d\'un calendrier ICS'),
              selected: _appSettings.calendarSourceType == CalendarSourceType.url,
              onTap: () => Navigator.pop(context, CalendarSourceType.url),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Fichier ICS'),
              subtitle: const Text('Importer un fichier depuis l\'appareil'),
              selected: _appSettings.calendarSourceType == CalendarSourceType.file,
              onTap: () => Navigator.pop(context, CalendarSourceType.file),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (result != null && result != _appSettings.calendarSourceType) {
      await _handleSourceTypeChange(result);
    }
  }

  Future<void> _handleSourceTypeChange(CalendarSourceType newType) async {
    switch (newType) {
      case CalendarSourceType.internal:
        // Demander la permission et sélectionner un calendrier
        setState(() => _loading = true);
        try {
          final status = await Permission.calendarFullAccess.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permission calendrier refusée'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            setState(() => _loading = false);
            return;
          }

          final calendars = await _calendarService.getCalendars();
          setState(() => _loading = false);

          if (!mounted) return;

          if (calendars.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Aucun calendrier trouvé'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CalendarSelectionScreen(
                calendars: calendars,
                preselectedCalendarId: _appSettings.selectedCalendarId,
                onSelectionConfirmed: (calendarId, calendarName) async {
                  await _settingsService.saveSettings(_appSettings.copyWith(
                    calendarSourceType: CalendarSourceType.internal,
                    selectedCalendarId: calendarId,
                    selectedCalendarName: calendarName,
                    clearIcsUrl: true,
                    clearIcsFilePath: true,
                  ));
                  await _loadSettings();

                  if (mounted) {
                    Navigator.pop(context);
                    final provider = context.read<SessionProvider>();
                    await provider.loadSessions();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Source de calendrier mise à jour'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ),
          );
        } catch (e) {
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;

      case CalendarSourceType.url:
        await _editIcsUrl();
        break;

      case CalendarSourceType.file:
        await _changeIcsFile();
        break;

      case CalendarSourceType.none:
        break;
    }
  }

  Future<void> _editIcsUrl() async {
    final controller = TextEditingController(text: _appSettings.icsUrl ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('URL du calendrier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entrez l\'URL de votre calendrier ICS.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/calendar.ics',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _loading = true);

      try {
        // Tester l'URL
        await _icsService.fetchFromUrl(result, _appSettings.eventPattern);

        await _settingsService.saveSettings(_appSettings.copyWith(
          calendarSourceType: CalendarSourceType.url,
          icsUrl: result,
          clearCalendarId: true,
          clearIcsFilePath: true,
        ));
        await _loadSettings();

        if (mounted) {
          final provider = context.read<SessionProvider>();
          await provider.loadSessions();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('URL du calendrier mise à jour'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible d\'accéder au calendrier: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      setState(() => _loading = false);
    }
  }

  Future<void> _changeIcsFile() async {
    setState(() => _loading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;

        // Copier le fichier dans le répertoire de l'app
        final appDir = await getApplicationDocumentsDirectory();
        final destPath = '${appDir.path}/calendar.ics';
        await File(sourcePath).copy(destPath);

        await _settingsService.saveSettings(_appSettings.copyWith(
          calendarSourceType: CalendarSourceType.file,
          icsFilePath: destPath,
          clearCalendarId: true,
          clearIcsUrl: true,
        ));
        await _loadSettings();

        if (mounted) {
          final provider = context.read<SessionProvider>();
          await provider.loadSessions();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fichier ICS importé'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'importation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _loading = false);
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
                // Section Source calendrier
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Source du calendrier',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(_getSourceIcon()),
                  title: const Text('Type de source'),
                  subtitle: Text(
                    _appSettings.calendarSourceDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showChangeSourceDialog,
                ),
                if (_appSettings.calendarSourceType == CalendarSourceType.internal)
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
                if (_appSettings.calendarSourceType == CalendarSourceType.url)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('URL du calendrier'),
                    subtitle: Text(
                      _appSettings.icsUrl ?? 'Non configuré',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: _editIcsUrl,
                  ),
                if (_appSettings.calendarSourceType == CalendarSourceType.file)
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('Fichier ICS'),
                    subtitle: Text(
                      _appSettings.icsFilePath?.split('/').last ?? 'Non configuré',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: _changeIcsFile,
                  ),
                const Divider(),

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
                  leading: const Icon(Icons.cleaning_services, color: Colors.blue),
                  title: const Text('Vider le cache'),
                  subtitle: const Text('Supprimer les données temporaires'),
                  onTap: _clearCache,
                ),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.orange),
                  title: const Text('Réinitialiser la configuration'),
                  subtitle: const Text('Relancer la sélection des praticiens'),
                  onTap: _resetSetup,
                ),
                const Divider(),

                // Section Paiements en masse
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Paiements en masse',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Consumer<SessionProvider>(
                  builder: (context, provider, _) {
                    final unpaid2025 = provider.getUnpaidSessionsByYear(2025);
                    final unpaid2026 = provider.getUnpaidSessionsByYear(2026);

                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: const Text('Marquer 2025 comme payé'),
                          subtitle: Text(
                            unpaid2025.isEmpty
                                ? 'Toutes les séances 2025 sont payées'
                                : '${unpaid2025.length} séance${unpaid2025.length > 1 ? 's' : ''} non payée${unpaid2025.length > 1 ? 's' : ''}',
                          ),
                          trailing: unpaid2025.isEmpty
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          enabled: unpaid2025.isNotEmpty,
                          onTap: unpaid2025.isEmpty
                              ? null
                              : () => _showBulkPaymentDialog(2025, unpaid2025.length),
                        ),
                        ListTile(
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                          title: const Text('Marquer 2026 comme payé'),
                          subtitle: Text(
                            unpaid2026.isEmpty
                                ? 'Toutes les séances 2026 sont payées'
                                : '${unpaid2026.length} séance${unpaid2026.length > 1 ? 's' : ''} non payée${unpaid2026.length > 1 ? 's' : ''}',
                          ),
                          trailing: unpaid2026.isEmpty
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          enabled: unpaid2026.isNotEmpty,
                          onTap: unpaid2026.isEmpty
                              ? null
                              : () => _showBulkPaymentDialog(2026, unpaid2026.length),
                        ),
                      ],
                    );
                  },
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
