import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/role_badge.dart';
import '../../../shared/widgets/document_list_item.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../organization/providers/organization_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../documents/providers/upload_provider.dart';
import '../../documents/screens/document_library_screen.dart';
import '../../search/screens/search_filter_screen.dart';
import '../../documents/screens/upload_queue_screen.dart';
import '../../documents/screens/document_details_screen.dart';
import '../../organization/screens/org_select_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../admin/screens/member_management_screen.dart';
import '../../admin/screens/storage_usage_screen.dart';
import '../../admin/screens/audit_logs_screen.dart';
import '../../documents/screens/trash_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  void _loadDashboardData() {
    final org = context.read<OrganizationProvider>().activeOrganization;
    if (org != null) {
      context.read<DocumentProvider>().loadContents(org.id);
    }
  }

  Future<void> _pickAndUploadFile() async {
    final org = context.read<OrganizationProvider>().activeOrganization;
    if (org == null) return;

    if (org.isViewer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viewer role cannot upload documents.')),
      );
      return;
    }

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'webp',
          'pdf', 'txt', 'mp4', 'mov',
          'docx', 'xlsx', 'pptx', 'doc', 'xls',
        ],
      );

      if (!mounted) return;
      if (files.isNotEmpty) {
        final uploadProvider = context.read<UploadProvider>();
        final docProvider = context.read<DocumentProvider>();

        for (final platformFile in files) {
          await uploadProvider.enqueuePlatformFile(
            platformFile,
            org.id,
            folderId: docProvider.currentFolder?.id,
          );
        }

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UploadQueueScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking files: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    final uploadProvider = context.watch<UploadProvider>();
    final activeOrg = orgProvider.activeOrganization;

    final pages = [
      _buildDashboardView(activeOrg),
      const DocumentLibraryScreen(),
      const SearchFilterScreen(),
      _buildMoreView(activeOrg),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrgSelectScreen()),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    activeOrg?.name.isNotEmpty == true ? activeOrg!.name[0].toUpperCase() : 'O',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    activeOrg?.name ?? 'Select Org',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        actions: [
          if (activeOrg != null) ...[
            Center(child: RoleBadge(role: activeOrg.role)),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: Badge(
              isLabelVisible: uploadProvider.hasActiveUploads,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.cloud_upload_outlined, color: AppColors.textSecondary),
            ),
            tooltip: 'Upload Queue',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UploadQueueScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: AppColors.textSecondary),
            tooltip: 'Account Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      floatingActionButton: (activeOrg?.canUpload == true)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Upload', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: _pickAndUploadFile,
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), activeIcon: Icon(Icons.folder_rounded), label: 'Files'),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_rounded), label: 'More'),
        ],
      ),
    );
  }

  Widget _buildDashboardView(activeOrg) {
    final docProvider = context.watch<DocumentProvider>();

    if (activeOrg == null) {
      return const Center(child: Text('Please select an organization.'));
    }

    final recentDocs = docProvider.documents.take(6).toList();

    return RefreshIndicator(
      onRefresh: () async => _loadDashboardData(),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Storage Overview Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B3A42), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Organization Storage', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Icon(Icons.cloud_outlined, color: AppColors.primary.withValues(alpha: 0.8), size: 20),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  Formatters.formatBytes(activeOrg.storageUsedBytes),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'of ${Formatters.formatBytes(activeOrg.storageQuotaBytes)} allocated quota',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: activeOrg.storageQuotaBytes > 0
                        ? (activeOrg.storageUsedBytes / activeOrg.storageQuotaBytes).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Quick Actions
          Row(
            children: [
              _buildQuickCard(
                icon: Icons.upload_file_rounded,
                label: 'Upload File',
                color: AppColors.primary,
                onTap: _pickAndUploadFile,
              ),
              const SizedBox(width: 12),
              _buildQuickCard(
                icon: Icons.create_new_folder_rounded,
                label: 'New Folder',
                color: Colors.indigo,
                onTap: () {
                  setState(() => _currentIndex = 1);
                },
              ),
              const SizedBox(width: 12),
              _buildQuickCard(
                icon: Icons.delete_sweep_rounded,
                label: 'Trash',
                color: AppColors.textSecondary,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TrashScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Recent Documents
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Documents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              TextButton(
                onPressed: () => setState(() => _currentIndex = 1),
                child: const Text('View All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (docProvider.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))))
          else if (recentDocs.isEmpty)
            const EmptyState(
              icon: Icons.description_outlined,
              title: 'No Documents Yet',
              message: 'Files uploaded to this organization will show up here.',
            )
          else
            ...recentDocs.map((doc) => DocumentListItem(
                  document: doc,
                  canManage: activeOrg.canUpload,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DocumentDetailsScreen(document: doc)),
                    );
                  },
                )),
        ],
      ),
    );
  }

  Widget _buildQuickCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreView(activeOrg) {
    final isAdmin = activeOrg?.isAdmin == true;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Organization Settings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.people_outline_rounded, color: AppColors.primary),
                  title: const Text('Members & Roles'),
                  subtitle: Text(isAdmin ? 'Manage invites and permissions' : 'View organization members'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemberManagementScreen()));
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline_rounded, color: Colors.teal),
                  title: const Text('Storage Usage'),
                  subtitle: const Text('View quota and category breakdown'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StorageUsageScreen()));
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.warning),
                  title: const Text('Trash & Recovery'),
                  subtitle: const Text('Restore or permanently purge documents'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashScreen()));
                  },
                ),
                if (isAdmin) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.history_rounded, color: Colors.deepPurple),
                    title: const Text('Audit History'),
                    subtitle: const Text('Access control and activity events'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuditLogsScreen()));
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Preferences & Switcher', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.accent),
                  title: const Text('Switch Organization'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrgSelectScreen()));
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded, color: AppColors.textPrimary),
                  title: const Text('User Account Profile'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
