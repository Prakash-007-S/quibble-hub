import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/state/auth_provider.dart';
import 'package:frontend/core/state/complaint_provider.dart';
import 'package:frontend/core/widgets/status_badge.dart';
import 'package:frontend/core/widgets/priority_badge.dart';
import 'package:frontend/core/widgets/state_views.dart';
import 'package:frontend/core/widgets/ai_suggestion_card.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'package:frontend/app/splash_screen.dart';

void main() {
  testWidgets('StatusBadge renders correct label and color', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(status: 'IN_PROGRESS'),
        ),
      ),
    );

    expect(find.text('IN PROGRESS'), findsOneWidget);
  });

  testWidgets('PriorityBadge renders correct urgency label', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PriorityBadge(priority: 'CRITICAL'),
        ),
      ),
    );

    expect(find.text('CRITICAL'), findsOneWidget);
  });

  testWidgets('StateViews render appropriately', (WidgetTester tester) async {
    // 1. LoadingView
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LoadingView(message: 'Testing Loading State'),
        ),
      ),
    );
    expect(find.text('Testing Loading State'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 2. EmptyStateView
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateView(
            title: 'Empty List',
            message: 'No records to display',
            actionLabel: 'Create Record',
            onAction: () {},
          ),
        ),
      ),
    );
    expect(find.text('Empty List'), findsOneWidget);
    expect(find.text('No records to display'), findsOneWidget);
    expect(find.text('Create Record'), findsOneWidget);

    // 3. ErrorStateView
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorStateView(
            message: 'Local error occurred',
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.text('Unable to Load Content'), findsOneWidget);
    expect(find.text('Local error occurred'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('AISuggestionCard renders recommendation details and handles apply callback', (WidgetTester tester) async {
    bool applied = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AISuggestionCard(
            suggestion: {
              'category_name': 'Campus Wi-Fi & Internet',
              'department_name': 'IT Infrastructure',
              'recommended_priority': 'HIGH',
              'confidence': 0.94,
              'explanation': 'Keywords matching network failure detected.',
              'is_fallback': false,
            },
            onApply: () {
              applied = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('AI Assistant Recommendation'), findsOneWidget);
    expect(find.text('Campus Wi-Fi & Internet'), findsOneWidget);
    expect(find.text('IT Infrastructure'), findsOneWidget);
    expect(find.text('Confidence: 94%'), findsOneWidget);

    // Tap apply button
    await tester.tap(find.text('Apply AI Recommendations'));
    await tester.pump();
    expect(applied, isTrue);
  });

  testWidgets('LoginScreen renders dual portals (Complainant and Authority) without hardcoded mock complaints', (WidgetTester tester) async {
    final authProvider = AuthProvider();
    final complaintProvider = ComplaintProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<ComplaintProvider>.value(value: complaintProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Quibble Hub'), findsOneWidget);
    expect(find.text('Complainant'), findsOneWidget);
    expect(find.text('Authority Portal'), findsOneWidget);
    expect(find.text('Sign In as Complainant'), findsOneWidget);
    expect(find.text('Admin Identities'), findsOneWidget);
    expect(find.text('Register as Complainant'), findsOneWidget);

    // Verify all demo chips are completely absent
    expect(find.text('Student (Complainant)'), findsNothing);
    expect(find.text('1-Tap Demo Logins (Viva Evaluation):'), findsNothing);
    expect(find.text('Platform Admin'), findsNothing);
  });

  testWidgets('SplashScreen renders brand header and progress indicator', (WidgetTester tester) async {
    final authProvider = AuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: const MaterialApp(
          home: SplashScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Quibble Hub'), findsOneWidget);
    expect(find.text('Autonomous On-Device Local Storage System'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
  });
}
