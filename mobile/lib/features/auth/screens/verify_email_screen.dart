import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../../organization/providers/organization_provider.dart';
import '../../organization/screens/org_select_screen.dart';
import '../../home/screens/home_dashboard_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _tokenController = TextEditingController();
  bool _isResending = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your verification token')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final orgProvider = context.read<OrganizationProvider>();

    final success = await auth.verifyEmail(token);
    if (!mounted) return;

    if (success) {
      await orgProvider.loadOrganizations();
      if (!mounted) return;

      if (orgProvider.activeOrganization != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OrgSelectScreen()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Verification failed.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.resendVerification(widget.email);
    if (!mounted) return;

    setState(() => _isResending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Verification link re-sent to ${widget.email}' : 'Failed to resend.'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
              const Icon(Icons.mark_email_unread_outlined, size: 64, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text(
                'Verify your email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a verification link and token to\n${widget.email}',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _tokenController,
                label: 'Verification token',
                hint: 'Paste token from verification email',
                prefixIcon: const Icon(Icons.key_rounded, color: AppColors.textSecondary, size: 20),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Verify Email',
                onPressed: _handleVerify,
                isLoading: auth.status == AuthStatus.loading,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Resend Verification Code',
                isSecondary: true,
                onPressed: _isResending ? null : _handleResend,
                isLoading: _isResending,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
