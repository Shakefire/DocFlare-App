import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/document_list_item.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../organization/providers/organization_provider.dart';
import '../../documents/providers/document_provider.dart';
import '../../documents/models/document_model.dart';
import '../../documents/screens/document_details_screen.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final _searchController = TextEditingController();
  String _selectedType = '';
  String _sortBy = 'created_at';
  final String _order = 'DESC';
  bool _isSearching = false;
  List<DocumentModel> _results = [];

  final List<Map<String, String>> _typeFilters = [
    {'label': 'All', 'value': ''},
    {'label': 'PDFs', 'value': 'pdf'},
    {'label': 'Images', 'value': 'image'},
    {'label': 'Videos', 'value': 'video'},
    {'label': 'Office', 'value': 'officedocument'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final org = context.read<OrganizationProvider>().activeOrganization;
    if (org == null) return;

    setState(() => _isSearching = true);

    final docProvider = context.read<DocumentProvider>();
    final results = await docProvider.searchDocuments(
      org.id,
      query: _searchController.text.trim(),
      type: _selectedType.isNotEmpty ? _selectedType : null,
      sortBy: _sortBy,
      order: _order,
    );

    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Search input bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => _performSearch(),
                  onSubmitted: (_) => _performSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search documents by filename...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _typeFilters.map((f) {
                      final isSelected = _selectedType == f['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f['label']!),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.18),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                          ),
                          onSelected: (selected) {
                            setState(() => _selectedType = selected ? f['value']! : '');
                            _performSearch();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Sort Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_results.length} results found',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                      items: const [
                        DropdownMenuItem(value: 'created_at', child: Text('Sort: Date Added')),
                        DropdownMenuItem(value: 'display_name', child: Text('Sort: Name')),
                        DropdownMenuItem(value: 'file_size_bytes', child: Text('Sort: File Size')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _sortBy = val);
                          _performSearch();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
                : _results.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No Documents Found',
                        message: 'Try adjusting your search keywords or filter settings.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final doc = _results[index];
                          return DocumentListItem(
                            document: doc,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => DocumentDetailsScreen(document: doc)),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
