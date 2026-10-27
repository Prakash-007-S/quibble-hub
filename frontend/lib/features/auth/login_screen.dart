import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../core/models/admin_identity.dart';
import '../../core/state/auth_provider.dart';
import 'admin_setup_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  int _selectedPortal = 0; // 0: Complainant Portal, 1: Authority & Organization Portal
  List<AdminIdentity> _adminSlots = [];

  @override
  void initState() {
    super.initState();
    _loadAdminSlots();
  }

  Future<void> _loadAdminSlots() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final slots = await auth.getAdminSlots();
      if (mounted) {
        setState(() => _adminSlots = slots);
      }
    } catch (e) {
      debugPrint('Error loading admin slots: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Authentication failed. Please verify credentials.'),
          backgroundColor: AppTheme.statusRejected,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
            label: const Text(
              'Admin Identities',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminSetupScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppTheme.borderLight, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo & Brand Header
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _selectedPortal == 1 ? AppTheme.darkSlate.withValues(alpha: 0.1) : AppTheme.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedPortal == 1 ? Icons.shield_rounded : Icons.verified_user_rounded,
                              size: 38,
                              color: _selectedPortal == 1 ? AppTheme.darkSlate : AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Quibble Hub',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkSlate,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Offline-First Local Storage • Dual Portal Architecture',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Portal Switcher Tabs
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              // Portal 1: Complainant
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(9),
                                  onTap: () {
                                    setState(() {
                                      _selectedPortal = 0;
                                      _emailController.clear();
                                      _passwordController.clear();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedPortal == 0 ? AppTheme.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: _selectedPortal == 0
                                          ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_rounded,
                                          size: 15,
                                          color: _selectedPortal == 0 ? Colors.white : AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Complainant',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _selectedPortal == 0 ? Colors.white : AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Portal 2: Authority & Organization
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(9),
                                  onTap: () {
                                    setState(() {
                                      _selectedPortal = 1;
                                      _emailController.text = 'admin@sengunthar.edu';
                                      _passwordController.text = 'admin123';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedPortal == 1 ? AppTheme.darkSlate : Colors.transparent,
                                      borderRadius: BorderRadius.circular(9),
                                      boxShadow: _selectedPortal == 1
                                          ? [BoxShadow(color: AppTheme.darkSlate.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          size: 15,
                                          color: _selectedPortal == 1 ? Colors.white : AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Authority Portal',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _selectedPortal == 1 ? Colors.white : AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Portal Explanation Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedPortal == 0 ? Colors.blue.shade50 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedPortal == 0 ? Colors.blue.shade200 : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _selectedPortal == 0 ? Icons.info_outline_rounded : Icons.account_balance_rounded,
                                size: 16,
                                color: _selectedPortal == 0 ? Colors.blue.shade800 : AppTheme.darkSlate,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedPortal == 0
                                      ? 'Complainant Desk: Submit complaints, track status, view resolution summaries, and provide feedback.'
                                      : 'Authority Desk: Authorized officials receive all incoming complaints, investigate, post updates, and record official resolutions.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: _selectedPortal == 0 ? Colors.blue.shade900 : AppTheme.darkSlate,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // If Authority Portal is selected, show 4 Designated Admin Slots (Section 7)
                        if (_selectedPortal == 1) ...[
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text(
                                'Designated Administrator Slots (4 Slots):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                              InkWell(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AdminSetupScreen()),
                                  );
                                  _loadAdminSlots();
                                },
                                child: const Text(
                                  'Setup / Reset Slots',
                                  style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_adminSlots.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Loading designated administrator slots...', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                            )
                          else
                            ...List.generate(_adminSlots.length, (idx) {
                              final slot = _adminSlots[idx];
                              final isSelected = slot.isConfigured && slot.email != null && _emailController.text == slot.email;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    if (slot.isConfigured && slot.email != null) {
                                      setState(() {
                                        _emailController.text = slot.email!;
                                        _passwordController.text = 'admin123';
                                      });
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const AdminSetupScreen()),
                                      ).then((_) => _loadAdminSlots());
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryLight.withValues(alpha: 0.5) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primary : (slot.isConfigured ? Colors.grey.shade300 : Colors.amber.shade400),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: slot.isConfigured
                                              ? (isSelected ? AppTheme.primary : AppTheme.darkSlate.withValues(alpha: 0.1))
                                              : Colors.amber.shade100,
                                          child: Text(
                                            '${slot.slotNumber}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: slot.isConfigured
                                                  ? (isSelected ? Colors.white : AppTheme.darkSlate)
                                                  : Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                slot.displayName,
                                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                              ),
                                              Text(
                                                slot.isConfigured ? slot.email! : 'Unconfigured • Tap to set account details',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: slot.isConfigured ? AppTheme.textSecondary : Colors.amber.shade900,
                                                  fontStyle: slot.isConfigured ? FontStyle.normal : FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primary)
                                        else if (!slot.isConfigured)
                                          Icon(Icons.tune_rounded, size: 16, color: Colors.amber.shade900),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 12),
                        ],

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: _selectedPortal == 0 ? 'Complainant / Student Email' : 'Authorized Official Email',
                            hintText: _selectedPortal == 0 ? 'user@example.com' : 'admin@sengunthar.edu',
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!val.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Submit Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedPortal == 1 ? AppTheme.darkSlate : AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: auth.isLoading ? null : _submit,
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  _selectedPortal == 0 ? 'Sign In as Complainant' : 'Sign In as Authorized Official',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                        ),
                        const SizedBox(height: 14),

                        // Secondary Options
                        if (_selectedPortal == 0) ...[
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text("New user? ", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                  );
                                },
                                child: const Text('Register as Complainant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                            ],
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.settings_suggest_outlined, size: 16),
                            label: const Text('Manage & Customize Admin Identities', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminSetupScreen()),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
