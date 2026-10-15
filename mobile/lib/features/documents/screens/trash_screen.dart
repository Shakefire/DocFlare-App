import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/document_list_item.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../organization/providers/organization_provider.dart';
import '../../admin/providers/admin_provider.dart';
import '../providers/document_provider.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final org = context.read<OrganizationProvider>().activeOrganization;
      if (org != null) {
        context.read<AdminProvider>().loadTrash(org.id);
      }
    });
  }

  void _confirmPermanentDelete(String orgId, String docId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete?'),
        content: Text('Are you sure you want to permanently delete "$name"? This action cannot be undone and will purge the file from Cloudflare R2 storage.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final adminProvider = context.read<AdminProvider>();
              final success = await adminProvider.permanentDelete(orgId, docId);
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document permanently deleted.'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Delete Forever', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>().activeOrganization;
    final adminProvider = context.watch<AdminProvider>();
    final docProvider = context.read<DocumentProvider>();

    if (org == null) {
      return const Scaffold(body: Center(child: Text('No active organization')));
    }

    final isAdmin = org.isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trash & Recovery', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => adminProvider.loadTrash(org.id),
        child: adminProvider.isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
            : adminProvider.trashDocuments.isEmpty
                ? const EmptyState(
                    icon: Icons.delete_outline_rounded,
                    title: 'Trash is Empty',
                    message: 'Deleted documents are retained in trash for 30 days before automatic cleanup.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: adminProvider.trashDocuments.length,
                    itemBuilder: (_, index) {
                      final doc = adminProvider.trashDocuments[index];
                      return DocumentListItem(
                        document: doc,
                        isTrash: true,
                        canManage: isAdmin,
                        onTap: () {},
                        onRestore: () async {
                          final ok = await docProvider.restoreDocument(org.id, doc.id);
                          if (!mounted || !context.mounted) return;
                          if (ok) {
                            await adminProvider.loadTrash(org.id);
                            if (!mounted || !context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Document restored to library.'), backgroundColor: AppColors.success),
                            );
                          }
                        },
                        onDelete: () => _confirmPermanentDelete(org.id, doc.id, doc.displayName),
                      );
                    },
                  ),
      ),
    );
  }
}
