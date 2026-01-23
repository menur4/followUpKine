import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';

class MonthlyChart extends StatelessWidget {
  final List<MonthlyStats> stats;
  final List<String> practitioners;

  const MonthlyChart({
    super.key,
    required this.stats,
    required this.practitioners,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty || practitioners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évolution mensuelle',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: stats
                          .map((s) => s.total.toDouble())
                          .reduce((a, b) => a > b ? a : b) +
                      2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final stat = stats[groupIndex];
                        return BarTooltipItem(
                          '${stat.month}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: 'Total: ${stat.total}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= stats.length) {
                            return const SizedBox.shrink();
                          }
                          final label = stats[value.toInt()].month;
                          // Afficher seulement les 3 premières lettres
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label.substring(0, 3),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value == value.roundToDouble()) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: stats.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stat = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: practitioners.asMap().entries.map((pEntry) {
                        final pIndex = pEntry.key;
                        final practitioner = pEntry.value;
                        return BarChartRodData(
                          toY: stat.getCount(practitioner).toDouble(),
                          color: AppColors.chartColors[pIndex % AppColors.chartColors.length],
                          width: 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: practitioners.asMap().entries.map((entry) {
                final index = entry.key;
                final practitioner = entry.value;
                return _LegendItem(
                  color: AppColors.chartColors[index % AppColors.chartColors.length],
                  label: practitioner,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class PractitionerChart extends StatelessWidget {
  final List<PractitionerStats> stats;

  const PractitionerChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition par praticien',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: stats.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stat = entry.value;
                    return PieChartSectionData(
                      color: AppColors.chartColors[index % AppColors.chartColors.length],
                      value: stat.count.toDouble(),
                      title: '${stat.percentage.round()}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...stats.asMap().entries.map((entry) {
              final index = entry.key;
              final stat = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.chartColors[index % AppColors.chartColors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(stat.name, style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text(
                      '${stat.count} séances',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class PaymentChart extends StatelessWidget {
  final PaymentStats stats;
  final VoidCallback? onTap;

  const PaymentChart({super.key, required this.stats, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final paidTotal = stats.paid2025 + stats.paid2026;
    final paidPercentage = (paidTotal / stats.total * 100).round();

    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Statut des paiements',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        color: AppColors.success,
                        value: paidTotal.toDouble(),
                        title: '$paidPercentage%',
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (stats.pending > 0)
                        PieChartSectionData(
                          color: AppColors.warning,
                          value: stats.pending.toDouble(),
                          title: '${100 - paidPercentage}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _LegendItem(color: AppColors.success, label: 'Payées ($paidTotal)'),
              const SizedBox(height: AppSpacing.xs),
              if (stats.pending > 0)
                _LegendItem(color: AppColors.warning, label: 'En attente (${stats.pending})'),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSpacing.xs),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}
