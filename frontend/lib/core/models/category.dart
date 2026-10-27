class Category {
  final String id;
  final String organizationId;
  final String departmentId;
  final String? departmentName;
  final String name;
  final String? description;
  final String defaultPriority;
  final bool isActive;

  Category({
    required this.id,
    required this.organizationId,
    required this.departmentId,
    this.departmentName,
    required this.name,
    this.description,
    required this.defaultPriority,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      organizationId: json['organization_id'] ?? '',
      departmentId: json['department_id'] ?? '',
      departmentName: json['department_name'],
      name: json['name'] ?? '',
      description: json['description'],
      defaultPriority: json['default_priority'] ?? 'MEDIUM',
      isActive: json['is_active'] ?? true,
    );
  }
}
