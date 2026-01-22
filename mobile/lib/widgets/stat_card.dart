import 'package:flutter/material.dart';

enum StatCardVariant { normal, success, warning, info }

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final IconData? icon;
  final StatCardVariant variant;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.icon,
    this.variant = StatCardVariant.normal,
  });

  Color _getAccentColor(BuildContext context) {
    switch (variant) {
      case StatCardVariant.success:
        return Colors.green;
      case StatCardVariant.warning:
        return Colors.orange;
      case StatCardVariant.info:
        return Colors.blue;
      case StatCardVariant.normal:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getAccentColor(context);

    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: variant != StatCardVariant.normal
                  ? accentColor
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                ],
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: variant != StatCardVariant.normal
                    ? accentColor
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
