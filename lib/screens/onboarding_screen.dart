import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/user_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  DateTime? _selectedBirthDate;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate() || _selectedBirthDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldurun')));
      return;
    }

    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);

    if (height == null || weight == null) return;

    final user = UserModel(
      id: 1,
      height: height,
      weight: weight,
      birthDate: _selectedBirthDate!,
    );

    await DatabaseHelper.instance.insertUser(user.toMap());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);

    // Ana ekrana geçiş
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => _GoToHomePlaceholder()),
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hoşgeldin!')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Boy (cm)'),
                validator: (value) => value == null || value.isEmpty ? 'Boy giriniz' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kilo (kg)'),
                validator: (value) => value == null || value.isEmpty ? 'Kilo giriniz' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedBirthDate == null
                          ? 'Doğum tarihi seçiniz'
                          : DateFormat('yyyy-MM-dd').format(_selectedBirthDate!),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickBirthDate,
                    child: const Text('Seç'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveUser,
                child: const Text('Başla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder to trigger HomeWrapper in main.dart
class _GoToHomePlaceholder extends StatefulWidget {
  const _GoToHomePlaceholder();

  @override
  State<_GoToHomePlaceholder> createState() => _GoToHomePlaceholderState();
}

class _GoToHomePlaceholderState extends State<_GoToHomePlaceholder> {
  @override
  void initState() {
    super.initState();
    // Post frame callback ile context güvenli kullanımı
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
