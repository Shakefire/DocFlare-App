import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/role_badge.dart';
import '../providers/organization_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import 'create_org_screen.dart';
import '../../home/screens/home_dashboard_screen.dart';

class OrgSelectScreen extends StatefulWidget {
  const OrgSelectScreen({super.key});

  @override
  State<OrgSelectScreen> createState() => _OrgSelectScreenState();
}

class _OrgSelectScreenState extends State<OrgSelectScreen> {
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrganizationProvider>().loadOrganizations();
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _showJoinModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Accept Organization Invitation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the invitation token received in your email invitation.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                hintText: 'Paste invitation token',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Join Organization',
              onPressed: () async {
                final token = _tokenController.text.trim();
                if (token.isEmpty) return;
                Navigator.of(ctx).pop();

                final orgProvider = context.read<OrganizationProvider>();
                final success = await orgProvider.acceptInvitation(token);
                if (!mounted) return;

                if (success) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(orgProvider.errorMessage ?? 'Failed to accept invitation.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Organizations', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: 'Sign Out',
            onPressed: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: orgProvider.isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
          : orgProvider.organizations.isEmpty
              ? EmptyState(
                  icon: Icons.business_outlined,
                  title: 'No Organizations Found',
                  message: 'Create a new organization or join an existing one using an email invitation.',
                  action: Column(
                    children: [
                      AppButton(
                        label: 'Create Organization',
                        icon: Icons.add_rounded,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CreateOrgScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Have an Invitation Token?',
                        isSecondary: true,
                        icon: Icons.mail_outline_rounded,
                        onPressed: _showJoinModal,
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Select an organization to continue',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    ...orgProvider.organizations.map((org) {
                      final isSelected = orgProvider.activeOrganization?.id == org.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onTap: () async {
                            await orgProvider.selectOrganization(org);
                            if (!context.mounted) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O',
                              style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(org.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('ID: ${org.slug}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RoleBadge(role: org.role),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Create New Organization',
                      icon: Icons.add_rounded,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateOrgScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Accept Invitation Code',
                      isSecondary: true,
                      icon: Icons.mail_outline_rounded,
                      onPressed: _showJoinModal,
                    ),
                  ],
                ),
    );
  }
}
