// lib/screens/set_goal_screen.dart
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/goal_model.dart';
import 'package:flutter/services.dart';

class SetGoalScreen extends StatefulWidget {
  const SetGoalScreen({super.key});

  @override
  State<SetGoalScreen> createState() => _SetGoalScreenState();
}

class _SetGoalScreenState extends State<SetGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetController = TextEditingController();
  final _daysController = TextEditingController();
  bool _loading = true;
  GoalModel? _existing;

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  void _loadGoal() async {
    final data = await DatabaseHelper.instance.getGoal();
    if (data != null) {
      _existing = GoalModel.fromMap(data);
      _targetController.text = _existing!.targetWeight.toString();
      _daysController.text = _existing!.days.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final goal = GoalModel(
      targetWeight: double.parse(_targetController.text),
      days: int.parse(_daysController.text),
      startDate: DateTime.now(),
    );

    await DatabaseHelper.instance.insertGoal(goal.toMap());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hedef kaydedildi 🎯')));
    Navigator.pop(context);
  }

  void _delete() async {
    await DatabaseHelper.instance.deleteGoal();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hedef silindi')));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _targetController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Kilo Hedefi')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    decoration: const InputDecoration(labelText: 'Hedef Kilo (kg)'),
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu alan' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Kaç gün içinde?'),
                    validator: (v) => v == null || v.isEmpty ? 'Zorunlu alan' : null,
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Kaydet'),
            ),
            if (_existing != null) const SizedBox(height: 10),
            if (_existing != null)
              ElevatedButton(
                onPressed: _delete,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size.fromHeight(50)),
                child: const Text('Hedefi Sil'),
              ),
          ],
        ),
      ),
    );
  }
}
