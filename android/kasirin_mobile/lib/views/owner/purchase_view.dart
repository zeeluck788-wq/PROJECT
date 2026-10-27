import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import 'owner_widgets.dart';

class PurchaseView extends ConsumerStatefulWidget {
  const PurchaseView({
    this.openNewOrderOnLoad = false,
    this.initialTab = 0,
    super.key,
  });

  final bool openNewOrderOnLoad;
  final int initialTab;

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
    if (widget.initialTab >= 0 && widget.initialTab <= 2) {
      _tab = widget.initialTab;
    }
    _loadData(openNewOrder: widget.openNewOrderOnLoad);
  }

  Future<void> _loadData({bool openNewOrder = false}) async {
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
    if (openNewOrder && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _createOrder();
      });
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
    final draft = await showDialog<_PurchaseDraft>(
      context: context,
      builder: (_) => _PurchaseDialog(
        suppliers: _suppliers,
        products: _products,
        currency: _currency,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      final auth = ref.read(authNotifierProvider);
      final actorId = auth.userId;
      if (actorId == null) throw StateError('Sesi pengguna sudah berakhir.');
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.completePurchase(
        supplierId: draft.supplierId,
        newSupplierName: draft.newSupplierName,
        productId: draft.productId,
        newProductName: draft.newProductName,
        newProductSellingPrice: draft.newProductSellingPrice,
        newProductMinimumStock: draft.newProductMinimumStock,
        quantity: draft.quantity,
        unitCost: draft.unitCost,
        actorId: actorId,
        paymentType: draft.paymentType,
        downPaymentAmount: draft.downPaymentAmount,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembelian berhasil disimpan dan stok diperbarui.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat menyimpan pembelian: $error')),
        );
      }
    }
  }

  Future<void> _editSupplier(QueryRow supplier) async {
    final details = await showDialog<_SupplierDraft>(
      context: context,
      builder: (_) => _SupplierEditDialog(supplier: supplier),
    );
    if (details == null || !mounted) return;
    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.updateSupplier(
        supplierId: supplier.read<int>('id'),
        name: details.name,
        phone: details.phone,
        address: details.address,
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah supplier: $error')),
        );
      }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menerima stok: $error')));
      }
    }
  }

  Future<void> _payOrder(QueryRow order) async {
    final amountController = TextEditingController(
      text: (order.read<int>('subtotal') - order.read<int>('paid_amount'))
          .toString(),
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
      final amount = int.tryParse(
        amountController.text.replaceAll('.', '').trim(),
      );
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
        title: onlyOutstanding
            ? 'Tidak ada tagihan terbuka'
            : 'Belum ada pesanan',
        message: onlyOutstanding ? 'Tagihan supplier akan muncul di sini.' : 'Buat pesanan pembelian untuk mencatat barang yang akan diterima.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF1F6)),
          columns: const [
            DataColumn(label: Text('No. Pesanan')),
            DataColumn(label: Text('Supplier')),
            DataColumn(label: Text('Barang')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Total'), numeric: true),
            DataColumn(label: Text('Terbayar'), numeric: true),
            DataColumn(label: Text('Sisa'), numeric: true),
            DataColumn(label: Text('Aksi')),
          ],
          rows: orders.map((order) {
            final isDraft = order.read<String>('status') == 'DRAFT';
            final subtotal = order.read<int>('subtotal');
            final paid = order.read<int>('paid_amount');
            final outstanding = subtotal - paid;
            return DataRow(
              cells: [
                DataCell(Text(order.read<String>('order_no'))),
                DataCell(Text(order.read<String>('supplier_name'))),
                DataCell(
                  SizedBox(
                    width: 190,
                    child: Text(
                      order.read<String?>('item_summary') ?? 'Produk',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  _StatusChip(
                    label: isDraft ? 'Menunggu barang' : 'Diterima',
                    color: isDraft
                        ? const Color(0xFFB7791F)
                        : const Color(0xFF18794E),
                  ),
                ),
                DataCell(Text(_currency.format(subtotal))),
                DataCell(Text(_currency.format(paid))),
                DataCell(
                  Text(
                    _currency.format(outstanding),
                    style: TextStyle(
                      color: outstanding == 0
                          ? const Color(0xFF18794E)
                          : const Color(0xFFB7791F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DataCell(
                  Wrap(
                    spacing: 4,
                    children: [
                      if (isDraft)
                        IconButton(
                          tooltip: 'Terima stok',
                          icon: const Icon(Icons.inventory_2_outlined),
                          onPressed: () => _receiveOrder(order),
                        ),
                      if (!isDraft && outstanding > 0)
                        IconButton(
                          tooltip: 'Catat pembayaran',
                          icon: const Icon(Icons.payments_outlined),
                          onPressed: () => _payOrder(order),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSuppliers() {
    if (_suppliers.isEmpty) {
      return OwnerEmptyState(
        icon: Icons.business_outlined,
        title: 'Belum ada supplier',
        message:
            'Simpan data pemasok untuk menggunakannya pada pesanan pembelian.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFEAF1F6)),
          columns: const [
            DataColumn(label: Text('Kode')),
            DataColumn(label: Text('Nama supplier')),
            DataColumn(label: Text('Telepon')),
            DataColumn(label: Text('Alamat')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: _suppliers
              .map(
                (supplier) => DataRow(
                  cells: [
                    DataCell(Text(supplier.read<String>('code'))),
                    DataCell(Text(supplier.read<String>('name'))),
                    DataCell(Text(supplier.read<String?>('phone') ?? '-')),
                    DataCell(
                      SizedBox(
                        width: 240,
                        child: Text(
                          supplier.read<String?>('address') ?? '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      TextButton.icon(
                        onPressed: () => _editSupplier(supplier),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Supplier'),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OwnerScaffold(
      title: 'Pembelian & Supplier',
      onBack: () => context.go('/'),
      onAdd: _tab == 0
          ? _createOrder
          : _tab == 1
          ? _addSupplier
          : null,
      addLabel: _tab == 1 ? 'Tambah supplier' : 'Buat pesanan',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: OwnerTabBar<int>(
              tabs: const [(0, 'Pesanan'), (1, 'Supplier'), (2, 'Tagihan')],
              selected: _tab,
              onSelected: (selection) => setState(() => _tab = selection),
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

typedef _PurchaseDraft = ({
  int? supplierId,
  String? newSupplierName,
  int? productId,
  String? newProductName,
  int? newProductSellingPrice,
  int newProductMinimumStock,
  int quantity,
  int unitCost,
  String paymentType,
  int downPaymentAmount,
});

typedef _SupplierDraft = ({String name, String? phone, String? address});

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({
    required this.suppliers,
    required this.products,
    required this.currency,
  });

  final List<QueryRow> suppliers;
  final List<QueryRow> products;
  final NumberFormat currency;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  static const _newSupplier = -1;
  static const _newProduct = -1;

  late int _supplierSelection;
  late int _productSelection;
  late final TextEditingController _newSupplierNameController;
  late final TextEditingController _newProductNameController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitCostController;
  late final TextEditingController _downPaymentController;
  String _paymentType = 'CASH';
  String? _errorMessage;

  bool get _isNewSupplier => _supplierSelection == _newSupplier;
  bool get _isNewProduct => _productSelection == _newProduct;

  List<QueryRow> get _availableProducts {
    if (_isNewSupplier) return [];
    return widget.products.where((product) {
      final supplierId = product.read<int?>('supplier_id');
      return supplierId == null || supplierId == _supplierSelection;
    }).toList();
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;
  int get _unitCost => _parseMoney(_unitCostController.text);
  int get _total => _quantity * _unitCost;
  int get _downPayment => _parseMoney(_downPaymentController.text);

  int _parseMoney(String value) =>
      int.tryParse(value.replaceAll('.', '').replaceAll(' ', '').trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _supplierSelection = widget.suppliers.isEmpty
        ? _newSupplier
        : widget.suppliers.first.read<int>('id');
    final initialProducts = _availableProducts;
    _productSelection = initialProducts.isEmpty
        ? _newProduct
        : initialProducts.first.read<int>('id');
    _newSupplierNameController = TextEditingController();
    _newProductNameController = TextEditingController();
    _sellingPriceController = TextEditingController();
    _minimumStockController = TextEditingController(text: '5');
    _quantityController = TextEditingController(text: '1');
    _unitCostController = TextEditingController(
      text: initialProducts.isEmpty
          ? ''
          : '${initialProducts.first.read<int>('purchase_price')}',
    );
    _downPaymentController = TextEditingController();
  }

  @override
  void dispose() {
    _newSupplierNameController.dispose();
    _newProductNameController.dispose();
    _sellingPriceController.dispose();
    _minimumStockController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    _downPaymentController.dispose();
    super.dispose();
  }

  void _selectSupplier(int supplierId) {
    setState(() {
      _supplierSelection = supplierId;
      final products = _availableProducts;
      _productSelection = products.isEmpty
          ? _newProduct
          : products.first.read<int>('id');
      _unitCostController.text = products.isEmpty
          ? ''
          : '${products.first.read<int>('purchase_price')}';
      _errorMessage = null;
    });
  }

  void _selectProduct(int productId) {
    setState(() {
      _productSelection = productId;
      if (productId != _newProduct) {
        final product = _availableProducts.firstWhere(
          (row) => row.read<int>('id') == productId,
        );
        _unitCostController.text = '${product.read<int>('purchase_price')}';
      } else {
        _unitCostController.clear();
      }
      _errorMessage = null;
    });
  }

  void _submit() {
    final quantity = _quantity;
    final unitCost = _unitCost;
    final total = quantity * unitCost;
    final sellingPrice = _parseMoney(_sellingPriceController.text);
    final minimumStock = int.tryParse(_minimumStockController.text.trim()) ?? 0;
    String? error;

    if (_isNewSupplier && _newSupplierNameController.text.trim().isEmpty) {
      error = 'Nama supplier baru wajib diisi.';
    } else if (_isNewProduct && _newProductNameController.text.trim().isEmpty) {
      error = 'Nama produk baru wajib diisi.';
    } else if (_isNewProduct && sellingPrice <= 0) {
      error = 'Harga jual produk baru harus lebih dari 0.';
    } else if (quantity <= 0) {
      error = 'Jumlah pembelian minimal 1.';
    } else if (unitCost <= 0) {
      error = 'Harga modal per produk harus lebih dari 0.';
    } else if (minimumStock < 0) {
      error = 'Stok minimum tidak boleh negatif.';
    } else if (_paymentType == 'DP' &&
        (_downPayment <= 0 || _downPayment >= total)) {
      error = 'Nominal DP harus lebih dari 0 dan kurang dari total.';
    }

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    Navigator.pop<_PurchaseDraft>(context, (
      supplierId: _isNewSupplier ? null : _supplierSelection,
      newSupplierName: _isNewSupplier
          ? _newSupplierNameController.text.trim()
          : null,
      productId: _isNewProduct ? null : _productSelection,
      newProductName: _isNewProduct
          ? _newProductNameController.text.trim()
          : null,
      newProductSellingPrice: _isNewProduct ? sellingPrice : null,
      newProductMinimumStock: _isNewProduct ? minimumStock : 5,
      quantity: quantity,
      unitCost: unitCost,
      paymentType: _paymentType,
      downPaymentAmount: _paymentType == 'DP' ? _downPayment : 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final availableProducts = _availableProducts;

    return AlertDialog(
      title: const Text('Pembelian'),
      content: SizedBox(
        width: 460,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _supplierSelection,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    ...widget.suppliers.map(
                      (supplier) => DropdownMenuItem(
                        value: supplier.read<int>('id'),
                        child: Text(supplier.read<String>('name')),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: _newSupplier,
                      child: Text('Supplier Baru'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) _selectSupplier(value);
                  },
                ),
                if (_isNewSupplier) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newSupplierNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama supplier baru *',
                      helperText: 'Nomor WhatsApp dan alamat dapat dilengkapi di tab Supplier.',
                    ),
                    onChanged: (_) => setState(() => _errorMessage = null),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _productSelection,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Produk'),
                  items: [
                    ...availableProducts.map(
                      (product) => DropdownMenuItem(
                        value: product.read<int>('id'),
                        child: Text(
                          '${product.read<String>('name')} · ${product.read<String>('sku')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: _newProduct,
                      child: Text('Produk Baru'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) _selectProduct(value);
                  },
                ),
                if (_isNewProduct) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newProductNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama produk baru *',
                    ),
                    onChanged: (_) => setState(() => _errorMessage = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sellingPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga jual per pcs *',
                      prefixText: 'Rp ',
                    ),
                    onChanged: (_) => setState(() => _errorMessage = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _minimumStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok minimum',
                      suffixText: 'pcs',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah beli',
                          suffixText: 'pcs',
                        ),
                        onChanged: (_) => setState(() => _errorMessage = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _unitCostController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Modal / pcs',
                          prefixText: 'Rp ',
                        ),
                        onChanged: (_) => setState(() => _errorMessage = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentType,
                  decoration: const InputDecoration(labelText: 'Pembayaran'),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Tunai')),
                    DropdownMenuItem(value: 'TEMPO', child: Text('Tempo')),
                    DropdownMenuItem(value: 'DP', child: Text('DP')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _paymentType = value;
                        _errorMessage = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (_paymentType == 'DP') ...[
                  TextField(
                    controller: _downPaymentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal DP',
                      prefixText: 'Rp ',
                    ),
                    onChanged: (_) => setState(() => _errorMessage = null),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sisa pembayaran'),
                      Text(
                        widget.currency.format(
                          (_total - _downPayment).clamp(0, _total),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total pembelian'),
                    Text(
                      widget.currency.format(_total),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan Pembelian')),
      ],
    );
  }
}

class _SupplierEditDialog extends StatefulWidget {
  const _SupplierEditDialog({required this.supplier});

  final QueryRow supplier;

  @override
  State<_SupplierEditDialog> createState() => _SupplierEditDialogState();
}

class _SupplierEditDialogState extends State<_SupplierEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.supplier.read<String>('name'),
    );
    _phoneController = TextEditingController(
      text: widget.supplier.read<String?>('phone') ?? '',
    );
    _addressController = TextEditingController(
      text: widget.supplier.read<String?>('address') ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Nama supplier wajib diisi.');
      return;
    }
    Navigator.pop<_SupplierDraft>(context, (
      name: name,
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Supplier'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama supplier *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor WhatsApp'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Alamat'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
