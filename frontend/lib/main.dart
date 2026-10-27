import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/state/auth_provider.dart';
import 'core/state/complaint_provider.dart';
import 'app/app.dart';

void main() {
  // Ensure framework bindings are ready without blocking the UI thread
  WidgetsFlutterBinding.ensureInitialized();

  // Launch Flutter UI immediately to eliminate launch delay and startup black screens
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ComplaintProvider>(create: (_) => ComplaintProvider()),
      ],
      child: const ComplaintApp(),
    ),
  );
}
