import 'package:flutter/material.dart';

class PractitionerSelectionScreen extends StatefulWidget {
  final Map<String, int> discoveredPractitioners;
  final List<String> preselectedPractitioners;
  final Function(List<String>) onSelectionConfirmed;

  const PractitionerSelectionScreen({
    super.key,
    required this.discoveredPractitioners,
    this.preselectedPractitioners = const [],
    required this.onSelectionConfirmed,
  });

  @override
  State<PractitionerSelectionScreen> createState() =>
      _PractitionerSelectionScreenState();
}

class _PractitionerSelectionScreenState
    extends State<PractitionerSelectionScreen> {
  late Set<String> _selectedPractitioners;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPractitioners.isNotEmpty) {
      _selectedPractitioners = Set.from(widget.preselectedPractitioners);
    } else {
      // Par défaut, sélectionner tous les praticiens
      _selectedPractitioners = Set.from(widget.discoveredPractitioners.keys);
    }
  }

  void _togglePractitioner(String name) {
    setState(() {
      if (_selectedPractitioners.contains(name)) {
        _selectedPractitioners.remove(name);
      } else {
        _selectedPractitioners.add(name);
      }
    });
  }

  void _confirmSelection() {
    if (_selectedPractitioners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins un praticien'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    widget.onSelectionConfirmed(_selectedPractitioners.toList());
  }

  @override
  Widget build(BuildContext context) {
    final practitioners = widget.discoveredPractitioners.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sélection des praticiens'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Nous avons trouvé ces noms dans vos événements de calendrier. '
              'Sélectionnez ceux que vous souhaitez suivre :',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: practitioners.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun praticien trouvé',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vérifiez que vos événements correspondent au format '
                            '"Rendez-vous chez [nom]" ou "RDV chez [nom]"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: practitioners.length,
                    itemBuilder: (context, index) {
                      final entry = practitioners[index];
                      final name = entry.key;
                      final count = entry.value;
                      final isSelected = _selectedPractitioners.contains(name);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _togglePractitioner(name),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _togglePractitioner(name),
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
                                        '$count séance${count > 1 ? 's' : ''} trouvée${count > 1 ? 's' : ''}',
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
                  onPressed:
                      _selectedPractitioners.isNotEmpty ? _confirmSelection : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: Text(
                    _selectedPractitioners.isEmpty
                        ? 'Sélectionnez au moins un praticien'
                        : 'Confirmer (${_selectedPractitioners.length} sélectionné${_selectedPractitioners.length > 1 ? 's' : ''})',
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
