/// QR payload format: `VMS:<visitorId>`.
/// The prefix lets the scanner reject random QR codes before hitting the API.
class VisitorQr {
  VisitorQr._();

  static const _prefix = 'VMS:';
  static final _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,40}$');

  static String encode(String visitorId) => '$_prefix$visitorId';

  static String? decode(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (!value.startsWith(_prefix)) return null;

    final id = value.substring(_prefix.length).trim();
    return _idPattern.hasMatch(id) ? id : null;
  }
}
