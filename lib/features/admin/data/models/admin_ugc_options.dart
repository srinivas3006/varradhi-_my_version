class AdminPublicationLevelOption {
  final String value;
  final String label;
  final String description;
  const AdminPublicationLevelOption(this.value, this.label, this.description);
}

/// Centralizes the spec's fixed option lists so they aren't scattered as
/// magic strings across dropdowns/filter chips.
class AdminUgcOptions {
  AdminUgcOptions._();

  static const List<AdminPublicationLevelOption> publicationLevels = [
    AdminPublicationLevelOption('local', 'Local', 'Visible to the village/mandal only'),
    AdminPublicationLevelOption('district', 'District', 'Visible across the district'),
    AdminPublicationLevelOption('state', 'State', 'Visible statewide'),
    AdminPublicationLevelOption('global', 'Global', 'Visible to all app users'),
  ];

  static const List<String> pushNotificationTypes = ['local', 'breaking', 'alert', 'festival', 'promotion'];

  static const List<String> pushNotificationTargets = ['district', 'state', 'village', 'subdistrict', 'city', 'all'];

  static const List<String> bulkActionTypes = ['approve', 'reject', 'flag', 'increase_trust', 'block'];

  static const List<String> logActionTypes = [
    'ALL',
    'APPROVE',
    'REJECT',
    'FLAG',
    'BLOCK_UPLOADER',
    'UNBLOCK_UPLOADER',
    'INCREASE_TRUST',
    'DECREASE_TRUST',
  ];

  static const List<String> reportStatuses = ['PENDING', 'REVIEWED', 'DISMISSED', 'ALL'];

  static const List<String> otpStatuses = ['ALL', 'SENT', 'DELIVERED', 'FAILED', 'EXPIRED', 'PENDING'];
}
