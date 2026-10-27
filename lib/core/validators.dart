class Validators {
  Validators._();

  static final _mobilePattern = RegExp(r'^\d{10}$');
  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[a-zA-Z]{2,}$');

  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? mobile(String? value) {
    final mobile = value?.trim() ?? '';
    if (mobile.isEmpty) return 'Mobile number is required';
    if (!_mobilePattern.hasMatch(mobile)) {
      return 'Enter a valid 10 digit mobile number';
    }
    return null;
  }

  static String? optionalEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  static String? selection(Object? value, String fieldName) {
    if (value == null) return 'Please select $fieldName';
    return null;
  }
}
