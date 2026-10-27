import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management_app/models/visitor.dart';
import 'package:visitor_management_app/models/visitor_status.dart';
import 'package:visitor_management_app/theme/app_theme.dart';
import 'package:visitor_management_app/widgets/visitor_card.dart';

void main() {
  final visitor = Visitor(
    id: '1',
    name: 'Rahul Sharma',
    mobile: '9876543210',
    visitorType: 'Customer',
    project: 'Project A',
    purpose: 'Site visit',
    status: VisitorStatus.checkedIn,
    createdAt: DateTime(2026, 10, 26, 10),
  );

  testWidgets('visitor card shows the key details and actions', (tester) async {
    var edited = false;
    var deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: VisitorCard(
            visitor: visitor,
            onTap: () {},
            onEdit: () => edited = true,
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('Checked In'), findsOneWidget);
    expect(find.textContaining('Project A'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit'));
    await tester.tap(find.byTooltip('Delete'));
    expect(edited, isTrue);
    expect(deleted, isTrue);
  });
}
