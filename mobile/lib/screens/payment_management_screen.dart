import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import '../widgets/action_sheets.dart';

class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({super.key});

  @override
  State<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  String _filterYear = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(String sessionId) {
    setState(() {
      if (_selectedIds.contains(sessionId)) {
        _selectedIds.remove(sessionId);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIds.add(sessionId);
      }
    });
  }

  void _enterSelectionMode(String sessionId) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(sessionId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAllVisible(List<Session> sessions) {
    setState(() {
      _selectionMode = true;
      for (final session in sessions) {
        _selectedIds.add(session.id);
      }
    });
  }

  List<Session> _filterSessions(List<Session> sessions) {
    if (_filterYear == 'all') return sessions;
    final year = int.parse(_filterYear);
    return sessions.where((s) => s.date.year == year).toList();
  }

  void _showBulkPaymentDialog(List<Session> sessions) {
    // Ne prendre que les séances non payées parmi la sélection
    final unpaidSessions = sessions.where((s) => !s.paid).toList();
    final unpaidIds = unpaidSessions.map((s) => s.id).toList();

    if (unpaidIds.isEmpty) {
      _showBulkUnpaidDialog();
      return;
    }

    final labelController = TextEditingController(
      text: 'Payé le ${DateFormat('dd/MM/yy', 'fr_FR').format(DateTime.now())}',
    );
    final ignoredCount = _selectedIds.length - unpaidIds.length;

    ActionSheets.showWithContent<bool>(
      context: context,
      title: 'Marquer ${unpaidIds.length} séance${unpaidIds.length > 1 ? 's' : ''} comme payée${unpaidIds.length > 1 ? 's' : ''}',
      subtitle: ignoredCount > 0
          ? '$ignoredCount séance${ignoredCount > 1 ? 's' : ''} déjà payée${ignoredCount > 1 ? 's' : ''} sera ignorée${ignoredCount > 1 ? 's' : ''}.'
          : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'Label (optionnel)',
              hintText: 'Ex: Payé le 22/01/26',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
      buttons: [
        ActionSheetButton<bool>(
          label: 'Annuler',
          value: false,
        ),
        ActionSheetButton<bool>(
          label: 'Marquer payées',
          isPrimary: true,
          backgroundColor: AppColors.success,
          onTap: () {
            HapticService.success();
            Navigator.pop(context);
            final label = labelController.text.trim().isEmpty
                ? null
                : labelController.text.trim();
            context.read<SessionProvider>().markMultipleSessionsAsPaid(
              unpaidIds,
              label: label,
            );
            _exitSelectionMode();
          },
        ),
      ],
    );
  }

  void _showBulkUnpaidDialog() async {
    final confirmed = await ActionSheets.showDestructiveConfirmation(
      context: context,
      title: 'Annuler les paiements',
      message: 'Voulez-vous annuler le paiement de ${_selectedIds.length} séance${_selectedIds.length > 1 ? 's' : ''} ?',
      destructiveLabel: 'Annuler les paiements',
      cancelLabel: 'Annuler',
    );

    if (confirmed == true) {
      HapticService.warning();
      context.read<SessionProvider>().markMultipleSessionsAsUnpaid(
        _selectedIds.toList(),
      );
      _exitSelectionMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} sélectionnée${_selectedIds.length > 1 ? 's' : ''}')
            : const Text('Gestion des paiements'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppColors.success),
              onPressed: () {
                final provider = context.read<SessionProvider>();
                final sessions = _selectedIds
                    .map((id) => provider.sessions.firstWhere((s) => s.id == id))
                    .toList();
                _showBulkPaymentDialog(sessions);
              },
              tooltip: 'Marquer payées',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: AppColors.warning),
              onPressed: _showBulkUnpaidDialog,
              tooltip: 'Annuler paiements',
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filtrer par année',
              onSelected: (value) {
                setState(() {
                  _filterYear = value;
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'all',
                  child: Row(
                    children: [
                      if (_filterYear == 'all')
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      const Text('Toutes les années'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: '2025',
                  child: Row(
                    children: [
                      if (_filterYear == '2025')
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      const Text('2025'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: '2026',
                  child: Row(
                    children: [
                      if (_filterYear == '2026')
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      const Text('2026'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'À payer'),
            Tab(text: 'Payées'),
          ],
        ),
      ),
      body: Consumer<SessionProvider>(
        builder: (context, provider, _) {
          final allSessions = provider.pastSessions.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final unpaidSessions = allSessions.where((s) => !s.paid).toList();
          final paidSessions = allSessions.where((s) => s.paid).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildSessionList(_filterSessions(allSessions)),
              _buildSessionList(_filterSessions(unpaidSessions)),
              _buildSessionList(_filterSessions(paidSessions)),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<SessionProvider>(
        builder: (context, provider, _) {
          if (_selectionMode) return const SizedBox.shrink();

          final currentIndex = _tabController.index;
          List<Session> sessions;

          if (currentIndex == 0) {
            sessions = _filterSessions(provider.pastSessions.toList());
          } else if (currentIndex == 1) {
            sessions = _filterSessions(provider.unpaidSessions);
          } else {
            sessions = _filterSessions(
              provider.pastSessions.where((s) => s.paid).toList(),
            );
          }

          if (sessions.isEmpty) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () => _selectAllVisible(sessions),
            icon: const Icon(Icons.select_all),
            label: const Text('Tout sélectionner'),
          );
        },
      ),
    );
  }

  Widget _buildSessionList(List<Session> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppColors.dividerLight),
            const SizedBox(height: 16),
            Text(
              'Aucune séance',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SwipeableSessionCard(
          session: session,
          isSelected: _selectedIds.contains(session.id),
          selectionMode: _selectionMode,
          onTap: () {
            if (_selectionMode) {
              _toggleSelection(session.id);
            } else {
              _showSinglePaymentDialog(session);
            }
          },
          onLongPress: () => _enterSelectionMode(session.id),
          onMarkPaid: () => _quickMarkAsPaid(session),
          onMarkUnpaid: () => _quickMarkAsUnpaid(session),
        );
      },
    );
  }

  void _quickMarkAsPaid(Session session) {
    HapticService.success();
    final label = 'Payé le ${DateFormat('dd/MM/yy', 'fr_FR').format(DateTime.now())}';
    context.read<SessionProvider>().markSessionAsPaid(session.id, label: label);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Séance marquée comme payée'),
        backgroundColor: AppColors.success,
        action: SnackBarAction(
          label: 'Annuler',
          textColor: Colors.white,
          onPressed: () {
            context.read<SessionProvider>().markSessionAsUnpaid(session.id);
          },
        ),
      ),
    );
  }

  void _quickMarkAsUnpaid(Session session) {
    HapticService.warning();
    context.read<SessionProvider>().markSessionAsUnpaid(session.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Paiement annulé'),
        backgroundColor: AppColors.warning,
        action: SnackBarAction(
          label: 'Annuler',
          textColor: Colors.white,
          onPressed: () {
            context.read<SessionProvider>().markSessionAsPaid(session.id);
          },
        ),
      ),
    );
  }

  void _showSinglePaymentDialog(Session session) async {
    final dateFormat = DateFormat('d MMMM yyyy', 'fr_FR');

    if (session.paid) {
      // Action sheet pour annuler le paiement
      final confirmed = await ActionSheets.showDestructiveConfirmation(
        context: context,
        title: 'Annuler le paiement ?',
        message: session.paymentLabel != null
            ? 'Séance du ${dateFormat.format(session.date)}\nLabel : ${session.paymentLabel}'
            : 'Séance du ${dateFormat.format(session.date)}',
        destructiveLabel: 'Annuler le paiement',
        cancelLabel: 'Annuler',
      );

      if (confirmed == true) {
        HapticService.warning();
        context.read<SessionProvider>().markSessionAsUnpaid(session.id);
      }
    } else {
      // Action sheet pour marquer comme payée
      final labelController = TextEditingController(
        text: 'Payé le ${DateFormat('dd/MM/yy', 'fr_FR').format(DateTime.now())}',
      );

      ActionSheets.showWithContent<bool>(
        context: context,
        title: 'Marquer comme payée',
        subtitle: 'Séance du ${dateFormat.format(session.date)}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label (optionnel)',
                hintText: 'Ex: Payé le 22/01/26',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
        buttons: [
          ActionSheetButton<bool>(
            label: 'Annuler',
            value: false,
          ),
          ActionSheetButton<bool>(
            label: 'Marquer payée',
            isPrimary: true,
            backgroundColor: AppColors.success,
            onTap: () {
              HapticService.success();
              Navigator.pop(context);
              final label = labelController.text.trim().isEmpty
                  ? null
                  : labelController.text.trim();
              context.read<SessionProvider>().markSessionAsPaid(
                session.id,
                label: label,
              );
            },
          ),
        ],
      );
    }
  }
}

/// Carte de séance avec swipe actions style iOS
class _SwipeableSessionCard extends StatelessWidget {
  final Session session;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMarkPaid;
  final VoidCallback onMarkUnpaid;

  const _SwipeableSessionCard({
    required this.session,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');

    // En mode sélection, pas de swipe
    if (selectionMode) {
      return _buildCard(context, dateFormat);
    }

    // Swipe actions
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Dismissible(
        key: Key(session.id),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          HapticService.mediumImpact();
          if (direction == DismissDirection.endToStart) {
            // Swipe gauche → Marquer payée (si non payée)
            if (!session.paid) {
              onMarkPaid();
            }
          } else {
            // Swipe droite → Annuler paiement (si payée)
            if (session.paid) {
              onMarkUnpaid();
            }
          }
          return false; // Ne pas supprimer la carte
        },
        background: _buildSwipeBackground(
          context,
          alignment: Alignment.centerLeft,
          color: session.paid ? AppColors.warning : Colors.grey[400]!,
          icon: session.paid ? Icons.cancel : Icons.block,
          label: session.paid ? 'Annuler' : '',
          enabled: session.paid,
        ),
        secondaryBackground: _buildSwipeBackground(
          context,
          alignment: Alignment.centerRight,
          color: !session.paid ? AppColors.success : Colors.grey[400]!,
          icon: !session.paid ? Icons.check_circle : Icons.block,
          label: !session.paid ? 'Payée' : '',
          enabled: !session.paid,
        ),
        child: _buildCard(context, dateFormat),
      ),
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
    required bool enabled,
  }) {
    final isLeft = alignment == Alignment.centerLeft;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: enabled ? color : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? 24 : 0,
        right: isLeft ? 0 : 24,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeft
            ? [
                Icon(icon, color: Colors.white, size: 24),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ]
            : [
                if (label.isNotEmpty) ...[
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(icon, color: Colors.white, size: 24),
              ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, DateFormat dateFormat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? AppColors.info.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (selectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: session.paid ? AppColors.success : AppColors.warning,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(session.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.practitioner,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    if (session.paid && session.paymentLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        session.paymentLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!selectionMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: session.paid
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.paid ? 'Payée' : 'À payer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: session.paid ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
