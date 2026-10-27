enum VisitorStatus {
  registered('Registered'),
  checkedIn('Checked In'),
  checkedOut('Checked Out');

  const VisitorStatus(this.label);

  final String label;

  static VisitorStatus fromLabel(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('_', ' ');
    return VisitorStatus.values.firstWhere(
      (status) => status.label.toLowerCase() == normalized,
      orElse: () => VisitorStatus.registered,
    );
  }

  /// Returns a message explaining why moving to [target] is not allowed,
  /// or null when the transition is valid.
  String? blockedReason(VisitorStatus target) {
    switch (target) {
      case VisitorStatus.checkedIn:
        if (this == VisitorStatus.checkedIn) {
          return 'Visitor is already checked in.';
        }
        if (this == VisitorStatus.checkedOut) {
          return 'This visit is already completed. Register the visitor again for a new visit.';
        }
        return null;
      case VisitorStatus.checkedOut:
        if (this == VisitorStatus.registered) {
          return 'Visitor has to check in before checking out.';
        }
        if (this == VisitorStatus.checkedOut) {
          return 'Visitor has already checked out.';
        }
        return null;
      case VisitorStatus.registered:
        return 'Status cannot be moved back to Registered.';
    }
  }
}
