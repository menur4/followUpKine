class Session {
  final String id;
  final DateTime date;
  final String practitioner;
  final bool paid;
  final DateTime? paidDate;
  final String? paymentLabel;
  final String? location;
  final String? time;

  Session({
    required this.id,
    required this.date,
    required this.practitioner,
    required this.paid,
    this.paidDate,
    this.paymentLabel,
    this.location,
    this.time,
  });

  /// Crée une copie de la session avec des valeurs modifiées
  Session copyWith({
    String? id,
    DateTime? date,
    String? practitioner,
    bool? paid,
    DateTime? paidDate,
    String? paymentLabel,
    String? location,
    String? time,
    bool clearPaymentInfo = false,
  }) {
    return Session(
      id: id ?? this.id,
      date: date ?? this.date,
      practitioner: practitioner ?? this.practitioner,
      paid: paid ?? this.paid,
      paidDate: clearPaymentInfo ? null : (paidDate ?? this.paidDate),
      paymentLabel: clearPaymentInfo ? null : (paymentLabel ?? this.paymentLabel),
      location: location ?? this.location,
      time: time ?? this.time,
    );
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      practitioner: json['practitioner'] as String,
      paid: json['paid'] as bool,
      paidDate: json['paidDate'] != null
          ? DateTime.parse(json['paidDate'] as String)
          : null,
      paymentLabel: json['paymentLabel'] as String?,
      location: json['location'] as String?,
      time: json['time'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'practitioner': practitioner,
      'paid': paid,
      'paidDate': paidDate?.toIso8601String(),
      'paymentLabel': paymentLabel,
      'location': location,
      'time': time,
    };
  }

  bool get isFuture => date.isAfter(DateTime.now());

  /// Indique si la séance peut être marquée comme payée
  /// (séances passées ou du jour uniquement)
  bool get canBePaid => !isFuture;
}

class MonthlyStats {
  final String month;
  final int sortKey;
  final Map<String, int> countByPractitioner;
  final int total;

  MonthlyStats({
    required this.month,
    required this.sortKey,
    required this.countByPractitioner,
    required this.total,
  });

  /// Helper pour obtenir le count d'un praticien
  int getCount(String practitioner) {
    return countByPractitioner[practitioner] ?? 0;
  }
}

class PractitionerStats {
  final String name;
  final int count;
  final double percentage;

  PractitionerStats({
    required this.name,
    required this.count,
    required this.percentage,
  });
}

class PaymentStats {
  final int paid2025;
  final int paid2026;
  final int pending;
  final int total;

  PaymentStats({
    required this.paid2025,
    required this.paid2026,
    required this.pending,
    required this.total,
  });
}
