import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import 'owner_widgets.dart';

class PurchaseView extends ConsumerStatefulWidget {
  const PurchaseView({super.key});

  @override
  ConsumerState<PurchaseView> createState() => _PurchaseViewState();
}

class _PurchaseViewState extends ConsumerState<PurchaseView> {
  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  List<QueryRow> _orders = [];
  List<QueryRow> _suppliers = [];
  List<QueryRow> _products = [];
  bool _isLoading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      final orders = await repository.getPurchaseOrders();
      final suppliers = await repository.getSuppliers();
      final products = await repository.products();
      if (mounted) {
        setState(() {
          _orders = orders;
          _suppliers = suppliers;
          _products = products;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data pembelian: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSupplier() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama supplier *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor telepon'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Alamat'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) {
      nameController.dispose();
      phoneController.dispose();
      addressController.dispose();
      return;
    }
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.createSupplier(
        name: nameController.text,
        phone: phoneController.text,
        address: addressController.text,
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat menyimpan supplier: $error')),
        );
      }
    } finally {
      nameController.dispose();
      phoneController.dispose();
      addressController.dispose();
    }
  }

  Future<void> _createOrder() async {
    if (_suppliers.isEmpty) {
      await _addSupplier();
      if (_suppliers.isEmpty) return;
    }
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan produk terlebih dahulu.')),
      );
      return;
    }

    final quantityController = TextEditingController(text: '1');
    final costController = TextEditingController(
      text: _products.first.read<int>('purchase_price').toString(),
    );
    final noteController = TextEditingController();
    var supplierId = _suppliers.first.read<int>('id');
    var productId = _products.first.read<int>('id');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pesanan pembelian baru'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: supplierId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Supplier'),
                    items: _suppliers.map((supplier) {
                      final id = supplier.read<int>('id');
                      return DropdownMenuItem(
                        value: id,
                        child: Text(supplier.read<String>('name')),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => supplierId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: productId,
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
                        setDialogState(() => productId = value);
                        final product = _products.firstWhere(
                          (row) => row.read<int>('id') == value,
                        );
                        costController.text =
                            product.read<int>('purchase_price').toString();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah',
                            suffixText: 'pcs',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: costController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Modal / pcs',
                            prefixText: 'Rp ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Catatan'),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pembayaran dicatat sebagai tempo 30 hari. Stok bertambah setelah pesanan diterima.',
                      style: TextStyle(fontSize: 12, color: ownerMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Buat pesanan'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) {
      quantityController.dispose();
      costController.dispose();
      noteController.dispose();
      return;
    }
    try {
      final quantity = int.tryParse(quantityController.text.trim());
      final cost = int.tryParse(costController.text.replaceAll('.', '').trim());
      if (quantity == null || cost == null) {
        throw StateError('Jumlah dan harga modal harus berupa angka.');
      }
      final auth = ref.read(authNotifierProvider);
      final actorId = auth.userId;
      if (actorId == null) throw StateError('Sesi pengguna sudah berakhir.');
      final dueDate = DateTime.now()
          .toUtc()
          .add(const Duration(days: 30))
          .toIso8601String()
          .substring(0, 10);
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.createPurchaseOrder(
        supplierId: supplierId,
        productId: productId,
        quantity: quantity,
        unitCost: cost,
        actorId: actorId,
        dueDate: dueDate,
        notes: noteController.text,
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuat pesanan: $error')),
        );
      }
    } finally {
      quantityController.dispose();
      costController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _receiveOrder(QueryRow order) async {
    final auth = ref.read(authNotifierProvider);
    try {
      final actorId = auth.userId;
      if (actorId == null) throw StateError('Sesi pengguna sudah berakhir.');
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.receivePurchaseOrder(
        orderId: order.read<int>('id'),
        actorId: actorId,
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menerima stok: $error')),
        );
      }
    }
  }

  Future<void> _payOrder(QueryRow order) async {
    final amountController = TextEditingController(
      text: (order.read<int>('subtotal') - order.read<int>('paid_amount')).toString(),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bayar supplier'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nominal pembayaran',
            prefixText: 'Rp ',
            helperText: 'Pembayaran dicatat melalui kas.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Catat pembayaran'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) {
      amountController.dispose();
      return;
    }
    try {
      final amount = int.tryParse(amountController.text.replaceAll('.', '').trim());
      if (amount == null) throw StateError('Masukkan nominal yang valid.');
      final actorId = ref.read(authNotifierProvider).userId;
      if (actorId == null) throw StateError('Sesi pengguna sudah berakhir.');
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.payPurchaseOrder(
        orderId: order.read<int>('id'),
        amount: amount,
        actorId: actorId,
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencatat pembayaran: $error')),
        );
      }
    } finally {
      amountController.dispose();
    }
  }

  Widget _buildOrders({required bool onlyOutstanding}) {
    final orders = _orders.where((order) {
      return !onlyOutstanding ||
          (order.read<String>('status') == 'RECEIVED' &&
              order.read<int>('paid_amount') < order.read<int>('subtotal'));
    }).toList();
    if (orders.isEmpty) {
      return OwnerEmptyState(
        icon: onlyOutstanding
            ? Icons.account_balance_wallet_outlined
            : Icons.local_shipping_outlined,
        title: onlyOutstanding ? 'Tidak ada tagihan terbuka' : 'Belum ada pesanan',
        message: onlyOutstanding
            ? 'Tagihan supplier akan muncul di sini.'
            : 'Buat pesanan pembelian untuk mencatat barang yang akan diterima.',
        action: onlyOutstanding
            ? null
            : FilledButton.icon(
                onPressed: _createOrder,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Buat pesanan'),
              ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = orders[index];
        final isDraft = order.read<String>('status') == 'DRAFT';
        final subtotal = order.read<int>('subtotal');
        final paid = order.read<int>('paid_amount');
        final outstanding = subtotal - paid;
        return OwnerSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.read<String>('supplier_name'),
                      style: const TextStyle(
                        color: ownerInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusChip(
                    label: isDraft ? 'Menunggu barang' : 'Diterima',
                    color: isDraft ? const Color(0xFFB7791F) : const Color(0xFF18794E),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${order.read<String>('order_no')} · ${order.read<String>('item_summary') ?? 'Produk'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ownerMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _OrderValue(label: 'Total pesanan', value: _currency.format(subtotal)),
                  _OrderValue(
                    label: outstanding == 0 ? 'Pembayaran' : 'Sisa tagihan',
                    value: outstanding == 0 ? 'Lunas' : _currency.format(outstanding),
                    valueColor: outstanding == 0 ? const Color(0xFF18794E) : const Color(0xFFB7791F),
                  ),
                ],
              ),
              if (isDraft || outstanding > 0) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (isDraft)
                      OutlinedButton.icon(
                        onPressed: () => _receiveOrder(order),
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: const Text('Terima stok'),
                      ),
                    if (!isDraft && outstanding > 0)
                      FilledButton.tonalIcon(
                        onPressed: () => _payOrder(order),
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('Catat pembayaran'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuppliers() {
    if (_suppliers.isEmpty) {
      return OwnerEmptyState(
        icon: Icons.business_outlined,
        title: 'Belum ada supplier',
        message: 'Simpan data pemasok untuk menggunakannya pada pesanan pembelian.',
        action: FilledButton.icon(
          onPressed: _addSupplier,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah supplier'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: _suppliers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final supplier = _suppliers[index];
        return OwnerSurface(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ownerBlue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.business_rounded, color: ownerBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier.read<String>('name'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      supplier.read<String?>('phone') ?? 'Nomor telepon belum diisi',
                      style: const TextStyle(color: ownerMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: ownerMuted),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OwnerScaffold(
      title: 'Pembelian & Supplier',
      onBack: () => context.go('/'),
      actions: [
        if (_tab == 0)
          IconButton(
            tooltip: 'Buat pesanan',
            onPressed: _createOrder,
            icon: const Icon(Icons.add_rounded),
          ),
        if (_tab == 1)
          IconButton(
            tooltip: 'Tambah supplier',
            onPressed: _addSupplier,
            icon: const Icon(Icons.person_add_alt_rounded),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Pesanan')),
                ButtonSegment(value: 1, label: Text('Supplier')),
                ButtonSegment(value: 2, label: Text('Tagihan')),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) =>
                  setState(() => _tab = selection.first),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tab == 1
                    ? _buildSuppliers()
                    : _buildOrders(onlyOutstanding: _tab == 2),
          ),
        ],
      ),
    );
  }
}

class _OrderValue extends StatelessWidget {
  const _OrderValue({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: ownerMuted, fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? ownerInk,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
}
