class ComplaintComment {
  final String id;
  final String userId;
  final String userName;
  final String commentText;
  final bool isInternalNote;
  final DateTime createdAt;

  ComplaintComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.commentText,
    required this.isInternalNote,
    required this.createdAt,
  });

  factory ComplaintComment.fromJson(Map<String, dynamic> json) {
    return ComplaintComment(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Anonymous',
      commentText: json['comment_text'] ?? '',
      isInternalNote: json['is_internal_note'] == 1 || json['is_internal_note'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class ComplaintAttachment {
  final String id;
  final String filename;
  final int fileSize;
  final String contentType;
  final String uploaderId;
  final String uploaderName;
  final String filePath;
  final String fileType;
  final DateTime createdAt;

  ComplaintAttachment({
    required this.id,
    required this.filename,
    required this.fileSize,
    required this.contentType,
    required this.uploaderId,
    required this.uploaderName,
    this.filePath = '',
    this.fileType = 'document',
    required this.createdAt,
  });

  factory ComplaintAttachment.fromJson(Map<String, dynamic> json) {
    return ComplaintAttachment(
      id: json['id'] ?? '',
      filename: json['filename'] ?? json['file_name'] ?? '',
      fileSize: json['file_size'] ?? 0,
      contentType: json['content_type'] ?? json['mime_type'] ?? '',
      uploaderId: json['uploader_id'] ?? '',
      uploaderName: json['uploader_name'] ?? 'User',
      filePath: json['file_path'] ?? '',
      fileType: json['file_type'] ?? 'document',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'file_size': fileSize,
      'content_type': contentType,
      'uploader_id': uploaderId,
      'uploader_name': uploaderName,
      'file_path': filePath,
      'file_type': fileType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ComplaintHistoryItem {
  final String id;
  final String actorId;
  final String actorName;
  final String eventType;
  final String? fromStatus;
  final String? toStatus;
  final String? fieldName;
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final DateTime createdAt;

  ComplaintHistoryItem({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.eventType,
    this.fromStatus,
    this.toStatus,
    this.fieldName,
    this.oldValue,
    this.newValue,
    this.reason,
    required this.createdAt,
  });

  factory ComplaintHistoryItem.fromJson(Map<String, dynamic> json) {
    return ComplaintHistoryItem(
      id: json['id'] ?? '',
      actorId: json['actor_id'] ?? '',
      actorName: json['actor_name'] ?? 'System',
      eventType: json['event_type'] ?? '',
      fromStatus: json['from_status'],
      toStatus: json['to_status'],
      fieldName: json['field_name'],
      oldValue: json['old_value'],
      newValue: json['new_value'],
      reason: json['reason'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class ComplaintFeedback {
  final String id;
  final int rating;
  final String? comments;
  final bool resolutionSatisfactory;
  final DateTime createdAt;

  ComplaintFeedback({
    required this.id,
    required this.rating,
    this.comments,
    required this.resolutionSatisfactory,
    required this.createdAt,
  });

  factory ComplaintFeedback.fromJson(Map<String, dynamic> json) {
    return ComplaintFeedback(
      id: json['id'] ?? '',
      rating: json['rating'] ?? 5,
      comments: json['comments'],
      resolutionSatisfactory: json['resolution_satisfactory'] ?? true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class Complaint {
  final String id;
  final String trackingNumber;
  final String organizationId;
  final String categoryId;
  final String categoryName;
  final String departmentId;
  final String departmentName;
  final String complainantId;
  final String complainantName;
  final String? assigneeId;
  final String? assigneeName;
  final String title;
  final String description;
  final String? locationContext;
  final String status;
  final String priority;
  final DateTime? slaFirstResponseDue;
  final DateTime? slaResolutionDue;
  final DateTime? firstRespondedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final String? resolutionSummary;
  final String? rejectionReason;
  final int reopenCount;
  final bool isEscalated;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int commentsCount;
  final int attachmentsCount;
  final ComplaintFeedback? feedback;

  final List<ComplaintComment> comments;
  final List<ComplaintAttachment> attachments;
  final List<ComplaintHistoryItem> history;

  Complaint({
    required this.id,
    required this.trackingNumber,
    required this.organizationId,
    required this.categoryId,
    required this.categoryName,
    required this.departmentId,
    required this.departmentName,
    required this.complainantId,
    required this.complainantName,
    this.assigneeId,
    this.assigneeName,
    required this.title,
    required this.description,
    this.locationContext,
    required this.status,
    required this.priority,
    this.slaFirstResponseDue,
    this.slaResolutionDue,
    this.firstRespondedAt,
    this.resolvedAt,
    this.closedAt,
    this.resolutionSummary,
    this.rejectionReason,
    required this.reopenCount,
    required this.isEscalated,
    this.isSynced = false,
    required this.createdAt,
    required this.updatedAt,
    required this.commentsCount,
    required this.attachmentsCount,
    this.feedback,
    this.comments = const [],
    this.attachments = const [],
    this.history = const [],
  });

  String get displayAssignee => (assigneeName != null && assigneeName!.isNotEmpty)
      ? assigneeName!
      : 'Unassigned';

  bool get isAssigned => assigneeId != null && assigneeId!.isNotEmpty;

  factory Complaint.fromJson(Map<String, dynamic> json) {
    var rawComments = json['comments'] as List? ?? [];
    var rawAttachments = json['attachments'] as List? ?? [];
    var rawHistory = json['history'] as List? ?? [];

    return Complaint(
      id: json['id'] ?? '',
      trackingNumber: json['tracking_number'] ?? '',
      organizationId: json['organization_id'] ?? '',
      categoryId: json['category_id'] ?? '',
      categoryName: json['category_name'] ?? 'General',
      departmentId: json['department_id'] ?? '',
      departmentName: json['department_name'] ?? 'Unassigned',
      complainantId: json['complainant_id'] ?? '',
      complainantName: json['complainant_name'] ?? 'User',
      assigneeId: json['assignee_id'],
      assigneeName: json['assignee_name'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      locationContext: json['location_context'],
      status: json['status'] ?? 'SUBMITTED',
      priority: json['priority'] ?? 'MEDIUM',
      slaFirstResponseDue: json['sla_first_response_due'] != null ? DateTime.tryParse(json['sla_first_response_due']) : null,
      slaResolutionDue: json['sla_resolution_due'] != null ? DateTime.tryParse(json['sla_resolution_due']) : null,
      firstRespondedAt: json['first_responded_at'] != null ? DateTime.tryParse(json['first_responded_at']) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at']) : null,
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at']) : null,
      resolutionSummary: json['resolution_summary'],
      rejectionReason: json['rejection_reason'],
      reopenCount: json['reopen_count'] ?? 0,
      isEscalated: json['is_escalated'] == 1 || json['is_escalated'] == true,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      commentsCount: json['comments_count'] ?? rawComments.length,
      attachmentsCount: json['attachments_count'] ?? rawAttachments.length,
      feedback: json['feedback'] != null ? ComplaintFeedback.fromJson(json['feedback']) : null,
      comments: rawComments.map((c) => ComplaintComment.fromJson(c)).toList(),
      attachments: rawAttachments.map((a) => ComplaintAttachment.fromJson(a)).toList(),
      history: rawHistory.map((h) => ComplaintHistoryItem.fromJson(h)).toList(),
    );
  }
}
