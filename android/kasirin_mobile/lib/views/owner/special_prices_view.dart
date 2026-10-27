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

    final draft = await showDialog<_SpecialPriceDraft>(
      context: context,
      builder: (_) => _SpecialPriceRuleDialog(
        products: _products,
        rule: rule,
        currency: _currency,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      final repository = await ref.read(repositoryFutureProvider.future);
      await repository.saveSpecialPriceRule(
        ruleId: rule?.read<int>('id'),
        productId: draft.productId,
        quantityThreshold: draft.minimumQuantity,
        specialPrice: draft.minimumPrice,
        multipleQuantityThreshold: draft.multipleQuantityThreshold,
        multipleSpecialPrice: draft.multiplePrice,
      );
      await _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat menyimpan: $error')),
        );
      }
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
      onAdd: () => _editRule(),
      addLabel: 'Tambah harga',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                const OwnerSectionHeading(
                  title: 'Harga dasar dan harga bertingkat',
                  subtitle: 'Atur harga normal, harga mulai jumlah minimum, serta harga untuk kelipatan jumlah tersebut.',
                ),
                const SizedBox(height: 18),
                OwnerSurface(
                  padding: EdgeInsets.zero,
                  child: _rules.isEmpty
                      ? OwnerEmptyState(
                          icon: Icons.sell_outlined,
                          title: 'Belum ada harga spesial',
                          message: 'Tambahkan harga spesial berdasarkan jumlah minimum dan kelipatannya.',
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 54,
                            dataRowMinHeight: 62,
                            dataRowMaxHeight: 72,
                            columns: const [
                              DataColumn(label: Text('PRODUK')),
                              DataColumn(
                                label: Text('HARGA DASAR'),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('QTY TINGKAT 2'),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('HARGA TINGKAT 2'),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('DISKON TINGKAT 2'),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('QTY TINGKAT 3'),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('HARGA TINGKAT 3'),
                                numeric: true,
                              ),
                              DataColumn(label: Text('AKSI')),
                            ],
                            rows: _rules.map((rule) {
                              final specialPrice = rule.read<int>(
                                'special_price',
                              );
                              final regularPrice = rule.read<int>(
                                'regular_price',
                              );
                              final multipleQuantity = rule.read<int>(
                                'multiple_quantity_threshold',
                              );
                              final multiplePrice = rule.read<int>(
                                'multiple_special_price',
                              );
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 190,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rule.read<String>('product_name'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            rule.read<String>('product_sku'),
                                            style: const TextStyle(
                                              color: ownerMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(_currency.format(regularPrice)),
                                  ),
                                  DataCell(
                                    Text(
                                      '${rule.read<int>('quantity_threshold')} pcs ke atas',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _currency.format(specialPrice),
                                      style: const TextStyle(
                                        color: Color(0xFF18794E),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${_discountText(regularPrice, specialPrice)}%',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      multiplePrice > 0
                                          ? '$multipleQuantity pcs'
                                          : '—',
                                    ),
                                  ),
                                  DataCell(
                                    multiplePrice > 0
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _currency.format(multiplePrice),
                                                style: const TextStyle(
                                                  color: Color(0xFF18794E),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                'Diskon ${_discountText(regularPrice, multiplePrice)}%',
                                                style: const TextStyle(
                                                  color: ownerMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Text('—'),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit',
                                          onPressed: () =>
                                              _editRule(rule: rule),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 19,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Hapus',
                                          onPressed: () => _deleteRule(rule),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 19,
                                          ),
                                        ),
                                      ],
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
}

typedef _SpecialPriceDraft = ({
  int productId,
  int minimumQuantity,
  int multipleQuantityThreshold,
  int minimumPrice,
  int multiplePrice,
});

class _SpecialPriceRuleDialog extends StatefulWidget {
  const _SpecialPriceRuleDialog({
    required this.products,
    required this.currency,
    this.rule,
  });

  final List<QueryRow> products;
  final QueryRow? rule;
  final NumberFormat currency;

  @override
  State<_SpecialPriceRuleDialog> createState() =>
      _SpecialPriceRuleDialogState();
}

class _SpecialPriceRuleDialogState extends State<_SpecialPriceRuleDialog> {
  late int _selectedProductId;
  late final TextEditingController _minimumQuantityController;
  late final TextEditingController _multipleQuantityController;
  late final TextEditingController _minimumPriceController;
  late final TextEditingController _minimumPercentController;
  late final TextEditingController _multiplePriceController;
  late final TextEditingController _multiplePercentController;
  String? _validationMessage;

  QueryRow get _selectedProduct => widget.products.firstWhere(
    (product) => product.read<int>('id') == _selectedProductId,
  );

  int get _basePrice => _selectedProduct.read<int>('selling_price');

  @override
  void initState() {
    super.initState();
    final productIds = widget.products.map((p) => p.read<int>('id')).toSet();
    final ruleProductId = widget.rule?.read<int>('product_id');
    _selectedProductId =
        ruleProductId != null && productIds.contains(ruleProductId)
        ? ruleProductId
        : widget.products.first.read<int>('id');

    final minimumPrice = widget.rule?.read<int>('special_price');
    final multiplePrice = widget.rule?.read<int>('multiple_special_price') ?? 0;
    final multipleQuantity =
        widget.rule?.read<int>('multiple_quantity_threshold') ?? 0;
    _minimumQuantityController = TextEditingController(
      text: '${widget.rule?.read<int>('quantity_threshold') ?? 12}',
    );
    _multipleQuantityController = TextEditingController(
      text: multiplePrice > 0 ? '$multipleQuantity' : '',
    );
    _minimumPriceController = TextEditingController(
      text: minimumPrice == null ? '' : '$minimumPrice',
    );
    _minimumPercentController = TextEditingController(
      text: minimumPrice == null ? '' : _percentFor(minimumPrice),
    );
    _multiplePriceController = TextEditingController(
      text: multiplePrice > 0 ? '$multiplePrice' : '',
    );
    _multiplePercentController = TextEditingController(
      text: multiplePrice > 0 ? _percentFor(multiplePrice) : '',
    );
  }

  @override
  void dispose() {
    _minimumQuantityController.dispose();
    _multipleQuantityController.dispose();
    _minimumPriceController.dispose();
    _minimumPercentController.dispose();
    _multiplePriceController.dispose();
    _multiplePercentController.dispose();
    super.dispose();
  }

  String _percentFor(int price) {
    if (_basePrice <= 0) return '0';
    final percent = ((_basePrice - price) * 100 / _basePrice);
    return _trimDecimal(percent.toStringAsFixed(2));
  }

  String _trimDecimal(String value) =>
      value.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  int? _parsePrice(String value) =>
      int.tryParse(value.replaceAll('.', '').replaceAll(' ', '').trim());

  double? _parsePercent(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _changeProduct(int productId) {
    setState(() {
      _selectedProductId = productId;
      final minimumPrice = _parsePrice(_minimumPriceController.text);
      final multiplePrice = _parsePrice(_multiplePriceController.text);
      _minimumPercentController.text = minimumPrice == null
          ? ''
          : _percentFor(minimumPrice);
      _multiplePercentController.text = multiplePrice == null
          ? ''
          : _percentFor(multiplePrice);
    });
  }

  void _updatePercentFromPrice(
    TextEditingController percentController,
    String value,
  ) {
    setState(() {
      final price = _parsePrice(value);
      percentController.text = price == null ? '' : _percentFor(price);
      _validationMessage = null;
    });
  }

  void _updatePriceFromPercent(
    TextEditingController priceController,
    String value,
  ) {
    setState(() {
      final percent = _parsePercent(value);
      if (percent != null && percent >= 0 && percent < 100) {
        priceController.text = (_basePrice * (100 - percent) / 100)
            .round()
            .toString();
      } else if (value.trim().isEmpty) {
        priceController.clear();
      }
      _validationMessage = null;
    });
  }

  void _submit() {
    final minimumQuantity =
        int.tryParse(_minimumQuantityController.text.trim()) ?? 0;
    final multipleQuantity =
        int.tryParse(_multipleQuantityController.text.trim()) ?? 0;
    final minimumPrice = _parsePrice(_minimumPriceController.text) ?? 0;
    final multiplePriceText = _multiplePriceController.text.trim();
    final multiplePrice = _parsePrice(multiplePriceText) ?? 0;

    String? error;
    if (minimumQuantity < 1) {
      error = 'Jumlah minimum harus minimal 1.';
    } else if (multipleQuantity <= minimumQuantity) {
      error =
          'Jumlah tingkat harga ketiga harus lebih besar dari tingkat kedua.';
    } else if (minimumPrice <= 0 || minimumPrice > _basePrice) {
      error =
          'Harga minimum harus lebih dari 0 dan tidak melebihi harga dasar.';
    } else if (multiplePrice <= 0 || multiplePrice > _basePrice) {
      error =
          'Harga kelipatan harus lebih dari 0 dan tidak melebihi harga dasar.';
    }

    if (error != null) {
      setState(() => _validationMessage = error);
      return;
    }

    Navigator.pop<_SpecialPriceDraft>(context, (
      productId: _selectedProductId,
      minimumQuantity: minimumQuantity,
      multipleQuantityThreshold: multipleQuantity,
      minimumPrice: minimumPrice,
      multiplePrice: multiplePrice,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final minimumQuantity =
        int.tryParse(_minimumQuantityController.text.trim()) ?? 0;
    final multipleThreshold =
        int.tryParse(_multipleQuantityController.text.trim()) ?? 0;

    return AlertDialog(
      title: Text(
        widget.rule == null ? 'Tambah harga spesial' : 'Ubah harga spesial',
      ),
      content: SizedBox(
        width: 460,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .62,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedProductId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Produk'),
                  items: widget.products.map((product) {
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
                    if (value != null) _changeProduct(value);
                  },
                ),
                const SizedBox(height: 14),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Harga dasar / harga normal',
                  ),
                  child: Text(
                    widget.currency.format(_basePrice),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minimumQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah tingkat harga 2',
                          suffixText: 'pcs',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _multipleQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah tingkat harga 3',
                          suffixText: 'pcs',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    multipleThreshold > 0
                        ? 'Harga normal di bawah $minimumQuantity pcs · tingkat 2 mulai $minimumQuantity pcs · tingkat 3 mulai $multipleThreshold pcs.'
                        : 'Isi jumlah tingkat harga 2 dan 3.',
                    style: const TextStyle(color: ownerMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _minimumPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga tingkat 2 per pcs',
                    prefixText: 'Rp ',
                  ),
                  onChanged: (value) =>
                      _updatePercentFromPrice(_minimumPercentController, value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _minimumPercentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Diskon dari harga dasar',
                    suffixText: '%',
                  ),
                  onChanged: (value) =>
                      _updatePriceFromPercent(_minimumPriceController, value),
                ),
                const SizedBox(height: 18),
                const Divider(),
                Text(
                  'Harga tingkat 3 mulai $multipleThreshold pcs',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _multiplePriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga tingkat 3 per pcs',
                    prefixText: 'Rp ',
                  ),
                  onChanged: (value) => _updatePercentFromPrice(
                    _multiplePercentController,
                    value,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _multiplePercentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Diskon tingkat 3 dari harga dasar',
                    suffixText: '%',
                  ),
                  onChanged: (value) =>
                      _updatePriceFromPercent(_multiplePriceController, value),
                ),
                if (_validationMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _validationMessage!,
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
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

String _discountText(int basePrice, int specialPrice) {
  if (basePrice <= 0) return '0';
  final percent = ((basePrice - specialPrice) * 100 / basePrice);
  return percent
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
