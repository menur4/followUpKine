import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/session.dart';
import '../models/practitioner_data.dart';
import '../services/practitioner_data_service.dart';
import 'action_sheets.dart';

class PractitionerInfo {
  final String name;
  final int totalSessions;
  final int paidSessions;
  final int unpaidSessions;
  final String? commonLocation;
  final String? commonTime;
  final DateTime? lastSessionDate;
  final DateTime? nextSessionDate;

  PractitionerInfo({
    required this.name,
    required this.totalSessions,
    required this.paidSessions,
    required this.unpaidSessions,
    this.commonLocation,
    this.commonTime,
    this.lastSessionDate,
    this.nextSessionDate,
  });

  double get paidPercentage => totalSessions > 0 ? (paidSessions / totalSessions) * 100 : 0;
}

class PractitionersCarousel extends StatefulWidget {
  final List<Session> sessions;
  final List<String> practitioners;
  final DateTime? lastUpdated;

  const PractitionersCarousel({
    super.key,
    required this.sessions,
    required this.practitioners,
    this.lastUpdated,
  });

  @override
  State<PractitionersCarousel> createState() => _PractitionersCarouselState();
}

class _PractitionersCarouselState extends State<PractitionersCarousel> {
  final PageController _pageController = PageController();
  final PractitionerDataService _dataService = PractitionerDataService();
  int _currentPage = 0;
  Map<String, PractitionerData> _practitionerData = {};
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadPractitionerData();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPractitionerData() async {
    final data = await _dataService.load();
    if (mounted) {
      setState(() {
        _practitionerData = data;
      });
    }
  }

