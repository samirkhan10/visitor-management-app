import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/visitor_status.dart';
import '../../providers/visitor_provider.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/state_views.dart';
import '../../widgets/visitor_card.dart';
import '../visitor_navigation.dart';

class VisitorListScreen extends StatefulWidget {
  const VisitorListScreen({super.key, required this.onOpenScanner});

  final VoidCallback onOpenScanner;

  @override
  State<VisitorListScreen> createState() => _VisitorListScreenState();
}

class _VisitorListScreenState extends State<VisitorListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: context.read<VisitorProvider>().searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<VisitorProvider>().updateSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VisitorProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitors'),
        actions: [
          IconButton(
            tooltip: 'Scan QR',
            onPressed: widget.onOpenScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: provider.isLoading ? null : provider.loadVisitors,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openRegisterVisitor(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Register'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by name or mobile',
              leading: const Icon(Icons.search_rounded),
              onChanged: provider.updateSearch,
              trailing: [
                if (provider.searchQuery.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          _StatusFilterBar(
            selected: provider.statusFilter,
            onSelected: provider.updateStatusFilter,
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildBody(VisitorProvider provider) {
    if (provider.isLoading && !provider.hasLoaded) {
      return const VisitorListSkeleton();
    }

    if (provider.loadError != null && provider.visitors.isEmpty) {
      return ErrorStateView(message: provider.loadError!, onRetry: provider.loadVisitors);
    }

    final visitors = provider.filteredVisitors;

    return RefreshIndicator(
      onRefresh: provider.loadVisitors,
      child: visitors.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(height: constraints.maxHeight, child: _buildEmptyState(provider)),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: visitors.length,
              itemBuilder: (context, index) {
                final visitor = visitors[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeSlideIn(
                    key: ValueKey(visitor.id),
                    index: index,
                    child: VisitorCard(
                      visitor: visitor,
                      isBusy: provider.isBusy(visitor.id),
                      onTap: () => openVisitorDetails(context, visitor.id),
                      onEdit: () => openEditVisitor(context, visitor),
                      onDelete: () => deleteVisitorWithConfirmation(context, visitor),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(VisitorProvider provider) {
    final isFiltering = provider.searchQuery.isNotEmpty || provider.statusFilter != null;

    if (isFiltering) {
      return EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'No matching visitors',
        message: 'Try a different name, mobile number or status filter.',
        action: TextButton(
          onPressed: () {
            _clearSearch();
            provider.updateStatusFilter(null);
          },
          child: const Text('Clear filters'),
        ),
      );
    }

    return EmptyStateView(
      icon: Icons.people_outline_rounded,
      title: 'No visitors yet',
      message: 'Registered visitors will appear here.',
      action: SizedBox(
        width: 200,
        child: ElevatedButton.icon(
          onPressed: () => openRegisterVisitor(context),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: const Text('Register visitor'),
        ),
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelected});

  final VisitorStatus? selected;
  final ValueChanged<VisitorStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <VisitorStatus?>[null, ...VisitorStatus.values];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = options[index];
          return ChoiceChip(
            label: Text(status?.label ?? 'All'),
            selected: selected == status,
            showCheckmark: false,
            onSelected: (_) => onSelected(status),
          );
        },
      ),
    );
  }
}
