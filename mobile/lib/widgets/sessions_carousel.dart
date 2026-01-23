import 'package:flutter/material.dart';
import '../models/session.dart';
import 'session_list.dart';

class SessionsCarousel extends StatefulWidget {
  final List<Session> futureSessions;
  final List<Session> pastSessions;

  const SessionsCarousel({
    super.key,
    required this.futureSessions,
    required this.pastSessions,
  });

  @override
  State<SessionsCarousel> createState() => _SessionsCarouselState();
}

class _SessionsCarouselState extends State<SessionsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Commencer sur la première page avec du contenu
    if (widget.futureSessions.isEmpty && widget.pastSessions.isNotEmpty) {
      _currentPage = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(1);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si aucune séance, afficher un message
    if (widget.futureSessions.isEmpty && widget.pastSessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Séances',
                style: TextStyle(
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

    final pages = <Widget>[];
    final titles = <String>[];

    // Ajouter les pages disponibles
    if (widget.futureSessions.isNotEmpty) {
      pages.add(SessionList(
        title: 'Prochaines séances',
        sessions: widget.futureSessions,
        showFuture: true,
      ));
      titles.add('À venir');
    }

    if (widget.pastSessions.isNotEmpty) {
      pages.add(SessionList(
        title: 'Dernières séances',
        sessions: widget.pastSessions,
      ));
      titles.add('Passées');
    }

    // Si une seule page, pas besoin de carrousel
    if (pages.length == 1) {
      return pages.first;
    }

    return Column(
      children: [
        // Onglets de navigation
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: List.generate(
              pages.length,
              (index) => Expanded(
                child: GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          index == 0 && widget.futureSessions.isNotEmpty
                              ? Icons.calendar_today
                              : Icons.history,
                          size: 16,
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          titles[index],
                          style: TextStyle(
                            fontWeight: _currentPage == index
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _currentPage == index
                                ? Theme.of(context).primaryColor
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            index == 0 && widget.futureSessions.isNotEmpty
                                ? '${widget.futureSessions.length}'
                                : '${widget.pastSessions.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _currentPage == index
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Contenu du carrousel
        SizedBox(
          height: _calculatePageHeight(),
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: pages.length,
            itemBuilder: (context, index) {
              return pages[index];
            },
          ),
        ),
      ],
    );
  }

  double _calculatePageHeight() {
    // Calculer la hauteur en fonction du nombre de séances
    // Base: 80px pour le header + 68px par séance + padding
    final futureCount = widget.futureSessions.length;
    final pastCount = widget.pastSessions.length;
    final maxCount = futureCount > pastCount ? futureCount : pastCount;

    // Hauteur de base pour le titre et les actions
    const baseHeight = 80.0;
    // Hauteur par séance (incluant les marges)
    const itemHeight = 72.0;
    // Hauteur pour les boutons d'action en mode sélection
    const actionHeight = 50.0;

    final calculatedHeight = baseHeight + (maxCount * itemHeight) + actionHeight;

    // Limiter la hauteur maximale
    return calculatedHeight.clamp(200.0, 500.0);
  }
}
