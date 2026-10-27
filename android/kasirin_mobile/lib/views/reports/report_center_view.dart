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
  final _rupiahFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<QueryRow> _recentSales = [];
  List<QueryRow> _stockRows = [];
  int _tab = 0;

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

      if (mounted) {
        setState(() {
          _stats = stats;
          _recentSales = sales;
          _stockRows = stock;
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Ringkasan')),
                ButtonSegment(value: 1, label: Text('Penjualan')),
                ButtonSegment(value: 2, label: Text('Stok')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tab == 1
                    ? _buildSalesList()
                    : _tab == 2
                        ? _buildStockList()
                        : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OwnerSectionHeading(
                    title: 'Ringkasan hari ini',
                    subtitle: 'Performa toko yang tercatat pada hari ini.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Omzet Hari Ini',
                          value: _rupiahFormat.format(_stats['todaySales'] ?? 0),
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
                    subtitle: 'Penjualan terakhir yang tersimpan di perangkat.',
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
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentSales.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final sale = _recentSales[index];
                            final invoice = sale.read<String>('invoice_no');
                            final total = sale.read<int>('grand_total');
                            final date = sale.read<String>('created_at');
                            final cashier =
                                sale.read<String?>('cashier_name') ?? 'Kasir';

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFD7DEE5)),
                              ),
                              color: Colors.white,
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF18794E)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_outlined,
                                    color: Color(0xFF18794E),
                                  ),
                                ),
                                title: Text(
                                  invoice,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Kasir: $cashier  •  ${date.length >= 16 ? date.substring(0, 16).replaceAll("T", " ") : date}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  _rupiahFormat.format(total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF006EAE),
                                  ),
                                ),
                              ),
                            );
                          },
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
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _recentSales.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final sale = _recentSales[index];
        final date = DateTime.tryParse(sale.read<String>('created_at'))?.toLocal();
        return OwnerSurface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF18794E).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF18794E)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sale.read<String>('invoice_no'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      '${sale.read<String?>('cashier_name') ?? 'Kasir'} · ${date == null ? '' : DateFormat('dd MMM, HH:mm').format(date)}',
                      style: const TextStyle(color: ownerMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _rupiahFormat.format(sale.read<int>('grand_total')),
                style: const TextStyle(color: ownerBlue, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockList() {
    if (_stockRows.isEmpty) {
      return const OwnerEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum ada data stok',
        message: 'Tambahkan produk untuk mulai memantau persediaan.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _stockRows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final product = _stockRows[index];
        final stock = product.read<int>('stock_qty');
        final minimum = product.read<int>('min_stock');
        final isLow = stock <= minimum;
        final color = isLow ? const Color(0xFFB42318) : const Color(0xFF18794E);
        return OwnerSurface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.read<String>('name'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('${product.read<String>('sku')} · Minimum $minimum', style: const TextStyle(color: ownerMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(20)),
                child: Text('$stock tersedia', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
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

