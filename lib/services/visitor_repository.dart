import '../models/visitor.dart';

abstract class VisitorRepository {
  Future<List<Visitor>> fetchVisitors();

  Future<Visitor> fetchVisitor(String id);

  Future<Visitor> createVisitor(VisitorDraft draft);

  Future<Visitor> updateVisitor(String id, Map<String, dynamic> changes);

  Future<void> deleteVisitor(String id);
}
