import 'dart:convert';

class PractitionerData {
  final String name;
  final String? photoPath;
  final String? notes;
  final String? phone;
  final String? email;

  PractitionerData({
    required this.name,
    this.photoPath,
    this.notes,
    this.phone,
    this.email,
  });

  PractitionerData copyWith({
    String? name,
    String? photoPath,
    String? notes,
    String? phone,
    String? email,
    bool clearPhoto = false,
  }) {
    return PractitionerData(
      name: name ?? this.name,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      notes: notes ?? this.notes,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }

  factory PractitionerData.fromJson(Map<String, dynamic> json) {
    return PractitionerData(
      name: json['name'] as String,
      photoPath: json['photoPath'] as String?,
      notes: json['notes'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'photoPath': photoPath,
      'notes': notes,
      'phone': phone,
      'email': email,
    };
  }

  static Map<String, PractitionerData> mapFromJsonString(String jsonString) {
    final Map<String, dynamic> decoded = json.decode(jsonString);
    return decoded.map((key, value) => MapEntry(
      key,
      PractitionerData.fromJson(value as Map<String, dynamic>),
    ));
  }

  static String mapToJsonString(Map<String, PractitionerData> map) {
    final encoded = map.map((key, value) => MapEntry(key, value.toJson()));
    return json.encode(encoded);
  }
}
