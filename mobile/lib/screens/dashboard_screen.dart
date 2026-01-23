import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/charts_carousel.dart';
import '../widgets/sessions_carousel.dart';
import '../widgets/practitioners_carousel.dart';
import 'settings_screen.dart';
import 'calendar_selection_screen.dart';
import 'organizer_selection_screen.dart';
import 'practitioner_selection_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mes Séances',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              'Suivi de vos rendez-vous et paiements',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Consumer<SessionProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: provider.refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: provider.refreshing ? null : provider.refresh,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<SessionProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Chargement des calendriers
          if (provider.loadingCalendars) {
            return _buildLoadingScreen(
              'Chargement des calendriers...',
              'Récupération de vos calendriers',
            );
          }

          // Sélection du calendrier
          if (provider.needsCalendarSelection) {
            return CalendarSelectionScreen(
              calendars: provider.availableCalendars,
              preselectedCalendarId: provider.settings.selectedCalendarId,
              onSelectionConfirmed: (calendarId, calendarName) {
                provider.confirmCalendarSelection(calendarId, calendarName);
              },
            );
          }

          // Découverte des comptes calendrier
          if (provider.discoveringOrganizers) {
            return _buildLoadingScreen(
              'Analyse des comptes...',
              'Recherche des comptes calendrier',
            );
          }

          // Sélection des organisateurs
          if (provider.needsOrganizerSelection) {
            return OrganizerSelectionScreen(
              discoveredOrganizers: provider.discoveredOrganizers,
              preselectedOrganizers: provider.settings.selectedOrganizers,
              onSelectionConfirmed: (selected) {
                provider.confirmOrganizerSelection(selected);
              },
              onSkip: () {
                provider.skipOrganizerSelection();
              },
            );
          }

          // Découverte des praticiens
          if (provider.discoveringPractitioners) {
            return _buildLoadingScreen(
              'Analyse de votre calendrier...',
              'Recherche des praticiens dans vos événements',
            );
          }

          // Sélection des praticiens
          if (provider.needsPractitionerSelection) {
            return PractitionerSelectionScreen(
              discoveredPractitioners: provider.discoveredPractitioners,
              preselectedPractitioners: provider.settings.selectedPractitioners,
              onSelectionConfirmed: (selected) {
                provider.confirmPractitionerSelection(selected);
              },
            );
          }

          // Chargement des séances
          if (provider.loadingSessions) {
            return _buildLoadingScreen(
              'Chargement des séances...',
              'Récupération des événements de votre calendrier',
            );
          }

          if (provider.permissionDenied) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month, size: 64, color: Colors.orange[400]),
                    const SizedBox(height: 24),
                    const Text(
                      'Accès au calendrier requis',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pour afficher vos séances, l\'application a besoin d\'accéder à votre calendrier.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.requestCalendarPermission(),
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Autoriser l\'accès'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur: ${provider.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: provider.refresh,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final paymentStats = provider.paymentStats;
          final monthlyStats = provider.monthlyStats;
          final practitionerStats = provider.practitionerStats;
          final pastSessions = provider.pastSessions.reversed.take(5).toList();
          final futureSessions = provider.futureSessions.take(5).toList();

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Badges de statut
                  if (provider.refreshing)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Mise à jour en arrière-plan...'),
                        ],
                      ),
                    ),

                  // Statistiques de paiement
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.2,
                    children: [
                      StatCard(
                        label: 'Payées',
                        value: '${paymentStats.paid2025 + paymentStats.paid2026}',
                        detail: '${paymentStats.paid2025} en 2025 • ${paymentStats.paid2026} en 2026',
                        icon: Icons.check_circle_outline,
                        variant: StatCardVariant.success,
                      ),
                      StatCard(
                        label: 'En attente',
                        value: '${paymentStats.pending}',
                        detail: 'Séances à venir',
                        icon: Icons.schedule,
                        variant: StatCardVariant.warning,
                      ),
                      StatCard(
                        label: 'Total',
                        value: '${paymentStats.total}',
                        detail: 'Depuis mars 2025',
                        icon: Icons.calendar_month,
                        variant: StatCardVariant.info,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Carrousel de graphiques
                  ChartsCarousel(
                    monthlyStats: monthlyStats,
                    practitioners: provider.settings.selectedPractitioners,
                    paymentStats: paymentStats,
                    practitionerStats: practitionerStats,
                  ),
                  const SizedBox(height: 16),

                  // Carrousel des séances
                  SessionsCarousel(
                    futureSessions: futureSessions,
                    pastSessions: pastSessions,
                  ),

                  const SizedBox(height: 16),

                  // Carrousel des praticiens
                  PractitionersCarousel(
                    sessions: provider.sessions,
                    practitioners: provider.settings.selectedPractitioners,
                    lastUpdated: provider.lastUpdated,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
