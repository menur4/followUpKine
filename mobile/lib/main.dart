import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/session_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/calendar_source_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser les locales françaises
  await initializeDateFormatting('fr_FR', null);

  runApp(const SuiviKineApp());
}

class SuiviKineApp extends StatelessWidget {
  const SuiviKineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: MaterialApp(
        title: 'Mes Séances',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.system,
        home: const AppRouter(),
      ),
    );
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  final SettingsService _settingsService = SettingsService();
  bool _loading = true;
  bool _setupCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    final settings = await _settingsService.loadSettings();
    setState(() {
      _setupCompleted = settings.hasCompletedSetup;
      _loading = false;
    });
  }

  void _onSetupComplete() {
    setState(() {
      _setupCompleted = true;
    });
    // Recharger les sessions après la configuration
    context.read<SessionProvider>().loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_setupCompleted) {
      return CalendarSourceScreen(
        onSetupComplete: _onSetupComplete,
      );
    }

    return const LockScreen(child: DashboardScreen());
  }
}
