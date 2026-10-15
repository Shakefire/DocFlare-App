import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/upload_progress_tile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/upload_provider.dart';
import '../../organization/providers/organization_provider.dart';

class UploadQueueScreen extends StatelessWidget {
  const UploadQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uploadProvider = context.watch<UploadProvider>();
    final org = context.watch<OrganizationProvider>().activeOrganization;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Upload Queue', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        actions: [
          if (uploadProvider.tasks.any((t) => t.status == UploadTaskStatus.completed))
            TextButton(
              onPressed: () => uploadProvider.clearCompleted(),
              child: const Text('Clear Done', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: uploadProvider.tasks.isEmpty
          ? const EmptyState(
              icon: Icons.cloud_done_outlined,
              title: 'Upload Queue is Empty',
              message: 'Files you upload will show their progress and completion state here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: uploadProvider.tasks.length,
              itemBuilder: (context, index) {
                final task = uploadProvider.tasks[index];
                return UploadProgressTile(
                  task: task,
                  onRetry: () {
                    if (org != null) uploadProvider.retryTask(task, org.id);
                  },
                  onCancel: () => uploadProvider.cancelTask(task),
                );
              },
            ),
    );
  }
}
