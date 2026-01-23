import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';

class SessionList extends StatefulWidget {
  final String title;
  final List<Session> sessions;
  final bool showFuture;
  final bool allowSelection;

  const SessionList({
    super.key,
    required this.title,
    required this.sessions,
    this.showFuture = false,
    this.allowSelection = true,
  });

  @override
  State<SessionList> createState() => _SessionListState();
}

class _SessionListState extends State<SessionList> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

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

  void _selectAll() {
    setState(() {
      final payableSessions = widget.sessions.where((s) => !s.isFuture);
      for (final session in payableSessions) {
        _selectedIds.add(session.id);
      }
    });
  }

  void _selectUnpaid() {
    setState(() {
      final unpaidSessions = widget.sessions.where((s) => !s.isFuture && !s.paid);
      _selectedIds.clear();
      for (final session in unpaidSessions) {
        _selectedIds.add(session.id);
      }
    });
  }

  void _showBulkPaymentDialog() {
    // Ne prendre que les séances non payées parmi la sélection
    final unpaidIds = widget.sessions
        .where((s) => _selectedIds.contains(s.id) && !s.paid)
        .map((s) => s.id)
        .toList();

    if (unpaidIds.isEmpty) {
      // Toutes les séances sélectionnées sont déjà payées
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toutes les séances sélectionnées sont déjà payées'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final labelController = TextEditingController(
      text: 'Payé le ${DateFormat('dd/MM/yy', 'fr_FR').format(DateTime.now())}',
    );

    final ignoredCount = _selectedIds.length - unpaidIds.length;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Marquer ${unpaidIds.length} séance${unpaidIds.length > 1 ? 's' : ''} comme payée${unpaidIds.length > 1 ? 's' : ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous allez marquer ${unpaidIds.length} séance${unpaidIds.length > 1 ? 's' : ''} comme payée${unpaidIds.length > 1 ? 's' : ''}.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (ignoredCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$ignoredCount séance${ignoredCount > 1 ? 's' : ''} déjà payée${ignoredCount > 1 ? 's' : ''} ignorée${ignoredCount > 1 ? 's' : ''}.',
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
              context.read<SessionProvider>().markMultipleSessionsAsPaid(
                unpaidIds,
                label: label,
              );
              _exitSelectionMode();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
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
    if (widget.sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Aucune séance',
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

    final hasUnpaidSessions = widget.sessions.any((s) => !s.isFuture && !s.paid);
    final hasPaidSelected = _selectedIds.any(
      (id) => widget.sessions.any((s) => s.id == id && s.paid),
    );
    final hasUnpaidSelected = _selectedIds.any(
      (id) => widget.sessions.any((s) => s.id == id && !s.paid),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec titre et actions
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_selectionMode) ...[
                  Text(
                    '${_selectedIds.length} sélectionnée${_selectedIds.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelectionMode,
                    tooltip: 'Annuler la sélection',
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ] else if (widget.allowSelection && !widget.showFuture && hasUnpaidSessions) ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Actions groupées',
                    onSelected: (value) {
                      if (value == 'select_unpaid') {
                        setState(() {
                          _selectionMode = true;
                        });
                        _selectUnpaid();
                      } else if (value == 'select_all') {
                        setState(() {
                          _selectionMode = true;
                        });
                        _selectAll();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'select_unpaid',
                        child: Row(
                          children: [
                            Icon(Icons.check_box_outline_blank, size: 18),
                            SizedBox(width: 8),
                            Text('Sélectionner non payées'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'select_all',
                        child: Row(
                          children: [
                            Icon(Icons.select_all, size: 18),
                            SizedBox(width: 8),
                            Text('Tout sélectionner'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Liste des séances
            ...widget.sessions.map((session) => _SessionItem(
              session: session,
              showFuture: widget.showFuture,
              selectionMode: _selectionMode,
              isSelected: _selectedIds.contains(session.id),
              onTap: () {
                if (_selectionMode) {
                  if (!session.isFuture) {
                    _toggleSelection(session.id);
                  }
                } else if (!session.isFuture) {
                  _showSinglePaymentDialog(session);
                }
              },
              onLongPress: () {
                if (!session.isFuture && widget.allowSelection) {
                  _enterSelectionMode(session.id);
                }
              },
            )),

            // Actions de sélection
            if (_selectionMode && _selectedIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (hasUnpaidSelected)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _showBulkPaymentDialog,
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Marquer payées'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  if (hasUnpaidSelected && hasPaidSelected)
                    const SizedBox(width: 8),
                  if (hasPaidSelected)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showBulkUnpaidDialog,
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Annuler paiements'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSinglePaymentDialog(Session session) {
    final dateFormat = DateFormat('d MMMM yyyy', 'fr_FR');
    final labelController = TextEditingController(
      text: 'Payé le ${DateFormat('dd/MM/yy', 'fr_FR').format(DateTime.now())}',
    );

    if (session.paid) {
      // Dialog pour annuler le paiement
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Annuler le paiement ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voulez-vous annuler le paiement de la séance du ${dateFormat.format(session.date)} ?',
              ),
              if (session.paymentLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Label actuel : ${session.paymentLabel}',
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
      // Dialog pour marquer comme payé avec label
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

class _SessionItem extends StatelessWidget {
  final Session session;
  final bool showFuture;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SessionItem({
    required this.session,
    required this.showFuture,
    required this.selectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final isFuture = session.isFuture;

    // Couleur de la bordure selon le statut
    Color borderColor;
    if (isFuture) {
      borderColor = Colors.blue;
    } else if (session.paid) {
      borderColor = Colors.green;
    } else {
      borderColor = Colors.orange;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Checkbox en mode sélection
            if (selectionMode && !isFuture) ...[
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
            ],

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
                  if (session.time != null)
                    Text(
                      '${session.time} - ${session.practitioner}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  // Afficher le label de paiement
                  if (session.paid && session.paymentLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        session.paymentLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!selectionMode) _buildStatusIndicator(isFuture),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isFuture) {
    if (isFuture) {
      return const Icon(Icons.calendar_today, color: Colors.blue, size: 20);
    }

    if (session.paid) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 4),
          Text(
            'Payée',
            style: TextStyle(
              color: Colors.green,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.radio_button_unchecked, color: Colors.orange, size: 20),
        const SizedBox(width: 4),
        Text(
          'À payer',
          style: TextStyle(
            color: Colors.orange[700],
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
