import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:intl/intl.dart';
import 'db/database_helper.dart';
import 'models/user_model.dart';
import 'models/goal_model.dart';
import 'screens/onboarding_screen.dart';
import 'screens/update_info_screen.dart';
import 'screens/set_goal_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'widgets/info_card.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitYouApp());
}

class FitYouApp extends StatelessWidget {
  const FitYouApp({super.key});

  Future<bool> _checkFirstTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('isFirstTime') ?? true;
      
      // If SharedPreferences says it's not first time, check if user data exists
      if (!isFirstTime) {
        final userData = await DatabaseHelper.instance.getUser();
        if (userData == null) {
          // User data doesn't exist, reset to first time
          await prefs.setBool('isFirstTime', true);
          return true;
        }
      }
      
      return isFirstTime;
    } catch (e) {
      debugPrint("Error checking first time: $e");
      return true; // Default to onboarding if there's an error
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitYou',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, fontFamily: 'Poppins'),
      home: FutureBuilder<bool>(
        future: _checkFirstTime(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Başlatılıyor...'),
                  ],
                ),
              ),
            );
          }
          return snapshot.data! ? const OnboardingScreen() : const HomeWrapper();
        },
      ),
    );
  }
}

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  UserModel? _user;
  GoalModel? _goal;
  int _todaySteps = 0;
  int _todayWaterMl = 0;
  StreamSubscription<StepCount>? _stepCountStream;
  int _initialStepCount = -1;
  bool _isLoading = true;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadAll();
    // Delay pedometer start to not block the initial loading
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _startPedometer();
    });
  }

  @override
  void dispose() {
    _stepCountStream?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _flutterLocalNotificationsPlugin.initialize(settings);
  }

  Future _showNotification(String title, String body) async {
    const android = AndroidNotificationDetails(
      'fityou_channel',
      'FitYou Channel',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const platform = NotificationDetails(android: android, iOS: ios);
    await _flutterLocalNotificationsPlugin.show(0, title, body, platform);
  }

  void _startPedometer() {
    try {
      _stepCountStream = Pedometer.stepCountStream.listen((event) async {
        try {
          final steps = event.steps;
          if (_initialStepCount == -1) {
            _initialStepCount = steps;
          }
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final counted = steps - _initialStepCount;
          final safeCounted = counted < 0 ? steps : counted;
          _todaySteps = safeCounted;
          
          // Run database operation in background to avoid blocking UI
          DatabaseHelper.instance.insertOrUpdateSteps(today, _todaySteps).catchError((e) {
            debugPrint("Error updating steps: $e");
            return 0; // Return default value for error case
          });
          
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint("Error processing steps: $e");
        }
      }, onError: (e) {
        debugPrint("Pedometer error: $e");
      });
    } catch (e) {
      debugPrint("Pedometer init failed: $e");
    }
  }

  Future<void> _loadAll() async {
    try {
      setState(() => _isLoading = true);
      
      final userMap = await DatabaseHelper.instance.getUser();
      if (userMap != null) _user = UserModel.fromMap(userMap);
      
      final goalMap = await DatabaseHelper.instance.getGoal();
      if (goalMap != null) _goal = GoalModel.fromMap(goalMap);
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _todaySteps = await DatabaseHelper.instance.getStepsByDate(today);
      _todayWaterMl = await DatabaseHelper.instance.getWaterByDate(today);
      
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateWaterNeed(double weightKg) => weightKg * 0.033;

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) age--;
    return age;
  }

  String _formatDouble(double v) => v.toStringAsFixed(2);

  int? _calculateDailyStepsNeededForGoal() {
    if (_user == null || _goal == null) return null;
    final diff = (_user!.weight - _goal!.targetWeight);
    if (diff <= 0 || _goal!.days <= 0) return 0;
    final totalKcalToLose = diff * 7700;
    final dailyKcal = totalKcalToLose / _goal!.days;
    final stepsPerDay = dailyKcal / 0.04;
    return stepsPerDay.ceil();
  }

  Future<void> _addWater(int ml) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await DatabaseHelper.instance.insertWater(today, ml);
      _todayWaterMl = await DatabaseHelper.instance.getWaterByDate(today);
      setState(() {});
    } catch (e) {
      debugPrint("Error adding water: $e");
    }
  }

  Future<void> _refresh() async => _loadAll();

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _user == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Yükleniyor...'),
            ],
          ),
        ),
      );
    }

    final age = _calculateAge(_user!.birthDate);
    final waterNeedLiters = _calculateWaterNeed(_user!.weight);
    final recommendedMl = (waterNeedLiters * 1000).toInt();
    final dailyStepsForGoal = _calculateDailyStepsNeededForGoal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitYou'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              _showNotification('Hatırlatma', 'Hadi biraz hareket et ve su iç! 💧');
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              InfoCard(title: 'Boy', value: '${_user!.height.toInt()} cm', icon: Icons.height),
              const SizedBox(height: 10),
              InfoCard(title: 'Kilo', value: '${_user!.weight.toInt()} kg', icon: Icons.monitor_weight),
              const SizedBox(height: 10),
              InfoCard(title: 'Yaş', value: '$age', icon: Icons.cake),
              const SizedBox(height: 10),
              InfoCard(title: 'Atılan Adım', value: '$_todaySteps adım', icon: Icons.directions_walk),
              const SizedBox(height: 10),
              InfoCard(title: 'Su (öneri)', value: '${_formatDouble(waterNeedLiters)} L', icon: Icons.water_drop),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Text('Bugün içilen: ${(_todayWaterMl / 1000).toStringAsFixed(2)} L / ${(recommendedMl/1000).toStringAsFixed(2)} L'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(onPressed: () => _addWater(250), child: const Text('1 Bardak (250ml)')),
                          const SizedBox(width: 8),
                          ElevatedButton(onPressed: () => _addWater(500), child: const Text('1 Büyük (500ml)')),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_goal != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text('Hedef: ${_goal!.targetWeight} kg (${_goal!.days} gün)'),
                        const SizedBox(height: 6),
                        Text(dailyStepsForGoal == null
                            ? 'Hedef hesaplanamıyor'
                            : 'Günlük hedef adım: $dailyStepsForGoal adım'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdateInfoScreen()));
                        await _loadAll();
                      },
                      child: const Text('Bilgileri Güncelle'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SetGoalScreen()));
                        await _loadAll();
                      },
                      child: const Text('Kilo Hedefi'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Not: Uygulamayı yenilemek için ekranı aşağı çek.'),
            ],
          ),
        ),
      ),
    );
  }
}
