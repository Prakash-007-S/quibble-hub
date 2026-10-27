import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/theme.dart';
import '../core/state/auth_provider.dart';
import '../core/widgets/app_scaffold.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/complaints/complaint_list_screen.dart';
import '../features/notifications/notifications_screen.dart';

import 'splash_screen.dart';

class ComplaintApp extends StatelessWidget {
  const ComplaintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quibble Hub',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isInitialized) {
        auth.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isInitialized) {
      return const SplashScreen();
    }

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    return const MainNavigationShell();
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Operational Dashboard',
    'Case Inquiries & Queues',
    'Notifications & Alerts',
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardScreen(onNavigateTab: (idx) => setState(() => _currentIndex = idx)),
      const ComplaintListScreen(),
      const NotificationsScreen(),
    ];

    return AppScaffold(
      title: _titles[_currentIndex],
      currentIndex: _currentIndex,
      onTabSelected: (idx) => setState(() => _currentIndex = idx),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
    );
  }
}
