import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/file_type_icon.dart';
import '../models/document_model.dart';
import '../providers/document_provider.dart';
import '../../organization/providers/organization_provider.dart';
import 'preview_screen.dart';

class DocumentDetailsScreen extends StatefulWidget {
  final DocumentModel document;

  const DocumentDetailsScreen({super.key, required this.document});

  @override
  State<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends State<DocumentDetailsScreen> {
  late DocumentModel _doc;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
  }

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/${_doc.displayName}';
      final client = ApiClient();

      await client.downloadFile(
        '/documents/${_doc.id}/download',
        filePath,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (!mounted) return;
      setState(() => _isDownloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded: ${_doc.displayName}'),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => OpenFilex.open(filePath),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showEditMetadataDialog(String orgId) {
    final nameController = TextEditingController(text: _doc.displayName);
    final descController = TextEditingController(text: _doc.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Metadata'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Display Name')),
            const SizedBox(height: 12),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              Navigator.of(ctx).pop();

              final docProvider = context.read<DocumentProvider>();
              await docProvider.updateDocument(
                orgId,
                _doc.id,
                displayName: newName,
                description: descController.text.trim(),
              );

              setState(() {
                _doc = DocumentModel(
                  id: _doc.id,
                  organizationId: _doc.organizationId,
                  folderId: _doc.folderId,
                  ownerId: _doc.ownerId,
                  uploadedBy: _doc.uploadedBy,
                  displayName: newName,
                  contentType: _doc.contentType,
                  fileSizeBytes: _doc.fileSizeBytes,
                  checksum: _doc.checksum,
                  description: descController.text.trim(),
                  uploadStatus: _doc.uploadStatus,
                  createdAt: _doc.createdAt,
                  updatedAt: DateTime.now().toIso8601String(),
                );
              });
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String orgId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text('Are you sure you want to move "${_doc.displayName}" to trash? You can restore it later.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final docProvider = context.read<DocumentProvider>();
              await docProvider.softDeleteDocument(orgId, _doc.id);
              if (!mounted) return;
              Navigator.of(context).pop(); // Back to library
            },
            child: const Text('Move to Trash', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>().activeOrganization;
    final canManage = org != null && !org.isViewer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Document Details', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        actions: [
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
              tooltip: 'Edit details',
              onPressed: () => _showEditMetadataDialog(org.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              tooltip: 'Move to trash',
              onPressed: () => _confirmDelete(org.id),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                FileTypeIcon(contentType: _doc.contentType, size: 40),
                const SizedBox(height: 16),
                Text(
                  _doc.displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.formatBytes(_doc.fileSizeBytes),
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_doc.isPreviewable)
                      Expanded(
                        child: AppButton(
                          label: 'Preview',
                          icon: Icons.visibility_outlined,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => PreviewScreen(document: _doc)),
                            );
                          },
                        ),
                      ),
                    if (_doc.isPreviewable) const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: _isDownloading ? 'Downloading...' : 'Download',
                        icon: Icons.download_rounded,
                        isSecondary: _doc.isPreviewable,
                        isLoading: _isDownloading,
                        onPressed: _isDownloading ? null : _handleDownload,
                      ),
                    ),
                  ],
                ),
                if (_isDownloading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Metadata Details Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('METADATA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 16),
                _buildMetaRow('File Type', _doc.contentType),
                _buildMetaRow('File Size', '${Formatters.formatBytes(_doc.fileSizeBytes)} (${_doc.fileSizeBytes} bytes)'),
                _buildMetaRow('Uploaded On', Formatters.formatDate(_doc.createdAt)),
                _buildMetaRow('Last Modified', Formatters.formatDate(_doc.updatedAt)),
                if (_doc.checksum != null) _buildMetaRow('MD5 Checksum', _doc.checksum!),
                if (_doc.description != null && _doc.description!.isNotEmpty)
                  _buildMetaRow('Description', _doc.description!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
