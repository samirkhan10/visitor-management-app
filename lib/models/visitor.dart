import '../core/date_helpers.dart';
import 'visitor_status.dart';

const visitorTypes = ['Customer', 'Vendor', 'Other'];
const projects = ['Project A', 'Project B', 'Project C'];

class Visitor {
  const Visitor({
    required this.id,
    required this.name,
    required this.mobile,
    this.email,
    required this.visitorType,
    required this.project,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.checkInTime,
    this.checkOutTime,
  });

  final String id;
  final String name;
  final String mobile;
  final String? email;
  final String visitorType;
  final String project;
  final String purpose;
  final VisitorStatus status;
  final DateTime createdAt;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  bool get canCheckIn => status.blockedReason(VisitorStatus.checkedIn) == null;
  bool get canCheckOut => status.blockedReason(VisitorStatus.checkedOut) == null;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory Visitor.fromJson(Map<String, dynamic> json) {
    final email = json['email']?.toString().trim();

    return Visitor(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      mobile: (json['mobile'] ?? '').toString(),
      email: (email == null || email.isEmpty) ? null : email,
      visitorType: (json['visitor_type'] ?? 'Other').toString(),
      project: (json['project'] ?? '').toString(),
      purpose: (json['purpose'] ?? '').toString(),
      status: VisitorStatus.fromLabel(json['status']?.toString()),
      createdAt: parseApiDate(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      checkInTime: parseApiDate(json['check_in_time']),
      checkOutTime: parseApiDate(json['check_out_time']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'email': email,
    'visitor_type': visitorType,
    'project': project,
    'purpose': purpose,
    'status': status.label,
    'created_at': createdAt.toApiString(),
    'check_in_time': checkInTime?.toApiString(),
    'check_out_time': checkOutTime?.toApiString(),
  };
}

/// Editable fields captured by the registration form.
class VisitorDraft {
  const VisitorDraft({
    required this.name,
    required this.mobile,
    this.email,
    required this.visitorType,
    required this.project,
    required this.purpose,
  });

  final String name;
  final String mobile;
  final String? email;
  final String visitorType;
  final String project;
  final String purpose;

  Map<String, dynamic> toJson() {
    final trimmedEmail = email?.trim();
    return {
      'name': name.trim(),
      'mobile': mobile.trim(),
      'email': (trimmedEmail == null || trimmedEmail.isEmpty) ? null : trimmedEmail,
      'visitor_type': visitorType,
      'project': project,
      'purpose': purpose.trim(),
    };
  }

  /// Body for POST /visitors. A new visitor always starts as Registered.
  Map<String, dynamic> toCreateJson(DateTime now) => {
    ...toJson(),
    'status': VisitorStatus.registered.label,
    'created_at': now.toApiString(),
    'check_in_time': null,
    'check_out_time': null,
  };
}
