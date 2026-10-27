import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management_app/core/app_exception.dart';
import 'package:visitor_management_app/core/date_helpers.dart';
import 'package:visitor_management_app/models/visitor.dart';
import 'package:visitor_management_app/models/visitor_status.dart';
import 'package:visitor_management_app/providers/visitor_provider.dart';
import 'package:visitor_management_app/services/visitor_repository.dart';

class InMemoryVisitorRepository implements VisitorRepository {
  final Map<String, Map<String, dynamic>> records = {};
  int _nextId = 1;

  @override
  Future<List<Visitor>> fetchVisitors() async => records.values.map(Visitor.fromJson).toList();

  @override
  Future<Visitor> fetchVisitor(String id) async {
    final record = records[id];
    if (record == null) throw const AppException('Not found', statusCode: 404);
    return Visitor.fromJson(record);
  }

  @override
  Future<Visitor> createVisitor(VisitorDraft draft) async {
    final id = '${_nextId++}';
    records[id] = {...draft.toCreateJson(DateTime.now()), 'id': id};
    return Visitor.fromJson(records[id]!);
  }

  @override
  Future<Visitor> updateVisitor(String id, Map<String, dynamic> changes) async {
    records[id] = {...records[id]!, ...changes};
    return Visitor.fromJson(records[id]!);
  }

  @override
  Future<void> deleteVisitor(String id) async {
    records.remove(id);
  }
}

const _draft = VisitorDraft(
  name: 'Rahul Sharma',
  mobile: '9876543210',
  visitorType: 'Customer',
  project: 'Project A',
  purpose: 'Site visit',
);

void main() {
  late InMemoryVisitorRepository repository;
  late VisitorProvider provider;

  setUp(() {
    repository = InMemoryVisitorRepository();
    provider = VisitorProvider(repository);
  });

  test('registering adds the visitor and updates today count', () async {
    final visitor = await provider.registerVisitor(_draft);

    expect(visitor.status, VisitorStatus.registered);
    expect(provider.visitors, hasLength(1));
    expect(provider.visitorsToday, 1);
  });

  test('check in and check out update status, timestamps and counts', () async {
    final visitor = await provider.registerVisitor(_draft);

    final checkedIn = await provider.checkIn(visitor.id);
    expect(checkedIn.status, VisitorStatus.checkedIn);
    expect(checkedIn.checkInTime, isNotNull);
    expect(provider.currentlyCheckedIn, 1);

    final checkedOut = await provider.checkOut(visitor.id);
    expect(checkedOut.status, VisitorStatus.checkedOut);
    expect(checkedOut.checkOutTime!.isToday, isTrue);
    expect(provider.currentlyCheckedIn, 0);
    expect(provider.checkedOutToday, 1);
  });

  test('cannot check out before checking in', () async {
    final visitor = await provider.registerVisitor(_draft);

    await expectLater(provider.checkOut(visitor.id), throwsA(isA<AppException>()));
  });

  test('duplicate check in is rejected even if local state is stale', () async {
    final visitor = await provider.registerVisitor(_draft);
    repository.records[visitor.id]!['status'] = 'Checked In';

    await expectLater(provider.checkIn(visitor.id), throwsA(isA<AppException>()));
    expect(provider.visitorById(visitor.id)!.status, VisitorStatus.checkedIn);
  });

  test('parallel check in requests only run once', () async {
    final visitor = await provider.registerVisitor(_draft);

    final first = provider.checkIn(visitor.id);
    await expectLater(provider.checkIn(visitor.id), throwsA(isA<AppException>()));
    await first;

    expect(provider.visitorById(visitor.id)!.status, VisitorStatus.checkedIn);
  });

  test('search matches name or mobile', () async {
    await provider.registerVisitor(_draft);

    provider.updateSearch('rahul');
    expect(provider.filteredVisitors, hasLength(1));

    provider.updateSearch('98765');
    expect(provider.filteredVisitors, hasLength(1));

    provider.updateSearch('nobody');
    expect(provider.filteredVisitors, isEmpty);
  });

  test('deleting removes the visitor locally', () async {
    final visitor = await provider.registerVisitor(_draft);

    await provider.deleteVisitor(visitor.id);

    expect(provider.visitors, isEmpty);
    expect(repository.records, isEmpty);
  });
}
