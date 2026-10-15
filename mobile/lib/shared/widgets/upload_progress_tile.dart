import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../features/documents/providers/upload_provider.dart';
import 'file_type_icon.dart';

class UploadProgressTile extends StatelessWidget {
  final UploadTask task;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const UploadProgressTile({
    super.key,
    required this.task,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;

    switch (task.status) {
      case UploadTaskStatus.pending:
        statusColor = AppColors.warning;
        statusText = 'Waiting...';
        break;
      case UploadTaskStatus.uploading:
        statusColor = AppColors.primary;
        statusText = '${(task.progress * 100).toInt()}% Uploading';
        break;
      case UploadTaskStatus.completed:
        statusColor = AppColors.success;
        statusText = 'Completed';
        break;
      case UploadTaskStatus.failed:
        statusColor = AppColors.danger;
        statusText = 'Failed';
        break;
      case UploadTaskStatus.cancelled:
        statusColor = AppColors.textMuted;
        statusText = 'Cancelled';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FileTypeIcon(contentType: task.contentType, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.formatBytes(task.fileSize)} • $statusText',
                      style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (task.status == UploadTaskStatus.uploading || task.status == UploadTaskStatus.pending)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: onCancel,
                  tooltip: 'Cancel upload',
                )
              else if (task.status == UploadTaskStatus.failed)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                  onPressed: onRetry,
                  tooltip: 'Retry upload',
                ),
            ],
          ),
          if (task.status == UploadTaskStatus.uploading || task.status == UploadTaskStatus.pending) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.status == UploadTaskStatus.pending ? null : task.progress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ],
          if (task.errorMessage != null && task.status == UploadTaskStatus.failed) ...[
            const SizedBox(height: 6),
            Text(
              task.errorMessage!,
              style: const TextStyle(fontSize: 11, color: AppColors.danger),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
