class Organization {
  final String id;
  final String name;
  final String slug;
  final String orgType;
  final Map<String, dynamic> settings;
  final bool isActive;

  Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.orgType,
    required this.settings,
    required this.isActive,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      orgType: json['org_type'] ?? 'COLLEGE',
      settings: json['settings'] is Map ? Map<String, dynamic>.from(json['settings']) : {},
      isActive: json['is_active'] ?? true,
    );
  }

  String get typeLabel {
    switch (orgType) {
      case 'COLLEGE':
        return 'Education / College';
      case 'BUSINESS':
        return 'Commercial Business';
      case 'PUBLIC_SERVICE':
        return 'Public Authority';
      case 'CORPORATE':
        return 'Corporate Workplace';
      default:
        return orgType;
    }
  }
}
