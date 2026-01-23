import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../screens/payment_management_screen.dart';
import 'charts.dart';

class ChartsCarousel extends StatefulWidget {
  final List<MonthlyStats> monthlyStats;
  final List<String> practitioners;
  final PaymentStats paymentStats;
  final List<PractitionerStats> practitionerStats;

  const ChartsCarousel({
    super.key,
    required this.monthlyStats,
    required this.practitioners,
    required this.paymentStats,
    required this.practitionerStats,
  });

  @override
  State<ChartsCarousel> createState() => _ChartsCarouselState();
}

class _ChartsCarouselState extends State<ChartsCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charts = <Widget>[
      MonthlyChart(
        stats: widget.monthlyStats,
        practitioners: widget.practitioners,
      ),
      FlipPaymentChart(
        stats: widget.paymentStats,
      ),
      PractitionerChart(stats: widget.practitionerStats),
    ];

    return Column(
      children: [
        SizedBox(
          height: 400,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: charts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: charts[index],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Indicateurs de page
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            charts.length,
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
      ],
    );
  }
}

/// Widget avec effet de flip pour le graphique des paiements
class FlipPaymentChart extends StatefulWidget {
  final PaymentStats stats;

  const FlipPaymentChart({super.key, required this.stats});

  @override
  State<FlipPaymentChart> createState() => _FlipPaymentChartState();
}

class _FlipPaymentChartState extends State<FlipPaymentChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_showFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _showFront = !_showFront;
    });
  }

  void _navigateToPaymentManagement() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PaymentManagementScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * math.pi;
        final isBack = angle > math.pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: isBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _buildBackCard(),
                )
              : _buildFrontCard(),
        );
      },
    );
  }

  Widget _buildFrontCard() {
    return GestureDetector(
      onTap: _flip,
      child: _PaymentChartFront(
        stats: widget.stats,
        onTap: _flip,
      ),
    );
  }

  Widget _buildBackCard() {
    return GestureDetector(
      onTap: _flip,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _flip,
                    tooltip: 'Retour',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Gestion des paiements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildQuickStats(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _navigateToPaymentManagement,
                  icon: const Icon(Icons.list),
                  label: const Text('Voir toutes les séances'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final paidTotal = widget.stats.paid2025 + widget.stats.paid2026;

    return Column(
      children: [
        _QuickStatRow(
          icon: Icons.check_circle,
          color: Colors.green,
          label: 'Payées',
          value: '$paidTotal',
          detail: '${widget.stats.paid2025} en 2025 • ${widget.stats.paid2026} en 2026',
        ),
        const SizedBox(height: 16),
        _QuickStatRow(
          icon: Icons.pending,
          color: Colors.orange,
          label: 'En attente',
          value: '${widget.stats.pending}',
          detail: 'Séances à pointer',
        ),
        const SizedBox(height: 16),
        _QuickStatRow(
          icon: Icons.calendar_month,
          color: Colors.blue,
          label: 'Total',
          value: '${widget.stats.total}',
          detail: 'Toutes les séances',
        ),
      ],
    );
  }
}

class _PaymentChartFront extends StatelessWidget {
  final PaymentStats stats;
  final VoidCallback onTap;

  const _PaymentChartFront({required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // On réutilise le PaymentChart existant mais sans le onTap car on le gère au niveau parent
    return Stack(
      children: [
        PaymentChart(stats: stats),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Tap pour gérer',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickStatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;

  const _QuickStatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
