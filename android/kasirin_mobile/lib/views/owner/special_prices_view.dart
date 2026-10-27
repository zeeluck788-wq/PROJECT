import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import 'owner_widgets.dart';

class SpecialPricesView extends ConsumerStatefulWidget {
  const SpecialPricesView({super.key});

  @override
  ConsumerState<SpecialPricesView> createState() => _SpecialPricesViewState();
}

class _SpecialPricesViewState extends ConsumerState<SpecialPricesView> {
  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  List<QueryRow> _rules = [];
  List<QueryRow> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      final values = await Future.wait([
        repository.getSpecialPriceRules(),
        repository.products(),
      ]);
      if (mounted) {
        setState(() {
          _rules = values[0];
          _products = values[1];
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat harga spesial: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editRule({QueryRow? rule}) async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan produk terlebih dahulu.')),
      );
      return;
    }

    final quantityController = TextEditingController(
      text: rule?.read<int>('quantity_threshold').toString() ?? '12',
    );
    final priceController = TextEditingController(
      text: rule?.read<int>('special_price').toString() ?? '',
    );
    var selectedProductId = rule?.read<int>('product_id') ??
        _products.first.read<int>('id');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(rule == null ? 'Tambah harga spesial' : 'Ubah harga spesial'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedProductId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Produk'),
                  items: _products.map((product) {
                    final id = product.read<int>('id');
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        '${product.read<String>('name')} · ${product.read<String>('sku')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedProductId = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah minimum',
                    suffixText: 'pcs',
                    helperText: 'Harga berlaku mulai jumlah ini.',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga spesial per pcs',
                    prefixText: 'Rp ',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      quantityController.dispose();
      priceController.dispose();
      return;
    }
    final quantity = int.tryParse(quantityController.text.trim());
    final price = int.tryParse(priceController.text.replaceAll('.', '').trim());
    try {
      if (quantity == null || price == null) {
        throw StateError('Jumlah dan harga harus diisi dengan angka.');
      }
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.saveSpecialPriceRule(
        ruleId: rule?.read<int>('id'),
        productId: selectedProductId,
        quantityThreshold: quantity,
        specialPrice: price,
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat menyimpan: $error')),
        );
      }
    } finally {
      quantityController.dispose();
      priceController.dispose();
    }
  }

  Future<void> _deleteRule(QueryRow rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus harga spesial?'),
        content: Text(
          'Aturan untuk ${rule.read<String>('product_name')} mulai ${rule.read<int>('quantity_threshold')} pcs akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.deleteSpecialPriceRule(rule.read<int>('id'));
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus aturan: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OwnerScaffold(
      title: 'Harga Spesial',
      onBack: () => context.go('/'),
      actions: [
        IconButton(
          tooltip: 'Tambah aturan',
          onPressed: () => _editRule(),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const OwnerSectionHeading(
                  title: 'Atur harga berdasarkan jumlah',
                  subtitle: 'Tetapkan harga per unit yang lebih hemat untuk pembelian dalam jumlah tertentu.',
                ),
                const SizedBox(height: 18),
                OwnerSurface(
                  padding: EdgeInsets.zero,
                  child: _rules.isEmpty
                      ? OwnerEmptyState(
                          icon: Icons.sell_outlined,
                          title: 'Belum ada harga spesial',
                          message: 'Buat aturan pertama, misalnya harga khusus mulai pembelian 12 pcs.',
                          action: FilledButton.icon(
                            onPressed: () => _editRule(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Tambah aturan'),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 54,
                            dataRowMinHeight: 62,
                            dataRowMaxHeight: 72,
                            columns: const [
                              DataColumn(label: Text('PRODUK')),
                              DataColumn(label: Text('MINIMUM QTY'), numeric: true),
                              DataColumn(label: Text('HARGA / PCS'), numeric: true),
                              DataColumn(label: Text('HARGA NORMAL'), numeric: true),
                              DataColumn(label: Text('AKSI')),
                            ],
                            rows: _rules.map((rule) {
                              final specialPrice = rule.read<int>('special_price');
                              final regularPrice = rule.read<int>('regular_price');
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 190,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rule.read<String>('product_name'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          Text(
                                            rule.read<String>('product_sku'),
                                            style: const TextStyle(color: ownerMuted, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${rule.read<int>('quantity_threshold')} pcs ke atas')),
                                  DataCell(Text(
                                    _currency.format(specialPrice),
                                    style: const TextStyle(color: Color(0xFF18794E), fontWeight: FontWeight.w700),
                                  )),
                                  DataCell(Text(
                                    _currency.format(regularPrice),
                                    style: const TextStyle(color: ownerMuted),
                                  )),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        onPressed: () => _editRule(rule: rule),
                                        icon: const Icon(Icons.edit_outlined, size: 19),
                                      ),
                                      IconButton(
                                        tooltip: 'Hapus',
                                        onPressed: () => _deleteRule(rule),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 19),
                                      ),
                                    ],
                                  )),
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
}
