import 'package:flutter_test/flutter_test.dart';
import 'package:visitor_management_app/core/date_helpers.dart';
import 'package:visitor_management_app/core/validators.dart';
import 'package:visitor_management_app/core/visitor_qr.dart';
import 'package:visitor_management_app/models/visitor.dart';
import 'package:visitor_management_app/models/visitor_status.dart';

void main() {
  group('Visitor JSON', () {
    final sample = <String, dynamic>{
      'id': 'VIS001',
      'name': 'Rahul Sharma',
      'mobile': '9876543210',
      'email': 'rahul@example.com',
      'visitor_type': 'Customer',
      'project': 'Project A',
      'purpose': 'Site Visit',
      'status': 'Registered',
      'created_at': '2026-10-26T10:00:00+05:30',
      'check_in_time': null,
      'check_out_time': null,
    };

    test('parses the sample record', () {
      final visitor = Visitor.fromJson(sample);

      expect(visitor.id, 'VIS001');
      expect(visitor.status, VisitorStatus.registered);
      expect(visitor.checkInTime, isNull);
      expect(visitor.createdAt.toUtc(), DateTime.utc(2026, 10, 26, 4, 30));
      expect(visitor.initials, 'RS');
    });

    test('handles numeric ids and blank email from the API', () {
      final visitor = Visitor.fromJson({...sample, 'id': 7, 'email': ''});

      expect(visitor.id, '7');
      expect(visitor.email, isNull);
    });

    test('round trips through toJson', () {
      final visitor = Visitor.fromJson(sample);
      final copy = Visitor.fromJson(visitor.toJson());

      expect(copy.name, visitor.name);
      expect(copy.status, visitor.status);
      expect(copy.createdAt, visitor.createdAt);
    });

    test('new visitors are created as Registered', () {
      const draft = VisitorDraft(
        name: ' Asha ',
        mobile: '9999999999',
        email: '  ',
        visitorType: 'Vendor',
        project: 'Project B',
        purpose: 'Delivery',
      );

      final body = draft.toCreateJson(DateTime(2026, 10, 26, 9));

      expect(body['status'], 'Registered');
      expect(body['name'], 'Asha');
      expect(body['email'], isNull);
      expect(body['check_in_time'], isNull);
    });
  });

  group('Status rules', () {
    test('registered visitor can only check in', () {
      expect(VisitorStatus.registered.blockedReason(VisitorStatus.checkedIn), isNull);
      expect(VisitorStatus.registered.blockedReason(VisitorStatus.checkedOut), isNotNull);
    });

    test('checked in visitor cannot check in again', () {
      expect(VisitorStatus.checkedIn.blockedReason(VisitorStatus.checkedIn), isNotNull);
      expect(VisitorStatus.checkedIn.blockedReason(VisitorStatus.checkedOut), isNull);
    });

    test('completed visit is locked', () {
      expect(VisitorStatus.checkedOut.blockedReason(VisitorStatus.checkedIn), isNotNull);
      expect(VisitorStatus.checkedOut.blockedReason(VisitorStatus.checkedOut), isNotNull);
    });

    test('status labels are parsed case-insensitively', () {
      expect(VisitorStatus.fromLabel('checked in'), VisitorStatus.checkedIn);
      expect(VisitorStatus.fromLabel('Checked_Out'), VisitorStatus.checkedOut);
    });
  });

  group('QR payload', () {
    test('encodes and decodes the visitor id', () {
      expect(VisitorQr.decode(VisitorQr.encode('42')), '42');
    });

    test('rejects codes that are not visitor passes', () {
      expect(VisitorQr.decode('https://example.com'), isNull);
      expect(VisitorQr.decode('VMS:'), isNull);
      expect(VisitorQr.decode('VMS:12/../34'), isNull);
      expect(VisitorQr.decode(null), isNull);
    });
  });

  group('Validators', () {
    test('mobile must be exactly 10 digits', () {
      expect(Validators.mobile('9876543210'), isNull);
      expect(Validators.mobile('98765'), isNotNull);
      expect(Validators.mobile('98765432100'), isNotNull);
      expect(Validators.mobile(''), isNotNull);
    });

    test('email is optional but validated when entered', () {
      expect(Validators.optionalEmail(''), isNull);
      expect(Validators.optionalEmail('rahul@example.com'), isNull);
      expect(Validators.optionalEmail('rahul@'), isNotNull);
    });
  });

  test('api dates keep the device offset', () {
    final formatted = DateTime(2026, 10, 26, 10, 30).toApiString();
    expect(formatted, startsWith('2026-10-26T10:30:00'));
    expect(DateTime.parse(formatted).toLocal(), DateTime(2026, 10, 26, 10, 30));
  });
}