  List<PractitionerInfo> _buildPractitionerInfos() {
    return widget.practitioners.map((practitioner) {
      final practitionerSessions = widget.sessions
          .where((s) => s.practitioner == practitioner)
          .toList();

      final pastSessions = practitionerSessions.where((s) => !s.isFuture).toList();
      final futureSessions = practitionerSessions.where((s) => s.isFuture).toList();

      final paidCount = pastSessions.where((s) => s.paid).length;
      final unpaidCount = pastSessions.where((s) => !s.paid).length;

      // Trouver le lieu le plus commun
      final locationCounts = <String, int>{};
      for (final session in practitionerSessions) {
        if (session.location != null && session.location!.isNotEmpty) {
          locationCounts[session.location!] = (locationCounts[session.location!] ?? 0) + 1;
        }
      }
      String? commonLocation;
      if (locationCounts.isNotEmpty) {
        commonLocation = locationCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      // Trouver l'horaire le plus commun
      final timeCounts = <String, int>{};
      for (final session in practitionerSessions) {
        if (session.time != null && session.time!.isNotEmpty) {
          timeCounts[session.time!] = (timeCounts[session.time!] ?? 0) + 1;
        }
      }
      String? commonTime;
      if (timeCounts.isNotEmpty) {
        commonTime = timeCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }

      // Dernière séance passée
      DateTime? lastSessionDate;
      if (pastSessions.isNotEmpty) {
        pastSessions.sort((a, b) => b.date.compareTo(a.date));
        lastSessionDate = pastSessions.first.date;
      }

      // Prochaine séance
      DateTime? nextSessionDate;
      if (futureSessions.isNotEmpty) {
        futureSessions.sort((a, b) => a.date.compareTo(b.date));
        nextSessionDate = futureSessions.first.date;
      }

      return PractitionerInfo(
        name: practitioner,
        totalSessions: practitionerSessions.length,
        paidSessions: paidCount,
        unpaidSessions: unpaidCount,
        commonLocation: commonLocation,
        commonTime: commonTime,
        lastSessionDate: lastSessionDate,
        nextSessionDate: nextSessionDate,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final practitionerInfos = _buildPractitionerInfos();

    if (practitionerInfos.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mes praticiens',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Aucun praticien',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Si un seul praticien, pas de carrousel
    if (practitionerInfos.length == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FlipPractitionerCard(
            info: practitionerInfos.first,
            practitionerData: _practitionerData[practitionerInfos.first.name],
            dataService: _dataService,
            onDataUpdated: _loadPractitionerData,
            isOnly: true,
            lastUpdated: widget.lastUpdated,
          ),
          // Version et date de mise à jour
          const SizedBox(height: 8),
          Text(
            _appVersion.isNotEmpty
                ? (widget.lastUpdated != null
                    ? 'v$_appVersion • Mis à jour le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(widget.lastUpdated!)}'
                    : 'v$_appVersion')
                : (widget.lastUpdated != null
                    ? 'Mis à jour le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(widget.lastUpdated!)}'
                    : ''),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: practitionerInfos.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _FlipPractitionerCard(
                  info: practitionerInfos[index],
                  practitionerData: _practitionerData[practitionerInfos[index].name],
                  dataService: _dataService,
                  onDataUpdated: _loadPractitionerData,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Indicateurs de page
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            practitionerInfos.length,
            (index) => GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        // Version et date de mise à jour
        const SizedBox(height: 8),
        Text(
          _appVersion.isNotEmpty
              ? (widget.lastUpdated != null
                  ? 'v$_appVersion • Mis à jour le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(widget.lastUpdated!)}'
                  : 'v$_appVersion')
              : (widget.lastUpdated != null
                  ? 'Mis à jour le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(widget.lastUpdated!)}'
                  : ''),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _FlipPractitionerCard extends StatefulWidget {
  final PractitionerInfo info;
  final PractitionerData? practitionerData;
  final PractitionerDataService dataService;
  final VoidCallback onDataUpdated;
  final bool isOnly;
  final DateTime? lastUpdated;

  const _FlipPractitionerCard({
    required this.info,
    this.practitionerData,
    required this.dataService,
    required this.onDataUpdated,
    this.isOnly = false,
    this.lastUpdated,
  });

  @override
  State<_FlipPractitionerCard> createState() => _FlipPractitionerCardState();
}

class _FlipPractitionerCardState extends State<_FlipPractitionerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showFront = true;

  // Controllers pour le formulaire d'édition
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;
  String? _currentPhotoPath;
  File? _newPhotoFile;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _initFormControllers();
  }

  void _initFormControllers() {
    _phoneController = TextEditingController(text: widget.practitionerData?.phone ?? '');
    _emailController = TextEditingController(text: widget.practitionerData?.email ?? '');
    _notesController = TextEditingController(text: widget.practitionerData?.notes ?? '');
    _currentPhotoPath = widget.practitionerData?.photoPath;
    _newPhotoFile = null;
  }

  @override
  void didUpdateWidget(_FlipPractitionerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.practitionerData != widget.practitionerData) {
      _initFormControllers();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_showFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _showFront = !_showFront;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final actions = <ActionSheetItem<String>>[
      ActionSheetItem<String>(
        label: 'Appareil photo',
        icon: Icons.camera_alt,
        value: 'camera',
      ),
      ActionSheetItem<String>(
        label: 'Galerie',
        icon: Icons.photo_library,
        value: 'gallery',
      ),
      if (_currentPhotoPath != null)
        ActionSheetItem<String>(
          label: 'Supprimer la photo',
          icon: Icons.delete,
          isDestructive: true,
          value: 'delete',
        ),
    ];

    final result = await ActionSheets.show<String>(
      context: context,
      title: 'Choisir une photo',
      actions: actions,
      cancelAction: ActionSheetItem<String>(
        label: 'Annuler',
        value: 'cancel',
      ),
    );

    if (result == 'delete') {
      setState(() {
        _currentPhotoPath = null;
        _newPhotoFile = null;
      });
      return;
    }

    if (result == 'camera' || result == 'gallery') {
      final source = result == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _newPhotoFile = File(image.path);
          _currentPhotoPath = image.path;
        });
      }
    }
  }

  Future<void> _saveAndFlipBack() async {
    String? finalPhotoPath = widget.practitionerData?.photoPath;

    // Sauvegarder la nouvelle photo si nécessaire
    if (_newPhotoFile != null) {
      finalPhotoPath = await widget.dataService.savePhoto(widget.info.name, _newPhotoFile!);
    } else if (_currentPhotoPath == null && widget.practitionerData?.photoPath != null) {
      // Photo supprimée
      await widget.dataService.deletePhoto(widget.info.name);
      finalPhotoPath = null;
    }

    final updatedData = PractitionerData(
      name: widget.info.name,
      photoPath: finalPhotoPath,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      phone: _phoneController.text.isEmpty ? null : _phoneController.text,
      email: _emailController.text.isEmpty ? null : _emailController.text,
    );

    await widget.dataService.update(updatedData);
    widget.onDataUpdated();

    _flipCard();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations enregistrées'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _cancelAndFlipBack() {
    // Réinitialiser les valeurs
    _initFormControllers();
    _flipCard();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * pi;
        final isFront = angle < pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isFront
              ? _buildFrontCard()
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _buildBackCard(),
                ),
        );
      },
    );
  }

  Widget _buildFrontCard() {
    final dateFormat = DateFormat('d MMM yyyy', 'fr_FR');
    final hasPhoto = widget.practitionerData?.photoPath != null;

    return GestureDetector(
      onTap: _flipCard,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec nom et stats
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      image: hasPhoto
                          ? DecorationImage(
                              image: FileImage(File(widget.practitionerData!.photoPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: hasPhoto
                        ? null
                        : Icon(
                            Icons.person,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.info.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${widget.info.totalSessions} séance${widget.info.totalSessions > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge flip
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.flip,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Badge de statut paiement
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.info.unpaidSessions == 0
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.info.unpaidSessions == 0
                      ? 'Paiements à jour'
                      : '${widget.info.unpaidSessions} séance${widget.info.unpaidSessions > 1 ? 's' : ''} à payer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.info.unpaidSessions == 0
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Barre de progression paiements
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paiements',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${widget.info.paidSessions}/${widget.info.paidSessions + widget.info.unpaidSessions} payées',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (widget.info.paidSessions + widget.info.unpaidSessions) > 0
                        ? widget.info.paidSessions / (widget.info.paidSessions + widget.info.unpaidSessions)
                        : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.info.unpaidSessions == 0 ? Colors.green : Colors.orange,
                    ),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Informations détaillées
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (widget.info.commonLocation != null)
                        _InfoRow(
                          icon: Icons.location_on,
                          label: 'Lieu',
                          value: widget.info.commonLocation!,
                        ),
                      if (widget.info.commonTime != null)
                        _InfoRow(
                          icon: Icons.access_time,
                          label: 'Horaire',
                          value: widget.info.commonTime!,
                        ),
                      if (widget.info.lastSessionDate != null)
                        _InfoRow(
                          icon: Icons.history,
                          label: 'Dernière',
                          value: dateFormat.format(widget.info.lastSessionDate!),
                        ),
                      if (widget.info.nextSessionDate != null)
                        _InfoRow(
                          icon: Icons.event,
                          label: 'Prochaine',
                          value: dateFormat.format(widget.info.nextSessionDate!),
                          valueColor: Colors.blue,
                        ),
                      if (widget.practitionerData?.phone != null)
                        _InfoRow(
                          icon: Icons.phone,
                          label: 'Tél',
                          value: widget.practitionerData!.phone!,
                        ),
                    ],
                  ),
                ),
              ),

              // Hint pour retourner
              Center(
                child: Text(
                  'Appuyez pour modifier',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.edit, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.info.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _cancelAndFlipBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Formulaire
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Photo
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          image: _currentPhotoPath != null
                              ? DecorationImage(
                                  image: FileImage(File(_currentPhotoPath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _currentPhotoPath == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo,
                                    size: 24,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Photo',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Téléphone
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        prefixIcon: Icon(Icons.phone, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 14),
                    ),

                    const SizedBox(height: 10),

                    // Email
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 14),
                    ),

                    const SizedBox(height: 10),

                    // Notes
                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: Icon(Icons.notes, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelAndFlipBack,
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saveAndFlipBack,
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.grey[800],
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
