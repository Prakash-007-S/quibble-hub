import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../core/services/evidence_service.dart';
import '../../core/state/auth_provider.dart';
import '../../core/state/complaint_provider.dart';
import '../../core/widgets/ai_suggestion_card.dart';

class CreateComplaintScreen extends StatefulWidget {
  const CreateComplaintScreen({super.key});

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  String? _selectedCategoryId;
  String _selectedPriority = 'MEDIUM';

  Map<String, dynamic>? _aiSuggestion;
  bool _isCheckingAI = false;

  List<Map<String, dynamic>> _duplicateCandidates = [];
  bool _isCheckingDuplicates = false;

  final List<String> _priorities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
  final List<PickedEvidence> _pickedEvidence = [];
  bool _isPickingEvidence = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
      complaintProv.fetchCategoriesAndDepartments();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _runAIClassification() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.length < 5 || description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and description before asking AI')),
      );
      return;
    }

    setState(() {
      _isCheckingAI = true;
      _aiSuggestion = null;
    });

    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    final suggestion = await complaintProv.getAIClassification(title, description);

    if (mounted) {
      setState(() {
        _isCheckingAI = false;
        _aiSuggestion = suggestion;
      });
    }
  }

  Future<void> _checkDuplicates() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) return;

    setState(() {
      _isCheckingDuplicates = true;
      _duplicateCandidates = [];
    });

    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    final results = await complaintProv.checkDuplicates(title, description);

    if (mounted) {
      setState(() {
        _isCheckingDuplicates = false;
        _duplicateCandidates = results;
      });
    }
  }

  void _applyAISuggestion() {
    if (_aiSuggestion == null) return;
    final catId = _aiSuggestion!['category_id'];
    final priority = _aiSuggestion!['recommended_priority'];

    setState(() {
      if (catId != null) {
        _selectedCategoryId = catId;
      }
      if (priority != null && _priorities.contains(priority)) {
        _selectedPriority = priority;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI recommendations applied to form!'),
        backgroundColor: AppTheme.statusResolved,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickAttachment(Future<PickedEvidence?> Function() pickerAction) async {
    setState(() => _isPickingEvidence = true);
    try {
      final picked = await pickerAction();
      if (picked != null && mounted) {
        setState(() {
          _pickedEvidence.add(picked);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attached: ${picked.fileName} (${picked.formattedSize})'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not attach file: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppTheme.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingEvidence = false);
      }
    }
  }

  void _showAddEvidenceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.attachment_rounded, color: AppTheme.primary, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Add Evidence Attachment',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.darkSlate),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Attach photos, videos, audio, or PDF evidence stored locally on your device.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: Icon(Icons.photo_camera_rounded, color: AppTheme.primaryDark),
                ),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Capture photo with camera', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(EvidenceService.takePhoto);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: Icon(Icons.photo_library_rounded, color: AppTheme.primaryDark),
                ),
                title: const Text('Choose Photo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Select photo from device gallery', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(EvidenceService.choosePhoto);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: Icon(Icons.videocam_rounded, color: AppTheme.primaryDark),
                ),
                title: const Text('Record Video', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Record video evidence with camera', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(EvidenceService.recordVideo);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: Icon(Icons.video_collection_rounded, color: AppTheme.primaryDark),
                ),
                title: const Text('Choose Video', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Select video from device', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(EvidenceService.chooseVideo);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: Icon(Icons.mic_rounded, color: AppTheme.primaryDark),
                ),
                title: const Text('Attach Audio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Select recorded audio or voice note', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(EvidenceService.chooseAudio);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryLight,
                  child: Icon(Icons.description_rounded, color: AppTheme.primaryDark),
                ),
                title: const Text('Attach Document / PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Select PDF, DOC, or TXT file', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAttachment(EvidenceService.chooseDocument);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a complaint category')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in before submitting a complaint')),
      );
      return;
    }

    final complaintProv = Provider.of<ComplaintProvider>(context, listen: false);
    final success = await complaintProv.createComplaint(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryId: _selectedCategoryId!,
      complainantId: user.id,
      complainantName: user.fullName,
      locationContext: _locationController.text.trim(),
      priority: _selectedPriority,
      evidenceFiles: _pickedEvidence,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint submitted successfully! Stored on device.'),
          backgroundColor: AppTheme.statusResolved,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(complaintProv.errorMessage ?? 'Submission failed'),
          backgroundColor: AppTheme.statusRejected,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaintProv = Provider.of<ComplaintProvider>(context);
    final categories = complaintProv.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Grievance / Complaint'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final horizontalPadding = isWide ? (constraints.maxWidth - 700) / 2 : 18.0;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
            child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Complaint Title *',
                  hintText: 'Enter complaint title...',
                  prefixIcon: Icon(Icons.title_rounded, size: 20),
                ),
                validator: (v) => (v == null || v.trim().length < 5) ? 'Title must be at least 5 characters' : null,
              ),
              const SizedBox(height: 14),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detailed Problem Description *',
                  hintText: 'Provide specific details, observed errors, symptoms, and impact...',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().length < 10) ? 'Description must be at least 10 characters' : null,
              ),
              const SizedBox(height: 14),

              // AI Assistant Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isCheckingAI ? null : _runAIClassification,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.3),
                      ),
                      icon: _isCheckingAI
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('AI Auto-Classify', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isCheckingDuplicates ? null : _checkDuplicates,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isCheckingDuplicates
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Check Duplicates', style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),

              // AI Suggestion Preview Card
              if (_aiSuggestion != null)
                AISuggestionCard(
                  suggestion: _aiSuggestion!,
                  onApply: _applyAISuggestion,
                ),

              // Duplicate Candidates Preview
              if (_duplicateCandidates.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Text(
                            'Similar Existing Complaints (${_duplicateCandidates.length}):',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ..._duplicateCandidates.map((cand) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${cand['tracking_number']}: "${cand['title']}"',
                          style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900),
                        ),
                      )),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Category Selector
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Complaint Category *',
                  prefixIcon: Icon(Icons.category_outlined, size: 20),
                ),
                isExpanded: true,
                items: categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat.id,
                    child: Text(
                      '${cat.name} (${cat.departmentName ?? "General"})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                validator: (v) => v == null ? 'Please select category' : null,
              ),
              const SizedBox(height: 14),

              // Location / Service Context
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location or Service Context',
                  hintText: 'Building, room number, department, or context (optional)',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Priority Selector
              DropdownButtonFormField<String>(
                initialValue: _selectedPriority,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Priority Level',
                  prefixIcon: Icon(Icons.flag_outlined, size: 20),
                ),
                items: _priorities.map((p) {
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Text(p, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedPriority = val ?? 'MEDIUM'),
              ),
              const SizedBox(height: 20),

              // Evidence Attachments Section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 20, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Evidence Attachments',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isPickingEvidence ? null : _showAddEvidenceBottomSheet,
                          icon: _isPickingEvidence
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add, size: 18),
                          label: const Text('Add Evidence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Text(
                      'Attach photos, videos, audio notes, or PDF records to substantiate this complaint.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                    if (_pickedEvidence.isEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: const Center(
                          child: Text(
                            'No evidence attached yet. Tap "+ Add Evidence" above.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      ...List.generate(_pickedEvidence.length, (idx) {
                        final item = _pickedEvidence[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppTheme.borderLight),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: item.fileType == 'photo'
                                  ? Image.file(
                                      File(item.tempPath),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(Icons.photo, color: AppTheme.primary),
                                    )
                                  : Icon(
                                      item.fileType == 'video'
                                          ? Icons.videocam_rounded
                                          : item.fileType == 'audio'
                                              ? Icons.mic_rounded
                                              : Icons.picture_as_pdf_rounded,
                                      color: AppTheme.primaryDark,
                                    ),
                            ),
                            title: Text(
                              item.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.fileType.toUpperCase(),
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(item.formattedSize, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.statusRejected),
                              onPressed: () => setState(() => _pickedEvidence.removeAt(idx)),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: complaintProv.isSubmitting ? null : _submit,
                child: complaintProv.isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Submit Complaint'),
              ),
            ],
          ),
        ),
      );
        },
      ),
    );
  }
}
