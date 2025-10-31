// lib/models/user_model.dart
class UserModel {
  final int? id; 
  final double weight;
  final double height;
  final DateTime birthDate;

  UserModel({
    this.id,
    required this.weight,
    required this.height,
    required this.birthDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'height': height,
      'weight': weight,
      'birth_date': birthDate.toIso8601String(), // DB ile birebir uyumlu
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      height: map['height'],
      weight: map['weight'],
      birthDate: DateTime.parse(map['birth_date']),
    );
  }
}
