import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Helper pour afficher des action sheets style iOS
class ActionSheets {
  /// Affiche une action sheet avec des options
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    required List<ActionSheetItem<T>> actions,
    ActionSheetItem<T>? cancelAction,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ActionSheetContent<T>(
        title: title,
        message: message,
        actions: actions,
        cancelAction: cancelAction,
      ),
    );
  }

  /// Affiche une action sheet de confirmation destructive
  static Future<bool?> showDestructiveConfirmation({
    required BuildContext context,
    required String title,
    String? message,
    required String destructiveLabel,
    String cancelLabel = 'Annuler',
  }) {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      actions: [
        ActionSheetItem<bool>(
          label: destructiveLabel,
          isDestructive: true,
          value: true,
        ),
      ],
      cancelAction: ActionSheetItem<bool>(
        label: cancelLabel,
        value: false,
      ),
    );
  }

  /// Affiche une action sheet avec un contenu personnalisé (formulaire, etc.)
  static Future<T?> showWithContent<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget content,
    required List<ActionSheetButton<T>> buttons,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ActionSheetWithContent<T>(
        title: title,
        subtitle: subtitle,
        content: content,
        buttons: buttons,
      ),
    );
  }
}

class ActionSheetItem<T> {
  final String label;
  final IconData? icon;
  final bool isDestructive;
  final T? value;
  final VoidCallback? onTap;

  ActionSheetItem({
    required this.label,
    this.icon,
    this.isDestructive = false,
    this.value,
    this.onTap,
  });
}

class ActionSheetButton<T> {
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final Color? backgroundColor;
  final T? value;
  final VoidCallback? onTap;

  ActionSheetButton({
    required this.label,
    this.isPrimary = false,
    this.isDestructive = false,
    this.backgroundColor,
    this.value,
    this.onTap,
  });
}

class _ActionSheetContent<T> extends StatelessWidget {
  final String? title;
  final String? message;
  final List<ActionSheetItem<T>> actions;
  final ActionSheetItem<T>? cancelAction;

  const _ActionSheetContent({
    this.title,
    this.message,
    required this.actions,
    this.cancelAction,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, bottomPadding + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Actions principales
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Titre et message
                  if (title != null || message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          if (message != null) ...[
                            if (title != null) const SizedBox(height: 4),
                            Text(
                              message!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (title != null || message != null)
                    Divider(height: 1, color: Colors.grey[200]),
                  // Actions
                  ...actions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final action = entry.value;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (index > 0) Divider(height: 1, color: Colors.grey[200]),
                        _ActionSheetTile<T>(action: action),
                      ],
                    );
                  }),
                ],
              ),
            ),
            // Bouton annuler
            if (cancelAction != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _ActionSheetTile<T>(
                  action: cancelAction!,
                  isBold: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionSheetTile<T> extends StatelessWidget {
  final ActionSheetItem<T> action;
  final bool isBold;

  const _ActionSheetTile({
    required this.action,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = action.isDestructive ? AppColors.error : Theme.of(context).primaryColor;

    return InkWell(
      onTap: () {
        if (action.onTap != null) {
          action.onTap!();
        } else {
          Navigator.pop(context, action.value);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, color: textColor, size: 22),
              const SizedBox(width: 8),
            ],
            Text(
              action.label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionSheetWithContent<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget content;
  final List<ActionSheetButton<T>> buttons;

  const _ActionSheetWithContent({
    required this.title,
    this.subtitle,
    required this.content,
    required this.buttons,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: content,
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: buttons.asMap().entries.map((entry) {
                    final index = entry.key;
                    final button = entry.value;

                    Widget buttonWidget;
                    if (button.isPrimary) {
                      buttonWidget = FilledButton(
                        onPressed: () {
                          if (button.onTap != null) {
                            button.onTap!();
                          } else {
                            Navigator.pop(context, button.value);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: button.backgroundColor ??
                            (button.isDestructive ? AppColors.error : null),
                          minimumSize: const Size(0, 50),
                        ),
                        child: Text(button.label),
                      );
                    } else {
                      buttonWidget = OutlinedButton(
                        onPressed: () {
                          if (button.onTap != null) {
                            button.onTap!();
                          } else {
                            Navigator.pop(context, button.value);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: button.isDestructive ? AppColors.error : null,
                          minimumSize: const Size(0, 50),
                        ),
                        child: Text(button.label),
                      );
                    }

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: index > 0 ? 12 : 0),
                        child: buttonWidget,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
