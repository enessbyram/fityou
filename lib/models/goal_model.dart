// lib/models/goal_model.dart
class GoalModel {
  final int? id;
  final double targetWeight;
  final int days;
  final DateTime? startDate;

  GoalModel({
    this.id,
    required this.targetWeight,
    required this.days,
    this.startDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'target_weight': targetWeight,     // DB kolon adı
      'days': days,
      'start_date': startDate?.toIso8601String(), // DB kolon adı
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'],
      targetWeight: map['target_weight'],
      days: map['days'],
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date']) : null,
    );
  }
}
