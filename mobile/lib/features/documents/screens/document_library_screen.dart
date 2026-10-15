import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/document_list_item.dart';
import '../../../shared/widgets/folder_list_item.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/app_button.dart';
import '../../organization/providers/organization_provider.dart';
import '../providers/document_provider.dart';
import '../models/folder_model.dart';
import 'document_details_screen.dart';

class DocumentLibraryScreen extends StatefulWidget {
  const DocumentLibraryScreen({super.key});

  @override
  State<DocumentLibraryScreen> createState() => _DocumentLibraryScreenState();
}

class _DocumentLibraryScreenState extends State<DocumentLibraryScreen> {
  final _folderNameController = TextEditingController();

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  void _showCreateFolderDialog(String orgId) {
    _folderNameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _folderNameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'e.g. Invoices 2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = _folderNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();

              final docProvider = context.read<DocumentProvider>();
              final success = await docProvider.createFolder(orgId, name);
              if (!mounted) return;
              if (!success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(docProvider.errorMessage ?? 'Failed to create folder')),
                );
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(String orgId, FolderModel folder) {
    _folderNameController.text = folder.name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: _folderNameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Folder Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = _folderNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();

              final docProvider = context.read<DocumentProvider>();
              await docProvider.renameFolder(orgId, folder.id, name);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(String orgId, FolderModel folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Are you sure you want to delete "${folder.name}"? If it contains subfolders or documents, you must delete recursively.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final docProvider = context.read<DocumentProvider>();
              await docProvider.deleteFolder(orgId, folder.id, recursive: true);
            },
            child: const Text('Delete All', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>().activeOrganization;
    final docProvider = context.watch<DocumentProvider>();

    if (org == null) {
      return const Center(child: Text('No organization selected'));
    }

    final breadcrumbs = docProvider.breadcrumbs;
    final canManage = !org.isViewer;

    return Column(
      children: [
        // Breadcrumb Navigation Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => docProvider.resetNavigation(org.id),
                        child: const Text(
                          'Root',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13),
                        ),
                      ),
                      ...breadcrumbs.map((b) => Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                              ),
                              InkWell(
                                onTap: () => docProvider.openFolder(org.id, b),
                                child: Text(
                                  b.name,
                                  style: TextStyle(
                                    fontWeight: b == breadcrumbs.last ? FontWeight.bold : FontWeight.w500,
                                    color: b == breadcrumbs.last ? AppColors.textPrimary : AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          )),
                    ],
                  ),
                ),
              ),
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined, color: AppColors.primary, size: 22),
                  tooltip: 'Create New Folder',
                  onPressed: () => _showCreateFolderDialog(org.id),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        // Content Listing
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => docProvider.loadContents(org.id, folder: docProvider.currentFolder),
            child: docProvider.isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
                : (docProvider.folders.isEmpty && docProvider.documents.isEmpty)
                    ? EmptyState(
                        icon: Icons.folder_open_rounded,
                        title: 'This Folder is Empty',
                        message: 'Upload documents or create subfolders to organize your files.',
                        action: canManage
                            ? AppButton(
                                label: 'New Folder',
                                icon: Icons.create_new_folder_rounded,
                                isSecondary: true,
                                onPressed: () => _showCreateFolderDialog(org.id),
                              )
                            : null,
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Folders section
                          if (docProvider.folders.isNotEmpty) ...[
                            const Text('FOLDERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            ...docProvider.folders.map((f) => FolderListItem(
                                  folder: f,
                                  canManage: canManage,
                                  onTap: () => docProvider.openFolder(org.id, f),
                                  onRename: () => _showRenameFolderDialog(org.id, f),
                                  onDelete: () => _confirmDeleteFolder(org.id, f),
                                )),
                            const SizedBox(height: 16),
                          ],
                          // Documents section
                          if (docProvider.documents.isNotEmpty) ...[
                            const Text('DOCUMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            ...docProvider.documents.map((doc) => DocumentListItem(
                                  document: doc,
                                  canManage: canManage,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => DocumentDetailsScreen(document: doc)),
                                    );
                                  },
                                  onDelete: () async {
                                    await docProvider.softDeleteDocument(org.id, doc.id);
                                  },
                                )),
                          ],
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}
