import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import 'owner_widgets.dart';

class MasterDataView extends ConsumerStatefulWidget {
  const MasterDataView({super.key});

  @override
  ConsumerState<MasterDataView> createState() => _MasterDataViewState();
}

class _MasterDataViewState extends ConsumerState<MasterDataView> {
  final _searchController = TextEditingController();
  final _rupiahFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  List<QueryRow> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      final list = await repository.products(search: _searchQuery);
      if (mounted) {
        setState(() => _products = list);
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddProductDialog() async {
    final skuController = TextEditingController();
    final barcodeController = TextEditingController();
    final nameController = TextEditingController();
    final purchasePriceController = TextEditingController(text: '0');
    final sellingPriceController = TextEditingController(text: '0');
    final stockController = TextEditingController(text: '10');
    final minStockController = TextEditingController(text: '2');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tambah Produk Baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: skuController,
                decoration: const InputDecoration(labelText: 'Kode SKU *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: barcodeController,
                decoration:
                    const InputDecoration(labelText: 'Barcode (Opsional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama Produk *'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: purchasePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Beli (Rp)',
                        prefixText: 'Rp ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: sellingPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga Jual (Rp) *',
                        prefixText: 'Rp ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stok Awal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: minStockController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Stok Minimum'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006EAE),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final sku = skuController.text.trim();
      final name = nameController.text.trim();
      final barcode = barcodeController.text.trim();
      final purchasePrice =
          int.tryParse(purchasePriceController.text.replaceAll('.', '')) ?? 0;
      final sellingPrice =
          int.tryParse(sellingPriceController.text.replaceAll('.', '')) ?? 0;
      final initialStock = int.tryParse(stockController.text) ?? 0;
      final minStock = int.tryParse(minStockController.text) ?? 0;

      if (sku.isEmpty || name.isEmpty || sellingPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SKU, Nama, dan Harga Jual wajib diisi dengan benar.'),
            backgroundColor: Color(0xFFB42318),
          ),
        );
        return;
      }

      try {
        final repository = await ref.read(repositoryFutureProvider.future);
        await repository.createProduct(
          sku: sku,
          name: name,
          barcode: barcode.isEmpty ? null : barcode,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          initialStock: initialStock,
          minimumStock: minStock,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produk berhasil ditambahkan.'),
              backgroundColor: Color(0xFF18794E),
            ),
          );
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal: $e'),
              backgroundColor: const Color(0xFFB42318),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteProduct(QueryRow product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text(
          'Produk "${product.read<String>('name')}" akan dinonaktifkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repository = await ref.read(repositoryFutureProvider.future);
        await repository.deleteProduct(product.read<int>('id'));
        _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleProducts = _tab == 1
        ? _products
            .where((product) =>
                product.read<int>('stock_qty') <= product.read<int>('min_stock'))
            .toList()
        : _products;
    return OwnerScaffold(
      title: 'Produk & Stok',
      onBack: () => context.go('/'),
      actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Tambah Produk',
            onPressed: _showAddProductDialog,
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Semua produk')),
                ButtonSegment(value: 1, label: Text('Stok rendah')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) => setState(() => _tab = value.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari SKU, Barcode, atau Nama Produk...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _refresh();
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _refresh();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : visibleProducts.isEmpty
                    ? OwnerEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: _tab == 1
                            ? 'Stok aman'
                            : _searchQuery.isEmpty
                            ? 'Katalog masih kosong'
                            : 'Produk tidak ditemukan',
                        message: _tab == 1
                            ? 'Tidak ada produk yang mencapai batas stok minimum.'
                            : _searchQuery.isEmpty
                            ? 'Tambahkan produk pertama untuk mulai mengelola harga dan stok.'
                            : 'Coba kata kunci atau SKU yang berbeda.',
                        action: _tab == 0 && _searchQuery.isEmpty
                            ? FilledButton.icon(
                                onPressed: _showAddProductDialog,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Tambah produk'),
                              )
                            : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: visibleProducts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = visibleProducts[index];
                          final name = product.read<String>('name');
                          final sku = product.read<String>('sku');
                          final barcode =
                              product.read<String?>('barcode') ?? '-';
                          final sellingPrice =
                              product.read<int>('selling_price');
                          final purchasePrice =
                              product.read<int>('purchase_price');
                          final stock = product.read<int>('stock_qty');
                          final minStock = product.read<int>('min_stock');

                          return OwnerSurface(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF006EAE)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Color(0xFF006EAE),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF17212B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'SKU $sku  ·  Barcode $barcode',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: ownerMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Nonaktifkan produk',
                                    icon: const Icon(Icons.more_horiz_rounded),
                                    onPressed: () => _deleteProduct(product),
                                  ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _ProductTag(
                                        icon: Icons.sell_outlined,
                                        label: _rupiahFormat.format(sellingPrice),
                                        foreground: ownerBlue,
                                      ),
                                      _ProductTag(
                                        icon: Icons.shopping_bag_outlined,
                                        label: 'Modal ${_rupiahFormat.format(purchasePrice)}',
                                        foreground: ownerMuted,
                                      ),
                                      _ProductTag(
                                        icon: Icons.inventory_2_outlined,
                                        label: '$stock tersedia',
                                        foreground: stock <= minStock
                                            ? const Color(0xFFB42318)
                                            : const Color(0xFF18794E),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ProductTag extends StatelessWidget {
  const _ProductTag({required this.icon, required this.label, required this.foreground});

  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

