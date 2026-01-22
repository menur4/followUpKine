import 'package:flutter/material.dart';

class OrganizerSelectionScreen extends StatefulWidget {
  final Map<String, int> discoveredOrganizers;
  final List<String> preselectedOrganizers;
  final Function(List<String>) onSelectionConfirmed;
  final VoidCallback? onSkip;

  const OrganizerSelectionScreen({
    super.key,
    required this.discoveredOrganizers,
    this.preselectedOrganizers = const [],
    required this.onSelectionConfirmed,
    this.onSkip,
  });

  @override
  State<OrganizerSelectionScreen> createState() =>
      _OrganizerSelectionScreenState();
}

class _OrganizerSelectionScreenState extends State<OrganizerSelectionScreen> {
  late Set<String> _selectedOrganizers;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedOrganizers.isNotEmpty) {
      _selectedOrganizers = Set.from(widget.preselectedOrganizers);
    } else {
      // Par défaut, sélectionner tous les organisateurs
      _selectedOrganizers = Set.from(widget.discoveredOrganizers.keys);
    }
  }

  void _toggleOrganizer(String name) {
    setState(() {
      if (_selectedOrganizers.contains(name)) {
        _selectedOrganizers.remove(name);
      } else {
        _selectedOrganizers.add(name);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedOrganizers = Set.from(widget.discoveredOrganizers.keys);
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedOrganizers.clear();
    });
  }

  void _confirmSelection() {
    if (_selectedOrganizers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins un compte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    widget.onSelectionConfirmed(_selectedOrganizers.toList());
  }

  @override
  Widget build(BuildContext context) {
    final organizers = widget.discoveredOrganizers.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélection des comptes'),
        automaticallyImplyLeading: false,
        actions: [
          if (widget.onSkip != null)
            TextButton(
              onPressed: widget.onSkip,
              child: const Text(
                'Passer',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Vous avez plusieurs comptes calendrier. '
              'Sélectionnez ceux dont vous voulez suivre les événements :',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (widget.discoveredOrganizers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectAll,
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('Tout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _deselectAll,
                      icon: const Icon(Icons.deselect, size: 18),
                      label: const Text('Aucun'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: organizers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun créateur trouvé',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Les événements n\'ont pas d\'information sur leur créateur.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (widget.onSkip != null) ...[
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: widget.onSkip,
                              child: const Text('Continuer sans filtrer'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: organizers.length,
                    itemBuilder: (context, index) {
                      final entry = organizers[index];
                      final name = entry.key;
                      final count = entry.value;
                      final isSelected = _selectedOrganizers.contains(name);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _toggleOrganizer(name),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleOrganizer(name),
                                  activeColor: Colors.black,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$count calendrier${count > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: organizers.isEmpty
                      ? widget.onSkip
                      : (_selectedOrganizers.isNotEmpty
                          ? _confirmSelection
                          : null),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: Text(
                    organizers.isEmpty
                        ? 'Continuer'
                        : _selectedOrganizers.isEmpty
                            ? 'Sélectionnez au moins un compte'
                            : 'Confirmer (${_selectedOrganizers.length} sélectionné${_selectedOrganizers.length > 1 ? 's' : ''})',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
