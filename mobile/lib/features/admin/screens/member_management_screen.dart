import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/role_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../organization/providers/organization_provider.dart';
import '../providers/admin_provider.dart';
import '../models/member_model.dart';
import 'invitation_screen.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final org = context.read<OrganizationProvider>().activeOrganization;
      if (org != null) {
        context.read<AdminProvider>().loadMembers(org.id);
      }
    });
  }

  void _showChangeRoleDialog(String orgId, MemberModel member) {
    String selectedRole = member.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Change Role for ${member.email}', style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['admin', 'manager', 'viewer'].map((r) {
              return RadioListTile<String>(
                title: Text(r.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  r == 'admin' ? 'Full access & member management' : (r == 'manager' ? 'Can upload, organize, edit' : 'Read & download only'),
                  style: const TextStyle(fontSize: 11),
                ),
                value: r,
                groupValue: selectedRole,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedRole = val);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final adminProvider = context.read<AdminProvider>();
                final ok = await adminProvider.updateMemberRole(orgId, member.id, selectedRole);
                if (!mounted || !context.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(adminProvider.errorMessage ?? 'Failed to update role'), backgroundColor: AppColors.danger),
                  );
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveMember(String orgId, MemberModel member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Are you sure you want to remove ${member.email} from the organization?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final adminProvider = context.read<AdminProvider>();
              final ok = await adminProvider.removeMember(orgId, member.id);
              if (!mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(adminProvider.errorMessage ?? 'Failed to remove member'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>().activeOrganization;
    final adminProvider = context.watch<AdminProvider>();

    if (org == null) {
      return const Scaffold(body: Center(child: Text('No active organization')));
    }

    final isAdmin = org.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Members & Roles', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
              tooltip: 'Invite Member',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InvitationScreen()),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => adminProvider.loadMembers(org.id),
        child: adminProvider.isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
            : adminProvider.members.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No Members Found',
                    message: 'Invite colleagues by email to collaborate on your documents.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: adminProvider.members.length,
                    itemBuilder: (context, index) {
                      final m = adminProvider.members[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              m.email.isNotEmpty ? m.email[0].toUpperCase() : 'M',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                          ),
                          title: Text(
                            m.email,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Status: ${m.status}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RoleBadge(role: m.role),
                              if (isAdmin) ...[
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary, size: 20),
                                  onSelected: (val) {
                                    if (val == 'role') _showChangeRoleDialog(org.id, m);
                                    if (val == 'remove') _confirmRemoveMember(org.id, m);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'role', child: Text('Change Role')),
                                    const PopupMenuItem(value: 'remove', child: Text('Remove Member', style: TextStyle(color: AppColors.danger))),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
