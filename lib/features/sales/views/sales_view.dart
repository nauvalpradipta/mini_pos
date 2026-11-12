import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sale.dart';
import '../viewmodels/sales_view_model.dart';
import 'sale_detail_dialog.dart';
import 'sales_formatters.dart';

class SalesView extends StatefulWidget {
  const SalesView({super.key});

  @override
  State<SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<SalesView> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _scrollController = ScrollController();

    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<SalesViewModel>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.maxScrollExtent - position.pixels < 250) {
      context.read<SalesViewModel>().loadMore();
    }
  }

  // ---------------------------------------------------
  // DATE FILTER
  // ---------------------------------------------------

  Future<void> _pickDateRange(SalesViewModel viewModel) async {
    final now = DateTime.now();

    DateTimeRange? initialRange;

    if (viewModel.startDate != null && viewModel.endDate != null) {
      initialRange = DateTimeRange(
        start: viewModel.startDate!,
        end: viewModel.endDate!,
      );
    }

    final selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: initialRange,
      helpText: 'Pilih periode penjualan',
      cancelText: 'Batal',
      confirmText: 'Terapkan',
      saveText: 'Terapkan',
    );

    if (selectedRange == null || !mounted) return;

    await viewModel.setDateRange(
      startDate: selectedRange.start,
      endDate: selectedRange.end,
    );
  }

  Future<void> _clearDateRange(SalesViewModel viewModel) async {
    await viewModel.clearDateRange();
  }

  String _dateRangeLabel(SalesViewModel viewModel) {
    if (viewModel.startDate == null || viewModel.endDate == null) {
      return 'Semua tanggal';
    }

    return '${formatSalesDateOnly(viewModel.startDate!)} - '
        '${formatSalesDateOnly(viewModel.endDate!)}';
  }

  // ---------------------------------------------------
  // SEARCH
  // ---------------------------------------------------

  Future<void> _clearSearch(SalesViewModel viewModel) async {
    _searchController.clear();
    await viewModel.clearSearch();
  }

  // ---------------------------------------------------
  // DETAIL
  // ---------------------------------------------------

  Future<void> _openDetail(
    SalesViewModel viewModel,
    SaleTransaction transaction,
  ) async {
    final detail = await viewModel.loadDetail(transaction.id);

    if (!mounted) return;

    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.detailErrorMessage ??
                'Tidak dapat memuat detail transaksi.',
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => SaleDetailDialog(detail: detail),
    );

    viewModel.clearDetail();
  }

  // ---------------------------------------------------
  // BUILD
  // ---------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SalesViewModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Penjualan', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 3),
                      Text(
                        _dateRangeLabel(viewModel),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Pilih periode tanggal',
                  onPressed: () => _pickDateRange(viewModel),
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
                if (viewModel.startDate != null || viewModel.endDate != null)
                  IconButton(
                    tooltip: 'Hapus filter tanggal',
                    onPressed: () => _clearDateRange(viewModel),
                    icon: const Icon(Icons.filter_alt_off_outlined),
                  ),
                IconButton(
                  tooltip: 'Muat ulang penjualan',
                  onPressed: viewModel.isLoading ? null : viewModel.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

          TabBar(
            tabs: const [
              Tab(
                key: ValueKey('sales-summary-tab'),
                icon: Icon(Icons.analytics_outlined),
                text: 'Ringkasan',
              ),
              Tab(
                key: ValueKey('sales-history-tab'),
                icon: Icon(Icons.receipt_long_outlined),
                text: 'Riwayat',
              ),
            ],
          ),

          Expanded(
            child: TabBarView(
              children: [
                _buildSummaryTab(viewModel, theme, colorScheme),
                _buildHistoryTab(viewModel, theme, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // SUMMARY TAB
  // ---------------------------------------------------

  Widget _buildSummaryTab(
    SalesViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (viewModel.isLoading && viewModel.summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.summary == null && viewModel.errorMessage != null) {
      return _buildErrorState(viewModel.errorMessage!, viewModel.refresh);
    }

    final summary = viewModel.summary;

    if (summary == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      key: const ValueKey('sales-summary-content'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performa Penjualan', style: theme.textTheme.titleMedium),

          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;

              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;

              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricCard(
                      title: 'Omzet Bersih',
                      value: formatSalesCurrency(summary.revenue),
                      subtitle: 'Setelah diskon',
                      icon: Icons.payments_outlined,
                      color: colorScheme.primary,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricCard(
                      title: 'Transaksi',
                      value: '${summary.transactionCount}',
                      subtitle: 'Jumlah transaksi',
                      icon: Icons.receipt_long_outlined,
                      color: colorScheme.tertiary,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricCard(
                      title: 'Total Diskon',
                      value: formatSalesCurrency(summary.totalDiscount),
                      subtitle: 'Potongan penjualan',
                      icon: Icons.discount_outlined,
                      color: colorScheme.error,
                      theme: theme,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildMetricCard(
                      title: 'Rata-rata Transaksi',
                      value: formatSalesCurrency(summary.averageTransaction),
                      subtitle: 'Per transaksi',
                      icon: Icons.trending_up_outlined,
                      color: colorScheme.secondary,
                      theme: theme,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Transaksi Terbaru',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Builder(
                builder: (tabContext) {
                  return TextButton(
                    onPressed: () {
                      DefaultTabController.of(tabContext).animateTo(1);
                    },
                    child: const Text('Lihat semua'),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (viewModel.transactions.isEmpty)
            _buildEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada transaksi',
              description:
                  'Transaksi yang berhasil disimpan akan muncul di sini.',
            )
          else
            ...viewModel.transactions
                .take(5)
                .map(
                  (transaction) =>
                      _buildTransactionCard(transaction, theme, colorScheme),
                ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              key: ValueKey('sales-metric-$title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // HISTORY TAB
  // ---------------------------------------------------

  Widget _buildHistoryTab(
    SalesViewModel viewModel,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            key: const ValueKey('sales-search-field'),
            controller: _searchController,
            onChanged: viewModel.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Cari nomor struk atau nama kasir...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: viewModel.searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () => _clearSearch(viewModel),
                      icon: const Icon(Icons.close),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        if (viewModel.isLoading && viewModel.hasLoaded)
          const LinearProgressIndicator(minHeight: 2),

        if (viewModel.isLoading && !viewModel.hasLoaded)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (viewModel.errorMessage != null && !viewModel.hasTransactions)
          Expanded(
            child: _buildErrorState(viewModel.errorMessage!, viewModel.refresh),
          )
        else if (viewModel.isEmpty)
          Expanded(
            child: _buildEmptyState(
              icon: Icons.receipt_long_outlined,
              title: viewModel.searchQuery.isNotEmpty
                  ? 'Transaksi tidak ditemukan'
                  : 'Belum ada transaksi',
              description: viewModel.searchQuery.isNotEmpty
                  ? 'Coba nomor struk atau nama kasir yang lain.'
                  : 'Riwayat transaksi akan muncul setelah checkout berhasil.',
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: viewModel.refresh,
              child: ListView.builder(
                key: const ValueKey('sales-transaction-list'),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount:
                    viewModel.transactions.length + (viewModel.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= viewModel.transactions.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: viewModel.isLoadingMore
                            ? const CircularProgressIndicator()
                            : const SizedBox(height: 20),
                      ),
                    );
                  }

                  final transaction = viewModel.transactions[index];

                  return _buildTransactionCard(transaction, theme, colorScheme);
                },
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------
  // TRANSACTION CARD
  // ---------------------------------------------------

  Widget _buildTransactionCard(
    SaleTransaction transaction,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      key: ValueKey('sales-transaction-${transaction.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _openDetail(context.read<SalesViewModel>(), transaction);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.receiptNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${transaction.cashierName} • '
                      '${formatSalesDate(transaction.transactionAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (transaction.discountAmount > 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Diskon ${formatSalesCurrency(transaction.discountAmount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatSalesCurrency(transaction.total),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------
  // EMPTY AND ERROR STATES
  // ---------------------------------------------------

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, Future<void> Function() onRetry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
