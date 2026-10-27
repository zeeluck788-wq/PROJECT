import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../owner/owner_widgets.dart';

class ReportCenterView extends ConsumerStatefulWidget {
  const ReportCenterView({super.key});

  @override
  ConsumerState<ReportCenterView> createState() => _ReportCenterViewState();
}

class _ReportCenterViewState extends ConsumerState<ReportCenterView> {
  final _rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _financialReport = {};
  List<QueryRow> _recentSales = [];
  List<QueryRow> _stockRows = [];
  int _tab = 0;
  bool _onlyStockBelowFive = false;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      final stats = await repository.getDashboardStats();
      final sales = await repository.getRecentSales(limit: 100);
      final stock = await repository.getStockReport();
      final financial = await repository.getFinancialReport();

      if (mounted) {
        setState(() {
          _stats = stats;
          _recentSales = sales;
          _stockRows = stock;
          _financialReport = financial;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OwnerScaffold(
      title: 'Laporan',
      onBack: () => context.go('/'),
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReportData),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: OwnerTabBar<int>(
              tabs: const [
                (0, 'Ringkasan'),
                (1, 'Penjualan'),
                (2, 'Stok'),
                (3, 'Keuangan'),
              ],
              selected: _tab,
              onSelected: (value) => setState(() => _tab = value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tab == 1
                ? _buildSalesList()
                : _tab == 2
                ? _buildStockList()
                : _tab == 3
                ? _buildFinancialReport()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OwnerSectionHeading(
                          title: 'Ringkasan hari ini',
                          subtitle:
                              'Performa toko yang tercatat pada hari ini.',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Omzet Hari Ini',
                                value: _rupiahFormat.format(
                                  _stats['todaySales'] ?? 0,
                                ),
                                icon: Icons.payments_outlined,
                                color: const Color(0xFF18794E),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Transaksi Hari Ini',
                                value: '${_stats['todayCount'] ?? 0}',
                                icon: Icons.receipt_long_outlined,
                                color: const Color(0xFF006EAE),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Total Produk Aktif',
                                value: '${_stats['productCount'] ?? 0}',
                                icon: Icons.inventory_2_outlined,
                                color: const Color(0xFF586575),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                title: 'Peringatan Stok Rendah',
                                value: '${_stats['lowStockCount'] ?? 0}',
                                icon: Icons.warning_amber_rounded,
                                color: const Color(0xFFB42318),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const OwnerSectionHeading(
                          title: 'Transaksi terbaru',
                          subtitle:
                              'Penjualan terakhir yang tersimpan di perangkat.',
                        ),
                        const SizedBox(height: 12),
                        _recentSales.isEmpty
                            ? const OwnerSurface(
                                child: Text(
                                  'Belum ada transaksi penjualan yang tercatat.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: ownerMuted),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFEAF1F6),
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('No. Faktur')),
                                    DataColumn(label: Text('Tanggal')),
                                    DataColumn(label: Text('Kasir')),
                                    DataColumn(
                                      label: Text('Total'),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: _recentSales.map((sale) {
                                    final date = DateTime.tryParse(
                                      sale.read<String>('created_at'),
                                    )?.toLocal();
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(sale.read<String>('invoice_no')),
                                        ),
                                        DataCell(
                                          Text(
                                            date == null
                                                ? '-'
                                                : DateFormat(
                                                    'dd MMM yyyy, HH:mm',
                                                  ).format(date),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            sale.read<String?>(
                                                  'cashier_name',
                                                ) ??
                                                'Kasir',
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            _rupiahFormat.format(
                                              sale.read<int>('grand_total'),
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesList() {
    if (_recentSales.isEmpty) {
      return const OwnerEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada penjualan',
        message: 'Transaksi yang selesai akan tampil di sini.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF1F6)),
          columns: const [
            DataColumn(label: Text('No. Faktur')),
            DataColumn(label: Text('Tanggal')),
            DataColumn(label: Text('Kasir')),
            DataColumn(label: Text('Total'), numeric: true),
          ],
          rows: _recentSales.map((sale) {
            final date = DateTime.tryParse(sale.read<String>('created_at'))
                ?.toLocal();
            return DataRow(
              cells: [
                DataCell(Text(sale.read<String>('invoice_no'))),
                DataCell(
                  Text(
                    date == null
                        ? '-'
                        : DateFormat('dd MMM yyyy, HH:mm').format(date),
                  ),
                ),
                DataCell(Text(sale.read<String?>('cashier_name') ?? 'Kasir')),
                DataCell(
                  Text(_rupiahFormat.format(sale.read<int>('grand_total'))),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStockList() {
    final rows = _onlyStockBelowFive
        ? _stockRows
              .where((product) => product.read<int>('stock_qty') < 5)
              .toList()
        : _stockRows;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CheckboxListTile(
            value: _onlyStockBelowFive,
            onChanged: (value) =>
                setState(() => _onlyStockBelowFive = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Stok < 5'),
            subtitle: const Text(
              'Tampilkan produk dengan stok aktual di bawah 5 unit.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => context.go('/purchase?newOrder=true'),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Buat Pesanan'),
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? OwnerEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: _stockRows.isEmpty
                      ? 'Belum ada data stok'
                      : 'Tidak ada produk yang cocok',
                  message: _stockRows.isEmpty
                      ? 'Tambahkan produk untuk mulai memantau persediaan.'
                      : 'Tidak ada produk dengan stok aktual di bawah 5.',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFEAF1F6),
                      ),
                      columns: const [
                        DataColumn(label: Text('SKU')),
                        DataColumn(label: Text('Nama produk')),
                        DataColumn(label: Text('Stok'), numeric: true),
                        DataColumn(label: Text('Minimum'), numeric: true),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Harga beli'), numeric: true),
                        DataColumn(label: Text('Harga jual'), numeric: true),
                      ],
                      rows: rows.map((product) {
                        final stock = product.read<int>('stock_qty');
                        final minimum = product.read<int>('min_stock');
                        final low = stock <= minimum;
                        return DataRow(
                          cells: [
                            DataCell(Text(product.read<String>('sku'))),
                            DataCell(
                              SizedBox(
                                width: 170,
                                child: Text(
                                  product.read<String>('name'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text('$stock')),
                            DataCell(Text('$minimum')),
                            DataCell(
                              Text(
                                low ? 'Stok rendah' : 'Aman',
                                style: TextStyle(
                                  color: low
                                      ? const Color(0xFFB42318)
                                      : const Color(0xFF18794E),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _rupiahFormat.format(
                                  product.read<int>('purchase_price'),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _rupiahFormat.format(
                                  product.read<int>('selling_price'),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFinancialReport() {
    final startDate = DateTime.tryParse(
      _financialReport['startDate'] as String? ?? '',
    );
    final endDate = DateTime.tryParse(
      _financialReport['endDate'] as String? ?? '',
    );
    final accounts = _financialReport['accounts'] as List<QueryRow>? ?? [];
    final netProfit = _financialReport['netProfit'] as int? ?? 0;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OwnerSectionHeading(
            title: 'Laporan keuangan',
            subtitle: 'Akumulasi pencatatan keuangan sejak toko dibuka sampai hari ini.',
          ),
          const SizedBox(height: 8),
          Text(
            'Periode: ${startDate == null ? '—' : dateFormat.format(startDate)} – ${endDate == null ? '—' : dateFormat.format(endDate)}',
            style: const TextStyle(color: ownerMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _financialStatRow(
            'Pendapatan',
            _rupiahFormat.format(_financialReport['revenue'] ?? 0),
            Icons.trending_up_rounded,
            const Color(0xFF18794E),
            'Beban',
            _rupiahFormat.format(_financialReport['expenses'] ?? 0),
            Icons.trending_down_rounded,
            const Color(0xFFB42318),
          ),
          const SizedBox(height: 12),
          _financialStatRow(
            'Laba / Rugi Bersih',
            _rupiahFormat.format(netProfit),
            netProfit >= 0
                ? Icons.account_balance_wallet_outlined
                : Icons.warning_amber_rounded,
            netProfit >= 0 ? const Color(0xFF006EAE) : const Color(0xFFB42318),
            'Aset',
            _rupiahFormat.format(_financialReport['assets'] ?? 0),
            Icons.account_balance_outlined,
            const Color(0xFF586575),
          ),
          const SizedBox(height: 12),
          _financialStatRow(
            'Kewajiban / Hutang',
            _rupiahFormat.format(_financialReport['liabilities'] ?? 0),
            Icons.receipt_long_outlined,
            const Color(0xFF9A6700),
            'Modal',
            _rupiahFormat.format(_financialReport['equity'] ?? 0),
            Icons.savings_outlined,
            const Color(0xFF586575),
          ),
          const SizedBox(height: 24),
          const OwnerSectionHeading(
            title: 'Rincian akun',
            subtitle:
                'Saldo bersih setiap akun berdasarkan jurnal pada periode ini.',
          ),
          const SizedBox(height: 12),
          OwnerSurface(
            padding: EdgeInsets.zero,
            child: accounts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Belum ada akun keuangan.'),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFEAF1F6),
                      ),
                      columns: const [
                        DataColumn(label: Text('KODE')),
                        DataColumn(label: Text('NAMA AKUN')),
                        DataColumn(label: Text('JENIS')),
                        DataColumn(label: Text('DEBIT'), numeric: true),
                        DataColumn(label: Text('KREDIT'), numeric: true),
                        DataColumn(label: Text('SALDO'), numeric: true),
                      ],
                      rows: accounts.map((account) {
                        return DataRow(
                          cells: [
                            DataCell(Text(account.read<String>('code'))),
                            DataCell(Text(account.read<String>('name'))),
                            DataCell(
                              Text(
                                _accountTypeLabel(
                                  account.read<String>('account_type'),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _rupiahFormat.format(
                                  account.read<int>('debit'),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _rupiahFormat.format(
                                  account.read<int>('credit'),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _rupiahFormat.format(
                                  account.read<int>('balance'),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _financialStatRow(
    String firstTitle,
    String firstValue,
    IconData firstIcon,
    Color firstColor,
    String secondTitle,
    String secondValue,
    IconData secondIcon,
    Color secondColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: firstTitle,
            value: firstValue,
            icon: firstIcon,
            color: firstColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            title: secondTitle,
            value: secondValue,
            icon: secondIcon,
            color: secondColor,
          ),
        ),
      ],
    );
  }

  String _accountTypeLabel(String value) => switch (value) {
    'ASSET' => 'Aset',
    'LIABILITY' => 'Kewajiban',
    'EQUITY' => 'Modal',
    'REVENUE' => 'Pendapatan',
    'EXPENSE' => 'Beban',
    _ => value,
  };
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OwnerSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF586575),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
