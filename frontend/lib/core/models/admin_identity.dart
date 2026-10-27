class AdminIdentity {
  final int slotNumber;
  final String? fullName;
  final String? email;
  final String? passwordHash;
  final String? salt;
  final bool isConfigured;
  final DateTime? configuredAt;

  AdminIdentity({
    required this.slotNumber,
    this.fullName,
    this.email,
    this.passwordHash,
    this.salt,
    required this.isConfigured,
    this.configuredAt,
  });

  factory AdminIdentity.fromMap(Map<String, dynamic> map) {
    return AdminIdentity(
      slotNumber: map['slot_number'] as int,
      fullName: map['full_name'] as String?,
      email: map['email'] as String?,
      passwordHash: map['password_hash'] as String?,
      salt: map['salt'] as String?,
      isConfigured: (map['is_configured'] as int? ?? 0) == 1,
      configuredAt: map['configured_at'] != null ? DateTime.tryParse(map['configured_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slot_number': slotNumber,
      'full_name': fullName,
      'email': email,
      'password_hash': passwordHash,
      'salt': salt,
      'is_configured': isConfigured ? 1 : 0,
      'configured_at': configuredAt?.toIso8601String(),
    };
  }

  String get id => slotNumber.toString();
  String get displayName => isConfigured ? (fullName ?? 'Admin #$slotNumber') : 'Slot #$slotNumber (Unconfigured)';
}
