import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../core/models/admin_identity.dart';
import '../../core/state/auth_provider.dart';

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  List<AdminIdentity> _adminSlots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final slots = await auth.getAdminSlots();
    if (mounted) {
      setState(() {
        _adminSlots = slots;
        _isLoading = false;
      });
    }
  }

  void _openConfigDialog(AdminIdentity slot) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: slot.fullName ?? '');
    final emailController = TextEditingController(text: slot.email ?? '');
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Configure Admin Slot #${slot.slotNumber}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the designated administrator identity credentials. Passwords are saved with SHA-256 + 128-bit cryptographic salt in device storage.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Administrator Full Name *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Please enter a valid full name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Admin Work Email *',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter an email';
                        if (!v.contains('@')) return 'Enter a valid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Admin Password (min 8 chars) *',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setDialogState(() => obscure = !obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password *',
                        prefixIcon: Icon(Icons.check_circle_outline, size: 20),
                      ),
                      validator: (v) {
                        if (v != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final success = await auth.configureAdminSlot(
                    slotNumber: slot.slotNumber,
                    fullName: nameController.text.trim(),
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }

                  if (success) {
                    _loadSlots();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Admin Slot #${slot.slotNumber} successfully configured!'),
                        backgroundColor: AppTheme.statusResolved,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(auth.errorMessage ?? 'Failed to configure administrator identity.'),
                        backgroundColor: AppTheme.statusRejected,
                      ),
                    );
                  }
                },
                child: const Text('Save Admin Identity'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmReset(AdminIdentity slot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Admin Slot #${slot.slotNumber}?'),
        content: Text(
          'This will clear the administrator identity for "${slot.fullName}". They will no longer be able to log in with administrator privileges until reconfigured.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRejected),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await auth.resetAdminSlot(slot.slotNumber);
              _loadSlots();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Admin Slot #${slot.slotNumber} has been reset.')),
                );
              }
            },
            child: const Text('Reset Slot'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Provisioning Console'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final horizontalPadding = isWide ? (constraints.maxWidth - 700) / 2 : 18.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Explanatory Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryDark, size: 22),
                            SizedBox(width: 8),
                            Text(
                              '4 Designated Administrator Identities',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'The offline architecture reserves exactly four administrator accounts. When administrator credentials are provided, activate each slot below. Standard user registration is restricted to complainants and cannot grant administrator status.',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.4),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Privacy Notice: All data is strictly device-local. Accounts configured on this phone exist only within this device\'s SQLite database and do not automatically sync across phones.',
                          style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4 Slots List
                  ..._adminSlots.map((slot) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: slot.isConfigured ? AppTheme.statusResolved.withValues(alpha: 0.4) : AppTheme.borderLight,
                          width: 1.2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: slot.isConfigured ? AppTheme.primary : Colors.grey.shade300,
                                  child: Text(
                                    '#${slot.slotNumber}',
                                    style: TextStyle(
                                      color: slot.isConfigured ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.isConfigured ? (slot.fullName ?? 'Admin') : 'Admin Slot #${slot.slotNumber}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                      Text(
                                        slot.isConfigured ? slot.email! : 'Pending Administrator Credentials',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: slot.isConfigured ? AppTheme.textSecondary : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: slot.isConfigured ? Colors.green.shade50 : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: slot.isConfigured ? Colors.green.shade400 : Colors.amber.shade400,
                                    ),
                                  ),
                                  child: Text(
                                    slot.isConfigured ? 'CONFIGURED' : 'UNCONFIGURED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: slot.isConfigured ? Colors.green.shade800 : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (slot.isConfigured && slot.configuredAt != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Provisioned on: ${dateFormat.format(slot.configuredAt!)}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (slot.isConfigured) ...[
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.statusRejected),
                                    label: const Text('Reset', style: TextStyle(color: AppTheme.statusRejected, fontSize: 12)),
                                    onPressed: () => _confirmReset(slot),
                                  ),
                                ],
                                OutlinedButton.icon(
                                  icon: Icon(slot.isConfigured ? Icons.edit_outlined : Icons.add_moderator_rounded, size: 16),
                                  label: Text(slot.isConfigured ? 'Update Details' : 'Configure Identity', style: const TextStyle(fontSize: 12)),
                                  onPressed: () => _openConfigDialog(slot),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
    );
  }
}
