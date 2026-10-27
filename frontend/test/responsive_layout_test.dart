import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/widgets/status_badge.dart';
import 'package:frontend/core/widgets/priority_badge.dart';
import 'package:frontend/core/widgets/ai_suggestion_card.dart';

void main() {
  group('Responsive Layout & Overflow Tests', () {
    testWidgets('Metadata chips and status badges wrap gracefully on narrow 320px phone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const PriorityBadge(priority: 'MEDIUM'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: const Text(
                        'Housekeeping Department Very Long Title',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('On-Device Only', style: TextStyle(fontSize: 10)),
                  ),
                  const Text('Oct 22, 2026, 05:40 PM', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure no RenderFlex overflow error occurred
      expect(tester.takeException(), isNull);
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('On-Device Only'), findsOneWidget);
    });

    testWidgets('Investigation desk header and action buttons wrap cleanly on narrow 320px phone', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Responsive Header Wrap
                  LayoutBuilder(
                    builder: (headerCtx, headerConstraints) {
                      return Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: headerConstraints.maxWidth),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, size: 16),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Complaint Officer Investigation Desk',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: const Text(
                                'Dr. S. Ramanathan (Campus Grievance Officer)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Responsive Action buttons Wrap
                  LayoutBuilder(
                    builder: (btnCtx, btnConstraints) {
                      final maxBtnWidth = btnConstraints.maxWidth;
                      Widget buildBtn(String label) => ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxBtnWidth),
                            child: ElevatedButton(
                              onPressed: () {},
                              child: Text(label, textAlign: TextAlign.center, softWrap: true),
                            ),
                          );

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildBtn('👤 Assign Admin Slot'),
                          buildBtn('👁️ Mark Under Review'),
                          buildBtn('⚡ Start Investigation'),
                          buildBtn('⚖️ Change Priority'),
                          buildBtn('❓ Request Information from Complainant'),
                          buildBtn('✅ Resolve Grievance'),
                          buildBtn('❌ Reject Grievance'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Complaint Officer Investigation Desk'), findsOneWidget);
      expect(find.text('👤 Assign Admin Slot'), findsOneWidget);
      expect(find.text('✅ Resolve Grievance'), findsOneWidget);
    });

    testWidgets('Complainant & Officer info strip handles long names without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (infoCtx, infoConstraints) {
                  final maxItemWidth = infoConstraints.maxWidth;
                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxItemWidth),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline_rounded, size: 14),
                            SizedBox(width: 5),
                            Text('Complainant: ', style: TextStyle(fontSize: 11.5)),
                            Flexible(
                              child: Text(
                                'Prakash Extremely Long Complainant Name For Testing',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxItemWidth),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_ind_outlined, size: 14),
                            SizedBox(width: 4),
                            Text('Officer: ', style: TextStyle(fontSize: 11.5)),
                            Flexible(
                              child: Text(
                                'Dr. S. Ramanathan (Campus Grievance Officer Slot #1)',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Complainant: '), findsOneWidget);
      expect(find.text('Officer: '), findsOneWidget);
    });

    testWidgets('High system font scaling (1.4x) renders without overflow on 360px screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'jdjshwh2bwhash extremely long complaint title for testing text wrapping under large font',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                            softWrap: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const StatusBadge(status: 'SUBMITTED'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        const PriorityBadge(priority: 'MEDIUM'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          child: const Text('Housekeeping Department', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SUBMITTED'), findsOneWidget);
      expect(find.text('MEDIUM'), findsOneWidget);
    });

    testWidgets('Landscape tablet mode (1024x600) renders centered layout with max bounds', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final horizontalMargin = isWide ? (constraints.maxWidth - 700) / 2 : 0.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
                  child: Column(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: const Text('Wide Screen Adaptive Layout Test Content'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Wide Screen Adaptive Layout Test Content'), findsOneWidget);
    });

    testWidgets('AISuggestionCard renders safely under 320px narrow constraint', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AISuggestionCard(
                suggestion: {
                  'category_name': 'Campus Facilities & Sanitation',
                  'department_name': 'Physical Plant & Operations Department',
                  'recommended_priority': 'CRITICAL',
                  'confidence': 0.96,
                  'explanation': 'Critical plumbing blockage detected requiring immediate dispatch.',
                  'is_fallback': true,
                },
                onApply: () {},
              ),
            ),
          ),
        ),
      );

      final err = tester.takeException();
      if (err is FlutterError) {
        // ignore: avoid_print
        print(err.toStringDeep());
      }
      expect(err, isNull);
      expect(find.text('AI Assistant Recommendation'), findsOneWidget);
      expect(find.text('NLP Rule Engine'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);
    });
  });
}
