import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';

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

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Marquer ${unpaidIds.length} séance${unpaidIds.length > 1 ? 's' : ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marquer ${unpaidIds.length} séance${unpaidIds.length > 1 ? 's' : ''} non payée${unpaidIds.length > 1 ? 's' : ''} avec un label.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_selectedIds.length > unpaidIds.length) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedIds.length - unpaidIds.length} séance${(_selectedIds.length - unpaidIds.length) > 1 ? 's' : ''} déjà payée${(_selectedIds.length - unpaidIds.length) > 1 ? 's' : ''} sera ignorée${(_selectedIds.length - unpaidIds.length) > 1 ? 's' : ''}.',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final label = labelController.text.trim().isEmpty
                  ? null
                  : labelController.text.trim();
              // Ne marquer que les séances non payées
              context.read<SessionProvider>().markMultipleSessionsAsPaid(
                unpaidIds,
                label: label,
              );
              _exitSelectionMode();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Marquer payées'),
          ),
        ],
      ),
    );
  }

  void _showBulkUnpaidDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler les paiements'),
        content: Text(
          'Voulez-vous annuler le paiement de ${_selectedIds.length} séance${_selectedIds.length > 1 ? 's' : ''} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<SessionProvider>().markMultipleSessionsAsUnpaid(
                _selectedIds.toList(),
              );
              _exitSelectionMode();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
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
              icon: const Icon(Icons.check_circle, color: Colors.green),
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
              icon: const Icon(Icons.cancel, color: Colors.orange),
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
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aucune séance',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
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
        return _SessionCard(
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
        );
      },
    );
  }

  void _showSinglePaymentDialog(Session session) {
    final dateFormat = DateFormat('d MMMM yyyy', 'fr_FR');
    final labelController = TextEditingController(
      text: 'Payé le ${DateFormat('dd/MM/yy', 'fr_FR').format(DateTime.now())}',
    );

    if (session.paid) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Annuler le paiement ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Séance du ${dateFormat.format(session.date)}',
              ),
              if (session.paymentLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Label : ${session.paymentLabel}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<SessionProvider>().markSessionAsUnpaid(session.id);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Annuler paiement'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Marquer comme payée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Séance du ${dateFormat.format(session.date)}',
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
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                final label = labelController.text.trim().isEmpty
                    ? null
                    : labelController.text.trim();
                context.read<SessionProvider>().markSessionAsPaid(
                  session.id,
                  label: label,
                );
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Marquer payée'),
            ),
          ],
        ),
      );
    }
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SessionCard({
    required this.session,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
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
                  color: session.paid ? Colors.green : Colors.orange,
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
                        color: Colors.grey[600],
                      ),
                    ),
                    if (session.paid && session.paymentLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        session.paymentLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
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
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.paid ? 'Payée' : 'À payer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: session.paid ? Colors.green[700] : Colors.orange[700],
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
