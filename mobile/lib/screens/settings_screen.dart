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
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
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

    HapticService.mediumImpact();
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
                  backgroundColor: AppColors.success,
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
                    backgroundColor: AppColors.success,
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Vider le cache'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticService.warning();
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
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: AppColors.error,
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
      HapticService.warning();
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
              style: const TextStyle(color: AppColors.textSecondaryLight),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticService.success();
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
            backgroundColor: AppColors.success,
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
              style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight),
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
            backgroundColor: AppColors.success,
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
                  backgroundColor: AppColors.error,
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
                backgroundColor: AppColors.warning,
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
                        backgroundColor: AppColors.success,
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
                backgroundColor: AppColors.error,
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
              style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight),
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
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible d\'accéder au calendrier: $e'),
              backgroundColor: AppColors.error,
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
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'importation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: AppSpacing.sm),

                // Section Source calendrier
                _SettingsSection(
                  header: 'SOURCE DU CALENDRIER',
                  footer: 'Sélectionnez la source de vos événements de calendrier.',
                  children: [
                    _SettingsTile(
                      icon: _getSourceIcon(),
                      title: 'Type de source',
                      subtitle: _appSettings.calendarSourceDescription,
                      trailing: _SettingsChevron(),
                      onTap: _showChangeSourceDialog,
                    ),
                    if (_appSettings.calendarSourceType == CalendarSourceType.internal)
                      _SettingsTile(
                        icon: Icons.calendar_month,
                        title: 'Calendrier',
                        subtitle: _appSettings.selectedCalendarName ?? 'Tous les calendriers',
                        trailing: _SettingsChevron(),
                        onTap: _changeCalendar,
                        showDivider: false,
                      ),
                    if (_appSettings.calendarSourceType == CalendarSourceType.url)
                      _SettingsTile(
                        icon: Icons.link,
                        title: 'URL du calendrier',
                        subtitle: _appSettings.icsUrl ?? 'Non configuré',
                        trailing: _SettingsChevron(),
                        onTap: _editIcsUrl,
                        showDivider: false,
                      ),
                    if (_appSettings.calendarSourceType == CalendarSourceType.file)
                      _SettingsTile(
                        icon: Icons.upload_file,
                        title: 'Fichier ICS',
                        subtitle: _appSettings.icsFilePath?.split('/').last ?? 'Non configuré',
                        trailing: _SettingsChevron(),
                        onTap: _changeIcsFile,
                        showDivider: false,
                      ),
                  ],
                ),

                // Section Filtres
                _SettingsSection(
                  header: 'FILTRES',
                  footer: 'Configurez les praticiens et le motif de recherche pour filtrer vos séances.',
                  children: [
                    _SettingsTile(
                      icon: Icons.person,
                      title: 'Praticiens suivis',
                      subtitle: _appSettings.selectedPractitioners.isEmpty
                          ? 'Aucun praticien sélectionné'
                          : _appSettings.selectedPractitioners.join(', '),
                      trailing: _SettingsChevron(),
                      onTap: _changePractitioners,
                    ),
                    _SettingsTile(
                      icon: Icons.text_fields,
                      title: 'Motif des événements',
                      subtitle: _appSettings.eventPattern,
                      trailing: _SettingsChevron(),
                      onTap: _editEventPattern,
                      showDivider: false,
                    ),
                  ],
                ),

                // Section Paiements en masse
                Consumer<SessionProvider>(
                  builder: (context, provider, _) {
                    final unpaid2025 = provider.getUnpaidSessionsByYear(2025);
                    final unpaid2026 = provider.getUnpaidSessionsByYear(2026);

                    return _SettingsSection(
                      header: 'PAIEMENTS EN MASSE',
                      footer: 'Marquez rapidement toutes les séances d\'une année comme payées.',
                      children: [
                        _SettingsTile(
                          icon: Icons.check_circle,
                          iconColor: AppColors.success,
                          title: 'Marquer 2025 comme payé',
                          subtitle: unpaid2025.isEmpty
                              ? 'Toutes les séances sont payées'
                              : '${unpaid2025.length} séance${unpaid2025.length > 1 ? 's' : ''} en attente',
                          trailing: unpaid2025.isEmpty
                              ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
                              : null,
                          enabled: unpaid2025.isNotEmpty,
                          onTap: unpaid2025.isEmpty
                              ? null
                              : () => _showBulkPaymentDialog(2025, unpaid2025.length),
                        ),
                        _SettingsTile(
                          icon: Icons.check_circle,
                          iconColor: AppColors.success,
                          title: 'Marquer 2026 comme payé',
                          subtitle: unpaid2026.isEmpty
                              ? 'Toutes les séances sont payées'
                              : '${unpaid2026.length} séance${unpaid2026.length > 1 ? 's' : ''} en attente',
                          trailing: unpaid2026.isEmpty
                              ? Icon(Icons.check_circle, color: AppColors.success, size: 20)
                              : null,
                          enabled: unpaid2026.isNotEmpty,
                          onTap: unpaid2026.isEmpty
                              ? null
                              : () => _showBulkPaymentDialog(2026, unpaid2026.length),
                          showDivider: false,
                        ),
                      ],
                    );
                  },
                ),

                // Section Sécurité
                _SettingsSection(
                  header: 'SÉCURITÉ',
                  footer: _biometricAvailable
                      ? 'Protégez l\'accès à vos données avec Face ID ou votre empreinte digitale.'
                      : 'L\'authentification biométrique n\'est pas configurée sur cet appareil.',
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.fingerprint,
                      title: 'Authentification biométrique',
                      subtitle: _biometricAvailable
                          ? 'Face ID ou empreinte digitale'
                          : 'Non disponible',
                      value: _biometricEnabled,
                      onChanged: _biometricAvailable ? _toggleBiometric : null,
                      showDivider: false,
                    ),
                  ],
                ),

                // Section Données (actions potentiellement destructives)
                _SettingsSection(
                  header: 'DONNÉES',
                  children: [
                    _SettingsTile(
                      icon: Icons.cached,
                      title: 'Vider le cache',
                      subtitle: 'Supprimer les données temporaires',
                      onTap: _clearCache,
                    ),
                    _SettingsTile(
                      icon: Icons.restart_alt,
                      iconColor: AppColors.error,
                      title: 'Réinitialiser',
                      titleColor: AppColors.error,
                      subtitle: 'Effacer les paramètres et recommencer',
                      onTap: _resetSetup,
                      showDivider: false,
                    ),
                  ],
                ),

                // Espace en bas
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }
}

/// Section groupée style iOS avec coins arrondis
class _SettingsSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  const _SettingsSection({
    this.header,
    this.footer,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                header!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: children,
              ),
            ),
          ),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                footer!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tuile de paramètre style iOS
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;
    final effectiveTitleColor = titleColor ?? theme.colorScheme.onSurface;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: effectiveIconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: enabled
                          ? effectiveIconColor
                          : effectiveIconColor.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: enabled
                                ? effectiveTitleColor
                                : effectiveTitleColor.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: enabled ? 0.6 : 0.4,
                            ),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: Divider(height: 1, thickness: 0.5),
          ),
      ],
    );
  }
}

/// Switch tile style iOS
class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => onChanged!(!value) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: enabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: enabled
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: enabled ? 0.6 : 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: Divider(height: 1, thickness: 0.5),
          ),
      ],
    );
  }
}

/// Chevron de navigation style iOS
class _SettingsChevron extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right,
      size: 20,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
    );
  }
}
