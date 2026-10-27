import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_exception.dart';
import '../core/feedback.dart';
import '../models/visitor.dart';
import '../providers/visitor_provider.dart';
import 'visitor_details/visitor_details_screen.dart';
import 'visitor_form/visitor_form_screen.dart';

Future<void> openVisitorDetails(
  BuildContext context,
  String visitorId, {
  bool refreshOnOpen = true,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => VisitorDetailsScreen(visitorId: visitorId, refreshOnOpen: refreshOnOpen),
    ),
  );
}

Future<void> openRegisterVisitor(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VisitorFormScreen()));
}

Future<void> openEditVisitor(BuildContext context, Visitor visitor) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => VisitorFormScreen(visitor: visitor)));
}

/// Asks for confirmation and deletes. Returns true when the visitor was removed.
Future<bool> deleteVisitorWithConfirmation(BuildContext context, Visitor visitor) async {
  final confirmed = await confirmDelete(context, visitor.name);
  if (!confirmed || !context.mounted) return false;

  try {
    await context.read<VisitorProvider>().deleteVisitor(visitor.id);
    if (context.mounted) showAppSnackBar(context, '${visitor.name} was deleted');
    return true;
  } on AppException catch (e) {
    if (context.mounted) showAppSnackBar(context, e.message, isError: true);
    return e.isNotFound;
  }
}
