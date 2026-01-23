import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import '../services/ics_calendar_service.dart';
import '../services/local_calendar_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import 'calendar_selection_screen.dart';
import 'practitioner_selection_screen.dart';

class CalendarSourceScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const CalendarSourceScreen({
    super.key,
    required this.onSetupComplete,
  });

  @override
  State<CalendarSourceScreen> createState() => _CalendarSourceScreenState();
}

class _CalendarSourceScreenState extends State<CalendarSourceScreen> {
  final SettingsService _settingsService = SettingsService();
  final IcsCalendarService _icsService = IcsCalendarService();
  final LocalCalendarService _calendarService = LocalCalendarService();

  bool _loading = false;
  String? _error;
  int _currentStep = 0;

  // Step 0: Choose source type
  // Step 1: Configure source (URL input, file selection, or calendar selection)
  // Step 2: Configure event pattern
  // Step 3: Select practitioners

  final _urlController = TextEditingController();
  final _patternController = TextEditingController(text: AppSettings.defaultPattern);

  CalendarSourceType? _selectedSourceType;
  String? _selectedCalendarId;
  String? _selectedCalendarName;
  String? _icsFilePath;
  Map<String, int> _discoveredPractitioners = {};
  List<String> _selectedPractitioners = [];

  @override
  void dispose() {
    _urlController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _selectInternalCalendar() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Demander la permission calendrier
      final status = await Permission.calendarFullAccess.request();

      if (!status.isGranted) {
        setState(() {
          _error = 'Permission calendrier refusée';
          _loading = false;
        });
        return;
      }

      // Récupérer les calendriers
      final calendars = await _calendarService.getCalendars();

      if (!mounted) return;
      setState(() => _loading = false);

      if (calendars.isEmpty) {
        setState(() {
          _error = 'Aucun calendrier trouvé';
        });
        return;
      }

      // Afficher l'écran de sélection de calendrier
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CalendarSelectionScreen(
            calendars: calendars,
            onSelectionConfirmed: (calendarId, calendarName) {
              setState(() {
                _selectedCalendarId = calendarId;
                _selectedCalendarName = calendarName;
                _selectedSourceType = CalendarSourceType.internal;
              });
              Navigator.pop(context);
              _goToStep(2); // Aller à la configuration du pattern
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _loading = false;
      });
    }
  }

  Future<void> _selectIcsFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
      );

      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;

        // Copier le fichier dans le répertoire de l'app pour persistance
        final appDir = await getApplicationDocumentsDirectory();
        final destPath = '${appDir.path}/calendar.ics';
        await File(sourcePath).copy(destPath);

        setState(() {
          _icsFilePath = destPath;
          _selectedSourceType = CalendarSourceType.file;
          _loading = false;
        });

        _goToStep(2); // Aller à la configuration du pattern
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la sélection du fichier: $e';
        _loading = false;
      });
    }
  }

  Future<void> _validateUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Veuillez entrer une URL');
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _error = 'L\'URL doit commencer par http:// ou https://');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Tester l'URL en récupérant le contenu
      await _icsService.fetchFromUrl(url, _patternController.text);

      setState(() {
        _selectedSourceType = CalendarSourceType.url;
        _loading = false;
      });

      _goToStep(2); // Aller à la configuration du pattern
    } catch (e) {
      setState(() {
        _error = 'Impossible d\'accéder au calendrier: $e';
        _loading = false;
      });
    }
  }

  Future<void> _discoverPractitioners() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pattern = _patternController.text.trim();
      if (pattern.isEmpty) {
        setState(() {
          _error = 'Veuillez entrer un motif de recherche';
          _loading = false;
        });
        return;
      }

      Map<String, int> practitioners = {};

      switch (_selectedSourceType) {
        case CalendarSourceType.internal:
          practitioners = await _calendarService.discoverPractitioners(
            startDate: DateTime(2025, 3, 1),
            endDate: DateTime(2026, 12, 31),
            eventPattern: pattern,
            calendarId: _selectedCalendarId,
          );
          break;

        case CalendarSourceType.url:
          final sessions = await _icsService.fetchFromUrl(
            _urlController.text.trim(),
            pattern,
          );
          practitioners = _icsService.extractPractitioners(sessions);
          break;

        case CalendarSourceType.file:
          if (_icsFilePath != null) {
            final sessions = await _icsService.parseFromFile(
              File(_icsFilePath!),
              pattern,
            );
            practitioners = _icsService.extractPractitioners(sessions);
          }
          break;

        default:
          break;
      }

      if (practitioners.isEmpty) {
        setState(() {
          _error = 'Aucun praticien trouvé avec ce motif';
          _loading = false;
        });
        return;
      }

      setState(() {
        _discoveredPractitioners = practitioners;
        _selectedPractitioners = practitioners.keys.toList();
        _loading = false;
      });

      _goToStep(3); // Aller à la sélection des praticiens
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la recherche: $e';
        _loading = false;
      });
    }
  }

  Future<void> _finishSetup() async {
    HapticService.success();
    setState(() => _loading = true);

    try {
      // Sauvegarder les paramètres
      final settings = AppSettings(
        eventPattern: _patternController.text.trim(),
        calendarSourceType: _selectedSourceType!,
        selectedCalendarId: _selectedCalendarId,
        selectedCalendarName: _selectedCalendarName,
        icsUrl: _selectedSourceType == CalendarSourceType.url
            ? _urlController.text.trim()
            : null,
        icsFilePath: _icsFilePath,
        selectedPractitioners: _selectedPractitioners,
        hasCompletedSetup: true,
      );

      await _settingsService.saveSettings(settings);

      widget.onSetupComplete();
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la sauvegarde: $e';
        _loading = false;
      });
    }
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildSourceSelection();
      case 1:
        return _buildUrlInput();
      case 2:
        return _buildPatternInput();
      case 3:
        return _buildPractitionerSelection();
      default:
        return _buildSourceSelection();
    }
  }

  void _showIcsOptions() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Importer un calendrier ICS',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Comment souhaitez-vous importer votre calendrier ?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _IcsOptionTile(
                icon: Icons.upload_file,
                title: 'Depuis un fichier',
                subtitle: 'Sélectionner un fichier .ics',
                onTap: () {
                  Navigator.pop(context);
                  _selectIcsFile();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _IcsOptionTile(
                icon: Icons.link,
                title: 'Depuis une URL',
                subtitle: 'Entrer l\'adresse web du calendrier',
                onTap: () {
                  Navigator.pop(context);
                  _goToStep(1);
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceSelection() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xxl),

          // Logo/Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Center(
            child: Text(
              'Bienvenue !',
              style: theme.textTheme.displayMedium,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Center(
            child: Text(
              'Choisissez la source de votre calendrier',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Option 1: Calendrier du téléphone
          _SourceOption(
            icon: Icons.smartphone,
            title: 'Calendrier du téléphone',
            subtitle: 'Utiliser un calendrier synchronisé sur votre appareil',
            onTap: _selectInternalCalendar,
          ),

          const SizedBox(height: AppSpacing.md),

          // Option 2: Fichier ICS (fichier ou URL)
          _SourceOption(
            icon: Icons.event_note,
            title: 'Fichier ICS',
            subtitle: 'Importer depuis un fichier ou une URL',
            onTap: _showIcsOptions,
          ),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.smallRadius),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _goToStep(0),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'URL du calendrier',
            style: theme.textTheme.headlineLarge,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'Entrez l\'URL de votre calendrier ICS',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL du calendrier',
              hintText: 'https://example.com/calendar.ics',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: TextStyle(color: AppColors.error),
            ),
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _validateUrl,
              child: const Text('Continuer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternInput() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _goToStep(0),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Motif des événements',
            style: theme.textTheme.headlineLarge,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'Entrez le texte qui permet d\'identifier vos rendez-vous. '
            'Utilisez | pour séparer plusieurs motifs.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          TextField(
            controller: _patternController,
            decoration: const InputDecoration(
              labelText: 'Motif de recherche',
              hintText: 'rdv chez|rendez-vous chez',
              prefixIcon: Icon(Icons.search),
              helperText: 'Exemple: "rdv chez Dr Martin" sera détecté avec le motif "rdv chez"',
              helperMaxLines: 2,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: TextStyle(color: AppColors.error),
            ),
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _discoverPractitioners,
              child: const Text('Rechercher les praticiens'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPractitionerSelection() {
    return PractitionerSelectionScreen(
      discoveredPractitioners: _discoveredPractitioners,
      preselectedPractitioners: _selectedPractitioners,
      onSelectionConfirmed: (selected) {
        setState(() {
          _selectedPractitioners = selected;
        });
        _finishSetup();
      },
      showBackButton: true,
      onBack: () => _goToStep(2),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IcsOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _IcsOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
