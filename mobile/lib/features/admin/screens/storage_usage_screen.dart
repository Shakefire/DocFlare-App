import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../organization/providers/organization_provider.dart';
import '../providers/admin_provider.dart';

class StorageUsageScreen extends StatefulWidget {
  const StorageUsageScreen({super.key});

  @override
  State<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends State<StorageUsageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final org = context.read<OrganizationProvider>().activeOrganization;
      if (org != null) {
        context.read<AdminProvider>().loadStorageUsage(org.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>().activeOrganization;
    final adminProvider = context.watch<AdminProvider>();
    final stats = adminProvider.storageUsage;

    if (org == null) {
      return const Scaffold(body: Center(child: Text('No active organization')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Storage & Quota', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => adminProvider.loadStorageUsage(org.id),
        child: adminProvider.isLoading
            ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
            : stats == null
                ? const Center(child: Text('Unable to load storage statistics'))
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Overview Card
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
                            const Text('TOTAL CONSUMPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  Formatters.formatBytes(stats['storage_used_bytes'] ?? 0),
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  '${stats['usage_percentage'] ?? 0}% Used',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Quota: ${Formatters.formatBytes(stats['storage_quota_bytes'] ?? 1)}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ((stats['usage_percentage'] ?? 0) / 100).toDouble().clamp(0.0, 1.0),
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Category Breakdown Card
                      const Text('BREAKDOWN BY TYPE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            if (stats['by_category'] is List)
                              ...(stats['by_category'] as List).map((cat) {
                                return Column(
                                  children: [
                                    ListTile(
                                      title: Text(
                                        (cat['category'] as String).toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      subtitle: Text('${cat['count'] ?? 0} files'),
                                      trailing: Text(
                                        Formatters.formatBytes(cat['total_bytes'] ?? 0),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Trash Storage Card
                      if (stats['trash'] != null) ...[
                        const Text('TRASH RETENTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${stats['trash']['count'] ?? 0} deleted items',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Soft-deleted (30-day purge cycle)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                              Text(
                                Formatters.formatBytes(stats['trash']['bytes'] ?? 0),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}
