import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../widgets/stat_card.dart';
import '../widgets/session_list.dart';
import '../widgets/charts.dart';

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
              'Kinésithérapie 2025-2026',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              'Vue consolidée avec suivi des paiements',
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
        ],
      ),
      body: Consumer<SessionProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(
              child: CircularProgressIndicator(),
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

          String formattedLastUpdated = 'Jamais';
          if (provider.lastUpdated != null) {
            formattedLastUpdated = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR')
                .format(provider.lastUpdated!);
          }

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

                  // Graphiques
                  MonthlyChart(stats: monthlyStats),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PaymentChart(stats: paymentStats),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  PractitionerChart(stats: practitionerStats),
                  const SizedBox(height: 16),

                  // Listes de séances
                  if (futureSessions.isNotEmpty) ...[
                    SessionList(
                      title: 'Prochaines séances',
                      sessions: futureSessions,
                      showFuture: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  SessionList(
                    title: 'Dernières séances',
                    sessions: pastSessions,
                  ),

                  const SizedBox(height: 16),

                  // Informations pratiques
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations pratiques',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.location_on,
                            label: 'Lieu',
                            value: '24 Rue du Javelot, 75013',
                          ),
                          _InfoRow(
                            icon: Icons.access_time,
                            label: 'Horaire',
                            value: 'Généralement 12h15-13h15',
                          ),
                          _InfoRow(
                            icon: Icons.business,
                            label: 'Accès',
                            value: 'RDC, dalle Olympiades',
                          ),
                          _InfoRow(
                            icon: Icons.update,
                            label: 'Mis à jour',
                            value: formattedLastUpdated,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
