class Membership {
  final String id;
  final String organizationId;
  final String organizationName;
  final String orgSlug;
  final String orgType;
  final String role;
  final bool isActive;

  Membership({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.orgSlug,
    required this.orgType,
    required this.role,
    required this.isActive,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      id: json['id'] ?? '',
      organizationId: json['organization_id'] ?? '',
      organizationName: json['organization_name'] ?? '',
      orgSlug: json['org_slug'] ?? '',
      orgType: json['org_type'] ?? '',
      role: json['role'] ?? 'COMPLAINANT',
      isActive: json['is_active'] ?? true,
    );
  }
}

class User {
  final String id;
  final String email;
  final String fullName;
  final bool isPlatformAdmin;
  final List<Membership> memberships;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isPlatformAdmin,
    required this.memberships,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    var rawMemberships = json['memberships'] as List? ?? [];
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      isPlatformAdmin: json['is_platform_admin'] ?? false,
      memberships: rawMemberships.map((m) => Membership.fromJson(m)).toList(),
    );
  }
}
