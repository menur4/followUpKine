import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import '../services/ics_calendar_service.dart';
import '../services/local_calendar_service.dart';
import '../services/settings_service.dart';
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Importer un calendrier ICS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comment souhaitez-vous importer votre calendrier ?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              _IcsOptionTile(
                icon: Icons.upload_file,
                title: 'Depuis un fichier',
                subtitle: 'Sélectionner un fichier .ics',
                onTap: () {
                  Navigator.pop(context);
                  _selectIcsFile();
                },
              ),
              const SizedBox(height: 12),
              _IcsOptionTile(
                icon: Icons.link,
                title: 'Depuis une URL',
                subtitle: 'Entrer l\'adresse web du calendrier',
                onTap: () {
                  Navigator.pop(context);
                  _goToStep(1);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceSelection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // Logo/Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),

          const SizedBox(height: 32),

          const Center(
            child: Text(
              'Bienvenue !',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              'Choisissez la source de votre calendrier',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 48),

          // Option 1: Calendrier du téléphone
          _SourceOption(
            icon: Icons.smartphone,
            title: 'Calendrier du téléphone',
            subtitle: 'Utiliser un calendrier synchronisé sur votre appareil',
            onTap: _selectInternalCalendar,
          ),

          const SizedBox(height: 16),

          // Option 2: Fichier ICS (fichier ou URL)
          _SourceOption(
            icon: Icons.event_note,
            title: 'Fichier ICS',
            subtitle: 'Importer depuis un fichier ou une URL',
            onTap: _showIcsOptions,
          ),

          if (_error != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _goToStep(0),
          ),

          const SizedBox(height: 24),

          const Text(
            'URL du calendrier',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Entrez l\'URL de votre calendrier ICS',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 32),

          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL du calendrier',
              hintText: 'https://example.com/calendar.ics',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _validateUrl,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Continuer'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternInput() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _goToStep(0),
          ),

          const SizedBox(height: 24),

          const Text(
            'Motif des événements',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Entrez le texte qui permet d\'identifier vos rendez-vous. '
            'Utilisez | pour séparer plusieurs motifs.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 32),

          TextField(
            controller: _patternController,
            decoration: const InputDecoration(
              labelText: 'Motif de recherche',
              hintText: 'rdv chez|rendez-vous chez',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              helperText: 'Exemple: "rdv chez Dr Martin" sera détecté avec le motif "rdv chez"',
              helperMaxLines: 2,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _discoverPractitioners,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Rechercher les praticiens'),
              ),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
