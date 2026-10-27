class Department {
  final String id;
  final String organizationId;
  final String name;
  final String code;
  final String? description;
  final bool isActive;

  Department({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.code,
    this.description,
    required this.isActive,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] ?? '',
      organizationId: json['organization_id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'],
      isActive: json['is_active'] ?? true,
    );
  }
}
