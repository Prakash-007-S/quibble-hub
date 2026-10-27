import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/complaint.dart';
import '../../core/services/evidence_service.dart';
import '../../core/state/auth_provider.dart';
import '../../core/state/complaint_provider.dart';
import '../../core/widgets/priority_badge.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final String complaintId;

  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  bool _isInternalNote = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final prov = Provider.of<ComplaintProvider>(context, listen: false);
      prov.loadComplaintDetail(widget.complaintId, isComplainant: auth.isComplainant);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _showTransitionDialog({
    required String title,
    required String targetStatus,
    bool requireResolutionSummary = false,
    bool requireRejectionReason = false,
  }) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                requireResolutionSummary
                    ? 'Please describe the steps taken and outcome summary:'
                    : requireRejectionReason
                        ? 'Please specify the exact justification for rejecting this grievance:'
                        : 'Provide notes or reason for this status change (optional):',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: requireResolutionSummary
                      ? 'Describe actions taken, diagnosis, and resolution outcome...'
                      : 'Enter details...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = textController.text.trim();
              if ((requireResolutionSummary || requireRejectionReason) && text.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter at least 5 characters')),
                );
                return;
              }

              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final user = auth.currentUser;
              final prov = Provider.of<ComplaintProvider>(context, listen: false);

              final success = await prov.transitionStatus(
                complaintId: widget.complaintId,
                toStatus: targetStatus,
                actorId: user?.id ?? 'system',
                actorName: user?.fullName ?? 'Administrator',
                resolutionSummary: requireResolutionSummary ? text : null,
                reason: (!requireResolutionSummary && text.isNotEmpty) ? text : null,
              );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Status updated to $targetStatus'), backgroundColor: AppTheme.statusResolved),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    int rating = 5;
    final commentsController = TextEditingController();
    bool satisfactory = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Resolution Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How satisfied are you with the resolution?', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starVal = index + 1;
                    return IconButton(
                      icon: Icon(
                        starVal <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber.shade700,
                        size: 32,
                      ),
                      onPressed: () => setDialogState(() => rating = starVal),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Resolution is satisfactory', style: TextStyle(fontSize: 13)),
                  value: satisfactory,
                  onChanged: (v) => setDialogState(() => satisfactory = v ?? true),
                ),
                TextField(
                  controller: commentsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Additional comments or feedback (optional)...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final prov = Provider.of<ComplaintProvider>(context, listen: false);
                final success = await prov.submitFeedback(
                  complaintId: widget.complaintId,
                  rating: rating,
                  comments: commentsController.text.trim().isNotEmpty ? commentsController.text.trim() : null,
                  resolutionSatisfactory: satisfactory,
                );
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Feedback submitted. Thank you!'), backgroundColor: AppTheme.statusResolved),
                  );
                }
              },
              child: const Text('Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final prov = Provider.of<ComplaintProvider>(context, listen: false);
    final success = await prov.addComment(
      complaintId: widget.complaintId,
      userId: user.id,
      userName: user.fullName,
      commentText: text,
      isInternalNote: _isInternalNote,
    );

    if (success) {
      _commentController.clear();
      setState(() => _isInternalNote = false);
    }
  }

  Future<void> _showAssignAdminDialog() async {
    final admins = await AppDatabase.instance.getAdminIdentities();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_ind_outlined, color: AppTheme.darkSlate),
            SizedBox(width: 8),
            Text('Assign Administrator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select one of the 4 designated administrator slots to handle this grievance investigation:',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            const SizedBox(height: 12),
            ...admins.map((slot) {
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: slot.isConfigured ? AppTheme.primaryLight : Colors.grey.shade200,
                  child: Text(
                    '${slot.slotNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: slot.isConfigured ? AppTheme.primaryDark : Colors.grey.shade600,
                    ),
                  ),
                ),
                title: Text(
                  slot.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                subtitle: Text(
                  slot.isConfigured ? slot.email! : 'Designated slot (not yet configured)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () async {
                  Navigator.pop(ctx);
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final prov = Provider.of<ComplaintProvider>(context, listen: false);
                  final user = auth.currentUser;

                  final success = await prov.assignComplaint(
                    complaintId: widget.complaintId,
                    adminSlotId: slot.id,
                    adminName: slot.displayName,
                    actorId: user?.id ?? 'admin',
                    actorName: user?.fullName ?? 'Administrator',
                  );

                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Case assigned to ${slot.displayName}'),
                        backgroundColor: AppTheme.statusResolved,
                      ),
                    );
                  }
                },
              );
            }),
          ],
        ),
      ),
      actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showChangePriorityDialog(String currentPriority) {
    String selected = currentPriority;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Change Case Priority', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select new priority level:', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setDialogState(() => selected = v ?? selected),
                ),
                const SizedBox(height: 12),
                const Text('Justification for priority change:', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Escalated due to severe safety risk...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                if (reason.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Please provide a justification for changing priority')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final prov = Provider.of<ComplaintProvider>(context, listen: false);
                final user = auth.currentUser;

                final success = await prov.changePriority(
                  complaintId: widget.complaintId,
                  priority: selected,
                  reason: reason,
                  actorId: user?.id ?? 'admin',
                  actorName: user?.fullName ?? 'Administrator',
                );

                if (success && mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Priority updated to $selected'), backgroundColor: AppTheme.statusResolved),
                  );
                }
              },
              child: const Text('Apply Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordActionDialog() {
    final actionController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.build_circle_outlined, color: AppTheme.darkSlate),
            SizedBox(width: 8),
            Text('Record Action Taken', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Document concrete investigative or corrective steps performed. This is published to the case history and visible to the complainant:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: actionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'e.g., On-site inspection performed with the Facilities engineer. Defective equipment identified and replacement ordered...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = actionController.text.trim();
              if (text.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please describe the action taken in detail (min 5 chars)')),
                );
                return;
              }
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final prov = Provider.of<ComplaintProvider>(context, listen: false);
              final user = auth.currentUser;

              final success = await prov.recordActionTaken(
                complaintId: widget.complaintId,
                actionDetails: text,
                actorId: user?.id ?? 'admin',
                actorName: user?.fullName ?? 'Administrator',
              );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Action recorded successfully'), backgroundColor: AppTheme.statusResolved),
                );
              }
            },
            child: const Text('Record Action'),
          ),
        ],
      ),
    );
  }

  void _showRequestInfoDialog() {
    final infoController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.contact_support_outlined, color: Colors.purple),
            SizedBox(width: 8),
            Text('Request Additional Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Specify what additional information or evidence is required from the complainant. The case will move to "Awaiting Information" status:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: infoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g., Please provide your registration number, room number, or photo of receipt...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
            onPressed: () async {
              final text = infoController.text.trim();
              if (text.length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please describe the requested info in detail (min 5 chars)')),
                );
                return;
              }
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final prov = Provider.of<ComplaintProvider>(context, listen: false);
              final user = auth.currentUser;

              final success = await prov.requestAdditionalInformation(
                complaintId: widget.complaintId,
                requestMessage: text,
                actorId: user?.id ?? 'admin',
                actorName: user?.fullName ?? 'Administrator',
              );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request sent to complainant'), backgroundColor: Colors.purple),
                );
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _showComplainantResponseSheet() {
    final responseController = TextEditingController();
    final List<PickedEvidence> pickedEvidence = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.reply_all_rounded, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Respond to Officer Request',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Provide the requested information or clarification and optionally attach photos, documents, or recordings:',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: responseController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter your detailed explanation or answer here...',
                ),
              ),
              const SizedBox(height: 12),

              // Evidence attachment buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: const Text('Photo', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final item = await EvidenceService.pickEvidence('photo');
                      if (item != null) {
                        setSheetState(() => pickedEvidence.add(item));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file_rounded, size: 16),
                    label: const Text('Document', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final item = await EvidenceService.pickEvidence('document');
                      if (item != null) {
                        setSheetState(() => pickedEvidence.add(item));
                      }
                    },
                  ),
                ],
              ),
              if (pickedEvidence.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: pickedEvidence.map((e) {
                    return Chip(
                      label: Text(e.fileName, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setSheetState(() => pickedEvidence.remove(e)),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final text = responseController.text.trim();
                    if (text.isEmpty && pickedEvidence.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Please enter a response or attach evidence')),
                      );
                      return;
                    }

                    Navigator.pop(sheetCtx);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final prov = Provider.of<ComplaintProvider>(context, listen: false);
                    final user = auth.currentUser;

                    final success = await prov.submitComplainantResponse(
                      complaintId: widget.complaintId,
                      responseText: text.isNotEmpty ? text : 'Complainant uploaded additional requested evidence.',
                      complainantId: user?.id ?? 'user',
                      complainantName: user?.fullName ?? 'Complainant',
                      evidenceFiles: pickedEvidence,
                    );

                    if (success && mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Response and evidence submitted to Complaint Officer'),
                          backgroundColor: AppTheme.statusResolved,
                        ),
                      );
                    }
                  },
                  child: const Text('Submit Response & Evidence'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewPhotoFullscreen(String filePath, String filename) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(filename, style: const TextStyle(fontSize: 14, color: Colors.white)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            InteractiveViewer(
              child: Image.file(
                File(filePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Could not render image file', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(ComplaintAttachment att) async {
    try {
      final res = await EvidenceService.openFile(att.filePath);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'Could not open file'),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching file: $e'),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final prov = Provider.of<ComplaintProvider>(context);
    final complaint = prov.currentDetail;
    final isComplainant = auth.isComplainant;
    final isStaffOrAdmin = auth.isStaff || auth.isDeptManager || auth.isOrgAdmin;
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    if (prov.isLoadingDetail && complaint == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Complaint Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (complaint == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Complaint Details')),
        body: EmptyStateView(
          title: 'Complaint Not Found',
          message: 'The requested grievance record does not exist on this device.',
          actionLabel: 'Go Back',
          onAction: () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              complaint.trackingNumber,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              complaint.categoryName,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final isVerySmall = constraints.maxWidth < 360;
              return TabBar(
                controller: _tabController,
                isScrollable: isVerySmall,
                tabAlignment: isVerySmall ? TabAlignment.start : TabAlignment.fill,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: [
                  Tab(text: 'Comments (${complaint.comments.length})'),
                  const Tab(text: 'Audit History'),
                  Tab(text: 'Evidence (${complaint.attachments.length})'),
                ],
              );
            },
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final horizontalMargin = isWide ? (constraints.maxWidth - 700) / 2 : 0.0;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCard(complaint, isStaffOrAdmin, isComplainant, auth, dateFormat),
                      const Divider(height: 1),
                      GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity != null) {
                            if (details.primaryVelocity! < -250 && _tabController.index < 2) {
                              _tabController.animateTo(_tabController.index + 1);
                            } else if (details.primaryVelocity! > 250 && _tabController.index > 0) {
                              _tabController.animateTo(_tabController.index - 1);
                            }
                          }
                        },
                        child: _buildActiveTabContent(complaint, isStaffOrAdmin, dateFormat),
                      ),
                    ],
                  ),
                ),
              ),
              if (_tabController.index == 0)
                _buildCommentInputBar(isStaffOrAdmin, horizontalMargin),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(
    Complaint complaint,
    bool isStaffOrAdmin,
    bool isComplainant,
    AuthProvider auth,
    DateFormat dateFormat,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  complaint.title,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: complaint.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            complaint.description,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),

          // Metadata Chips (Priority, Department, Storage Sync, Date)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PriorityBadge(priority: complaint.priority),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    complaint.departmentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: complaint.isSynced ? Colors.green.shade50 : Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: complaint.isSynced ? Colors.green.shade300 : Colors.blueGrey.shade200,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      complaint.isSynced ? Icons.cloud_done_rounded : Icons.phone_android_rounded,
                      size: 11,
                      color: complaint.isSynced ? Colors.green.shade700 : Colors.blueGrey.shade700,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      complaint.isSynced ? 'Server Synced' : 'On-Device Only',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: complaint.isSynced ? Colors.green.shade800 : Colors.blueGrey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(complaint.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Complainant & Assignee info strip (Responsive Wrap)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: LayoutBuilder(
              builder: (infoCtx, infoConstraints) {
                final maxItemWidth = infoConstraints.maxWidth;
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxItemWidth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 5),
                          Text('Complainant: ', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                          Flexible(
                            child: Text(
                              complaint.complainantName,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxItemWidth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.assignment_ind_outlined, size: 14, color: Colors.indigo),
                          const SizedBox(width: 4),
                          Text('Officer: ', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                          Flexible(
                            child: Text(
                              complaint.displayAssignee,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: complaint.isAssigned ? Colors.indigo.shade800 : Colors.amber.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Location context if present
          if (complaint.locationContext != null && complaint.locationContext!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    complaint.locationContext!,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Resolution Summary Banner
          if (complaint.resolutionSummary != null && complaint.resolutionSummary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade800),
                      const SizedBox(width: 6),
                      Text(
                        'Official Resolution Summary:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint.resolutionSummary!,
                    style: TextStyle(fontSize: 12.5, color: Colors.green.shade900, height: 1.3),
                  ),
                ],
              ),
            ),
          ],

          // Rejection Reason Banner
          if (complaint.rejectionReason != null && complaint.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cancel_rounded, size: 16, color: Colors.red.shade800),
                      const SizedBox(width: 6),
                      Text(
                        'Rejection Justification:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.red.shade800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint.rejectionReason!,
                    style: TextStyle(fontSize: 12.5, color: Colors.red.shade900, height: 1.3),
                  ),
                ],
              ),
            ),
          ],

          // Administrator Investigation & Action Desk (Section 5 & 7)
          if (isStaffOrAdmin) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (headerCtx, headerConstraints) {
                      return Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: headerConstraints.maxWidth),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded, size: 16, color: AppTheme.darkSlate),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Complaint Officer Investigation Desk',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.darkSlate),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (auth.currentUser != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade200, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge_outlined, size: 11, color: Colors.blue.shade800),
                                  const SizedBox(width: 3),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 160),
                                    child: Text(
                                      auth.currentUser?.fullName ?? 'Admin Slot',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Execute official investigation lifecycle actions. Every action, assignment, and status change is audited:',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (btnCtx, btnConstraints) {
                      final maxBtnWidth = btnConstraints.maxWidth;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // 1. Assign Administrator (Slots 1-4)
                          _buildActionButton(
                            complaint.isAssigned ? '👤 Reassign (${complaint.displayAssignee})' : '👤 Assign Admin Slot',
                            Colors.indigo.shade700,
                            _showAssignAdminDialog,
                            maxWidth: maxBtnWidth,
                          ),

                          // 2. Mark Under Review
                          if (complaint.status == 'SUBMITTED')
                            _buildActionButton('👁️ Mark Under Review', Colors.blue.shade700, () {
                              _showTransitionDialog(title: 'Move to Under Review', targetStatus: 'UNDER_REVIEW');
                            }, maxWidth: maxBtnWidth),

                          // 3. Start Investigation
                          if (complaint.status == 'SUBMITTED' || complaint.status == 'UNDER_REVIEW' || complaint.status == 'REOPENED')
                            _buildActionButton('⚡ Start Investigation', AppTheme.statusInProgress, () {
                              _showTransitionDialog(title: 'Start Investigation', targetStatus: 'IN_PROGRESS');
                            }, maxWidth: maxBtnWidth),

                          // 4. Change Priority
                          if (complaint.status != 'RESOLVED' && complaint.status != 'CLOSED')
                            _buildActionButton('⚖️ Change Priority', Colors.deepOrange.shade700, () {
                              _showChangePriorityDialog(complaint.priority);
                            }, maxWidth: maxBtnWidth),

                          // 5. Record Action Taken
                          if (complaint.status == 'IN_PROGRESS' || complaint.status == 'UNDER_REVIEW' || complaint.status == 'AWAITING_USER')
                            _buildActionButton('🛠️ Record Action Taken', Colors.teal.shade700, _showRecordActionDialog, maxWidth: maxBtnWidth),

                          // 6. Request Additional Information
                          if (complaint.status != 'RESOLVED' && complaint.status != 'CLOSED' && complaint.status != 'REJECTED')
                            _buildActionButton('❓ Request Information from Complainant', Colors.purple.shade700, _showRequestInfoDialog, maxWidth: maxBtnWidth),

                          // 7. Resolve Grievance
                          if (complaint.status != 'RESOLVED' && complaint.status != 'CLOSED' && complaint.status != 'REJECTED')
                            _buildActionButton('✅ Resolve Grievance', AppTheme.statusResolved, () {
                              _showTransitionDialog(
                                title: 'Resolve Grievance',
                                targetStatus: 'RESOLVED',
                                requireResolutionSummary: true,
                              );
                            }, maxWidth: maxBtnWidth),

                          // 8. Reject Grievance
                          if (complaint.status != 'RESOLVED' && complaint.status != 'CLOSED' && complaint.status != 'REJECTED')
                            _buildActionButton('❌ Reject Grievance', AppTheme.statusRejected, () {
                              _showTransitionDialog(
                                title: 'Reject Complaint',
                                targetStatus: 'REJECTED',
                                requireRejectionReason: true,
                              );
                            }, maxWidth: maxBtnWidth),

                          // 9. Reopen Resolved/Closed Case
                          if (complaint.status == 'RESOLVED' || complaint.status == 'CLOSED')
                            _buildActionButton('🔄 Reopen Investigation', AppTheme.statusReopened, () {
                              _showTransitionDialog(title: 'Reopen Investigation', targetStatus: 'IN_PROGRESS');
                            }, maxWidth: maxBtnWidth),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          // Complainant Interaction Desk (Section 6)
          if (isComplainant) ...[
            if (complaint.status == 'AWAITING_USER') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.announcement_rounded, color: Colors.amber.shade900, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Information Requested by Complaint Officer',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'The investigating officer needs additional information or evidence from you to proceed with this case.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade900,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.reply_all_rounded, size: 16),
                        label: const Text('Provide Information & Attach Evidence', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: _showComplainantResponseSheet,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (complaint.status == 'RESOLVED') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Authority has provided an official resolution. Please review and confirm:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (resCtx, resConstraints) {
                        final maxResWidth = resConstraints.maxWidth;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildActionButton('Confirm & Close', AppTheme.statusClosed, () {
                              _showTransitionDialog(title: 'Close Complaint', targetStatus: 'CLOSED');
                            }, maxWidth: maxResWidth),
                            _buildActionButton('Reopen Issue', AppTheme.statusReopened, () {
                              _showTransitionDialog(title: 'Reopen Complaint', targetStatus: 'REOPENED');
                            }, maxWidth: maxResWidth),
                            if (complaint.feedback == null)
                              _buildActionButton('Submit Satisfaction Feedback', Colors.amber.shade800, _showFeedbackDialog, maxWidth: maxResWidth),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(Complaint complaint, bool isStaffOrAdmin, DateFormat dateFormat) {
    switch (_tabController.index) {
      case 0:
        return _buildCommentsTab(complaint, dateFormat);
      case 1:
        return _buildAuditHistoryTab(complaint, dateFormat);
      case 2:
        return _buildEvidenceTab(complaint);
      default:
        return _buildCommentsTab(complaint, dateFormat);
    }
  }

  Widget _buildCommentsTab(Complaint complaint, DateFormat dateFormat) {
    if (complaint.comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Text(
            'No comments posted yet.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: complaint.comments.length,
      itemBuilder: (ctx, idx) {
        final comm = complaint.comments[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: comm.isInternalNote ? Colors.amber.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: comm.isInternalNote ? Colors.amber.shade300 : AppTheme.borderLight,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      comm.userName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (comm.isInternalNote) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'INTERNAL NOTE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(dateFormat.format(comm.createdAt), style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                ],
              ),
              const SizedBox(height: 6),
              Text(comm.commentText, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.35)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditHistoryTab(Complaint complaint, DateFormat dateFormat) {
    if (complaint.history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Text(
            'No history entries recorded.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: complaint.history.length,
      itemBuilder: (ctx, idx) {
        final h = complaint.history[idx];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (idx < complaint.history.length - 1)
                  Container(
                    width: 2,
                    height: 50,
                    color: AppTheme.borderLight,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            h.toStatus ?? h.eventType,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        Text(dateFormat.format(h.createdAt), style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Actor: ${h.actorName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    if (h.reason != null && h.reason!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Note: "${h.reason}"', style: const TextStyle(fontSize: 11.5, color: AppTheme.textPrimary)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEvidenceTab(Complaint complaint) {
    if (complaint.attachments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.attachment_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No Evidence Attached',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary),
              ),
              SizedBox(height: 4),
              Text(
                'No photos, videos, audio notes, or documents were attached to this complaint.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: complaint.attachments.length,
      itemBuilder: (ctx, idx) {
        final att = complaint.attachments[idx];
        final fileExists = att.filePath.isNotEmpty && File(att.filePath).existsSync();
        final isImage = att.fileType == 'photo' || att.filename.endsWith('.jpg') || att.filename.endsWith('.jpeg') || att.filename.endsWith('.png');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (isImage && fileExists)
                          ? InkWell(
                              onTap: () => _viewPhotoFullscreen(att.filePath, att.filename),
                              child: Image.file(
                                File(att.filePath),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              att.fileType == 'video'
                                  ? Icons.videocam_rounded
                                  : att.fileType == 'audio'
                                      ? Icons.audiotrack_rounded
                                      : Icons.picture_as_pdf_rounded,
                              size: 28,
                              color: AppTheme.primaryDark,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            att.filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  att.fileType.toUpperCase(),
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                EvidenceService.formatBytes(att.fileSize),
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Uploaded by: ${att.uploaderName}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!fileExists && att.filePath.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade900),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Evidence file moved or unavailable on this device.',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isImage)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.zoom_in_rounded, size: 16),
                          label: const Text('View Full Image', style: TextStyle(fontSize: 12)),
                          onPressed: () => _viewPhotoFullscreen(att.filePath, att.filename),
                        )
                      else
                        ElevatedButton.icon(
                          icon: Icon(
                            att.fileType == 'video'
                                ? Icons.play_arrow_rounded
                                : att.fileType == 'audio'
                                    ? Icons.play_circle_fill_rounded
                                    : Icons.open_in_new_rounded,
                            size: 16,
                          ),
                          label: Text(
                            att.fileType == 'video'
                                ? 'Play Video'
                                : att.fileType == 'audio'
                                    ? 'Play Audio'
                                    : 'Open Document',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _openAttachment(att),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentInputBar(bool isStaffOrAdmin, double horizontalMargin) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          12 + horizontalMargin,
          8,
          12 + horizontalMargin,
          8,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderLight)),
        ),
        child: Column(
          children: [
            if (isStaffOrAdmin)
              Row(
                children: [
                  Checkbox(
                    value: _isInternalNote,
                    onChanged: (v) => setState(() => _isInternalNote = v ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isInternalNote = !_isInternalNote),
                      child: const Text(
                        'Mark as Confidential Internal Note (Admin Only)',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Type a reply or update...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                  onPressed: _postComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed, {double? maxWidth}) {
    Widget button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        softWrap: true,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );

    if (maxWidth != null) {
      button = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: button,
      );
    }
    return button;
  }
}
