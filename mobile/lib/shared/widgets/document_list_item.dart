import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../features/documents/models/document_model.dart';
import 'file_type_icon.dart';

class DocumentListItem extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final bool isTrash;
  final bool canManage;

  const DocumentListItem({
    super.key,
    required this.document,
    required this.onTap,
    this.onDownload,
    this.onDelete,
    this.onRestore,
    this.isTrash = false,
    this.canManage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: FileTypeIcon(contentType: document.contentType, size: 24),
        title: Text(
          document.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              Formatters.formatBytes(document.fileSizeBytes),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            const Text('•', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(width: 8),
            Text(
              Formatters.formatDateShort(isTrash ? document.deletedAt : document.createdAt),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: isTrash
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.restore_rounded, color: AppColors.success),
                    tooltip: 'Restore',
                    onPressed: onRestore,
                  ),
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                      tooltip: 'Delete Permanently',
                      onPressed: onDelete,
                    ),
                ],
              )
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                onSelected: (val) {
                  if (val == 'download') onDownload?.call();
                  if (val == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Download'),
                      ],
                    ),
                  ),
                  if (canManage)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text('Move to Trash', style: TextStyle(color: AppColors.danger)),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
