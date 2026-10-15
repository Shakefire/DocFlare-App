import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../organization/providers/organization_provider.dart';

class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  final _emailController = TextEditingController();
  String _selectedRole = 'viewer';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final orgProvider = context.read<OrganizationProvider>();
    final ok = await orgProvider.inviteMember(email, _selectedRole);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent to $email'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(orgProvider.errorMessage ?? 'Failed to send invitation'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Invite Member', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Send an Invitation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'An email with a secure, single-use token valid for 7 days will be dispatched to the recipient.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _emailController,
                label: 'Member Email Address',
                hint: 'colleague@company.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 20),
              ),
              const SizedBox(height: 24),
              const Text(
                'Select Role',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Viewer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Can view, preview, and download authorized files', style: TextStyle(fontSize: 12)),
                      value: 'viewer',
                      groupValue: _selectedRole,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Can upload, move, rename, and organize folders/documents', style: TextStyle(fontSize: 12)),
                      value: 'manager',
                      groupValue: _selectedRole,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Send Invitation Email',
                onPressed: _isLoading ? null : _handleInvite,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
