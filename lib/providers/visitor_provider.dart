import 'package:flutter/foundation.dart';

import '../core/app_exception.dart';
import '../core/date_helpers.dart';
import '../models/visitor.dart';
import '../models/visitor_status.dart';
import '../services/visitor_repository.dart';

class VisitorProvider extends ChangeNotifier {
  VisitorProvider(this._repository);

  final VisitorRepository _repository;

  List<Visitor> _visitors = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _loadError;

  String _searchQuery = '';
  VisitorStatus? _statusFilter;

  final Set<String> _busyVisitorIds = {};

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get loadError => _loadError;
  String get searchQuery => _searchQuery;
  VisitorStatus? get statusFilter => _statusFilter;

  List<Visitor> get visitors => List.unmodifiable(_visitors);

  List<Visitor> get filteredVisitors {
    final query = _searchQuery.trim().toLowerCase();
    return _visitors.where((visitor) {
      final matchesStatus = _statusFilter == null || visitor.status == _statusFilter;
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      return visitor.name.toLowerCase().contains(query) || visitor.mobile.contains(query);
    }).toList();
  }

  List<Visitor> get recentVisitors => _visitors.take(5).toList();

  int get visitorsToday => _visitors.where((v) => v.createdAt.isToday).length;

  int get currentlyCheckedIn => _visitors.where((v) => v.status == VisitorStatus.checkedIn).length;

  int get checkedOutToday => _visitors
      .where((v) => v.status == VisitorStatus.checkedOut && (v.checkOutTime?.isToday ?? false))
      .length;

  bool isBusy(String visitorId) => _busyVisitorIds.contains(visitorId);

  Visitor? visitorById(String id) {
    for (final visitor in _visitors) {
      if (visitor.id == id) return visitor;
    }
    return null;
  }

  Future<void> loadVisitors() async {
    if (_isLoading) return;

    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      _visitors = await _repository.fetchVisitors();
      _sortVisitors();
    } on AppException catch (e) {
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Something went wrong while loading visitors.';
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  void updateSearch(String query) {
    if (query == _searchQuery) return;
    _searchQuery = query;
    notifyListeners();
  }

  void updateStatusFilter(VisitorStatus? status) {
    if (status == _statusFilter) return;
    _statusFilter = status;
    notifyListeners();
  }

  Future<Visitor> registerVisitor(VisitorDraft draft) async {
    final visitor = await _repository.createVisitor(draft);
    _upsert(visitor);
    return visitor;
  }

  Future<Visitor> editVisitor(String id, VisitorDraft draft) async {
    final visitor = await _runForVisitor(id, () async {
      final current = visitorById(id) ?? await _repository.fetchVisitor(id);
      // Send the full record so status and timestamps survive even if the API replaces on PUT.
      return _repository.updateVisitor(id, {...current.toJson(), ...draft.toJson()});
    });
    _upsert(visitor);
    return visitor;
  }

  Future<void> deleteVisitor(String id) async {
    await _runForVisitor(id, () => _repository.deleteVisitor(id));
    _visitors.removeWhere((v) => v.id == id);
    notifyListeners();
  }

  /// Always hits the API so a scanned pass reflects the latest server state.
  Future<Visitor> fetchVisitor(String id) async {
    try {
      final visitor = await _repository.fetchVisitor(id);
      _upsert(visitor);
      return visitor;
    } on AppException catch (e) {
      if (e.isNotFound) _removeLocally(id);
      rethrow;
    }
  }

  Future<Visitor> checkIn(String id) => _moveVisitorTo(id, VisitorStatus.checkedIn);

  Future<Visitor> checkOut(String id) => _moveVisitorTo(id, VisitorStatus.checkedOut);

  Future<Visitor> _moveVisitorTo(String id, VisitorStatus target) {
    return _runForVisitor(id, () async {
      // Re-read before writing so a stale screen (or a second device)
      // can't check the same visitor in twice.
      final latest = await _repository.fetchVisitor(id);
      final reason = latest.status.blockedReason(target);
      if (reason != null) {
        _upsert(latest);
        throw AppException(reason);
      }

      final now = DateTime.now().toApiString();
      final changes = <String, dynamic>{
        ...latest.toJson(),
        'status': target.label,
        if (target == VisitorStatus.checkedIn) 'check_in_time': now,
        if (target == VisitorStatus.checkedOut) 'check_out_time': now,
      };

      final updated = await _repository.updateVisitor(id, changes);
      _upsert(updated);
      return updated;
    });
  }

  Future<T> _runForVisitor<T>(String id, Future<T> Function() action) async {
    if (_busyVisitorIds.contains(id)) {
      throw const AppException('Please wait, this visitor is already being updated.');
    }

    _busyVisitorIds.add(id);
    notifyListeners();
    try {
      return await action();
    } on AppException catch (e) {
      if (e.isNotFound) _removeLocally(id);
      rethrow;
    } finally {
      _busyVisitorIds.remove(id);
      notifyListeners();
    }
  }

  void _upsert(Visitor visitor) {
    final index = _visitors.indexWhere((v) => v.id == visitor.id);
    if (index == -1) {
      _visitors = [visitor, ..._visitors];
    } else {
      _visitors = [..._visitors]..[index] = visitor;
    }
    _sortVisitors();
    notifyListeners();
  }

  void _removeLocally(String id) {
    _visitors = _visitors.where((v) => v.id != id).toList();
    notifyListeners();
  }

  void _sortVisitors() {
    _visitors.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
