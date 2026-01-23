import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Informations de paiement pour une séance
class PaymentInfo {
  final DateTime paidDate;
  final String? label;

  PaymentInfo({
    required this.paidDate,
    this.label,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      paidDate: DateTime.parse(json['paidDate'] as String),
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paidDate': paidDate.toIso8601String(),
      'label': label,
    };
  }
}

/// Service pour persister le statut de paiement des séances
class PaymentService {
  static const String _paymentsKey = 'session_payments_v2';
  static const String _legacyPaymentsKey = 'session_payments';

  /// Charge les paiements enregistrés
  /// Retourne une Map avec sessionId comme clé et PaymentInfo comme valeur
  Future<Map<String, PaymentInfo>> loadPayments() async {
    final prefs = await SharedPreferences.getInstance();

    // Essayer de charger le nouveau format
    var jsonString = prefs.getString(_paymentsKey);

    // Migration depuis l'ancien format si nécessaire
    if (jsonString == null) {
      final legacyJson = prefs.getString(_legacyPaymentsKey);
      if (legacyJson != null) {
        try {
          final Map<String, dynamic> legacy = jsonDecode(legacyJson);
          final migrated = <String, PaymentInfo>{};
          for (final entry in legacy.entries) {
            migrated[entry.key] = PaymentInfo(
              paidDate: DateTime.parse(entry.value as String),
            );
          }
          // Sauvegarder dans le nouveau format
          await _savePaymentsInternal(prefs, migrated);
          // Supprimer l'ancien
          await prefs.remove(_legacyPaymentsKey);
          return migrated;
        } catch (e) {
          return {};
        }
      }
      return {};
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((key, value) => MapEntry(
            key,
            PaymentInfo.fromJson(value as Map<String, dynamic>),
          ));
    } catch (e) {
      return {};
    }
  }

  Future<void> _savePaymentsInternal(
    SharedPreferences prefs,
    Map<String, PaymentInfo> payments,
  ) async {
    final Map<String, dynamic> toSave = payments.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await prefs.setString(_paymentsKey, jsonEncode(toSave));
  }

  /// Sauvegarde les paiements
  Future<void> savePayments(Map<String, PaymentInfo> payments) async {
    final prefs = await SharedPreferences.getInstance();
    await _savePaymentsInternal(prefs, payments);
  }

  /// Marque une séance comme payée
  Future<void> markAsPaid(String sessionId, {String? label}) async {
    final payments = await loadPayments();
    payments[sessionId] = PaymentInfo(
      paidDate: DateTime.now(),
      label: label,
    );
    await savePayments(payments);
  }

  /// Marque plusieurs séances comme payées
  Future<void> markMultipleAsPaid(List<String> sessionIds, {String? label}) async {
    final payments = await loadPayments();
    final now = DateTime.now();
    for (final sessionId in sessionIds) {
      payments[sessionId] = PaymentInfo(
        paidDate: now,
        label: label,
      );
    }
    await savePayments(payments);
  }

  /// Marque une séance comme non payée
  Future<void> markAsUnpaid(String sessionId) async {
    final payments = await loadPayments();
    payments.remove(sessionId);
    await savePayments(payments);
  }

  /// Marque plusieurs séances comme non payées
  Future<void> markMultipleAsUnpaid(List<String> sessionIds) async {
    final payments = await loadPayments();
    for (final sessionId in sessionIds) {
      payments.remove(sessionId);
    }
    await savePayments(payments);
  }

  /// Vérifie si une séance est payée
  Future<bool> isPaid(String sessionId) async {
    final payments = await loadPayments();
    return payments.containsKey(sessionId);
  }

  /// Récupère les informations de paiement d'une séance
  Future<PaymentInfo?> getPaymentInfo(String sessionId) async {
    final payments = await loadPayments();
    return payments[sessionId];
  }
}
