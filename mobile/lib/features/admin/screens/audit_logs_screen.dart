import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../organization/providers/organization_provider.dart';
import '../providers/admin_provider.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  String _selectedAction = '';

  final List<Map<String, String>> _actionFilters = [
    {'label': 'All Actions', 'value': ''},
    {'label': 'Uploads', 'value': 'document.uploaded'},
    {'label': 'Downloads', 'value': 'document.downloaded'},
    {'label': 'Deletions', 'value': 'document.deleted'},
    {'label': 'Members', 'value': 'member.invited'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLogs();
    });
  }

  void _loadLogs() {
    final org = context.read<OrganizationProvider>().activeOrganization;
    if (org != null) {
      context.read<AdminProvider>().loadAuditLogs(
            org.id,
            action: _selectedAction.isNotEmpty ? _selectedAction : null,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>().activeOrganization;
    final adminProvider = context.watch<AdminProvider>();

    if (org == null) {
      return const Scaffold(body: Center(child: Text('No active organization')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Audit History', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _actionFilters.map((f) {
                  final isSelected = _selectedAction == f['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f['label']!),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                      ),
                      onSelected: (selected) {
                        setState(() => _selectedAction = selected ? f['value']! : '');
                        _loadLogs();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Audit Log Entries
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => _loadLogs(),
              child: adminProvider.isLoading
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
                  : adminProvider.auditLogs.isEmpty
                      ? const EmptyState(
                          icon: Icons.history_rounded,
                          title: 'No Audit Logs Recorded',
                          message: 'Organization actions and security events will be tracked here.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: adminProvider.auditLogs.length,
                          itemBuilder: (context, index) {
                            final log = adminProvider.auditLogs[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.bolt_rounded, size: 18, color: AppColors.primary),
                                ),
                                title: Text(
                                  log.action,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      'Actor: ${log.actorEmail ?? log.actorUserId}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      'Target: ${log.resourceType} (${log.resourceId.substring(0, log.resourceId.length > 8 ? 8 : log.resourceId.length)}...)',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  Formatters.formatDateShort(log.createdAt),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
