import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/product_repository.dart';
import '../../core/database/so_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/ui/rita_theme.dart';
import '../upload/upload_service.dart';
import 'rack_scan_screen.dart';

/// Detail produk ala Niko: info read-only + ubah qty → Simpan.
/// Dibuka dari tap list (edit/ganti) atau dari hasil scan baru (tambah).
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.rakId,
    required this.rakName,
    required this.productId,
    this.scannedProduct,
    this.mode = 'replace',
  });
  final int rakId;
  final String rakName;
  final int productId;

  /// Data master produk hasil scan (wajib bila item belum ada di rak).
  final Map<String, dynamic>? scannedProduct;

  /// 'replace' = qty diinput jadi qty akhir, 'add' = qty diinput ditambahkan.
  final String mode;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState
    extends ConsumerState<ProductDetailScreen> {
  final qtyCtrl = TextEditingController();
  Map<String, dynamic>? product;
  int? currentQty;
  bool isNew = false;
  bool loading = true;
  bool saving = false;
  String? info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(productRepositoryProvider);
    final so = ref.read(soRepositoryProvider);
    final existing =
        await so.findByRakAndProduct(widget.rakId, widget.productId);
    Map<String, dynamic>? master;
    if (existing != null) {
      master = await repo.findByBarcode(existing['barcode'] as String);
      currentQty = ((existing['quantity'] as num)).toInt();
      // Mode tambah: input dikosongkan untuk diisi jumlah tambahan.
      qtyCtrl.text = widget.mode == 'add' ? '' : '$currentQty';
    } else if (widget.scannedProduct != null) {
      // Produk baru dari hasil scan — qty default 1, Simpan = tambah.
      master = widget.scannedProduct;
      isNew = true;
      qtyCtrl.text = '1';
    }
    if (mounted) {
      setState(() {
        product = existing != null
            ? {...existing, ...?master}
            : master;
        loading = false;
      });
    }
  }

  Future<void> _save() async {
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => info = AppMessages.invalidQty);
      return;
    }
    final p = product;
    if (p == null) return;
    // Tambah hanya valid bila item sudah ada; produk baru selalu add.
    final mode = isNew ? 'add' : widget.mode;
    setState(() => saving = true);
    try {
      await ref.read(soRepositoryProvider).upsertScan(
            rakId: widget.rakId,
            rakName: widget.rakName,
            productId: widget.productId,
            barcode: p['barcode'] as String,
            productName:
                (p['product_name'] ?? p['name']) as String,
            quantity: qty,
            mode: mode,
          );
      ref.invalidate(rakItemsProvider(widget.rakId));
      ref.invalidate(pendingCountProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('DETAIL PRODUCT',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Informasi detail product',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : product == null
              ? const Center(
                  child: Text('Produk tidak ditemukan.'))
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.only(bottom: 50, left: 10, right: 10),
                  child: Column(
                    children: [
                      if (widget.mode == 'add' && currentQty != null)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Tercatat: $currentQty — input di bawah akan ditambahkan.',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      _ro('BARCODE', '${product!['barcode']}'),
                      _ro('NAMA PRODUK',
                          '${product!['product_name'] ?? product!['name']}'),
                      _ro('KODE DEPARTMENT',
                          '${product!['department_code'] ?? '-'}'),
                      _ro('KATEGORI',
                          '${product!['category_name'] ?? '-'}'),
                      Row(
                        children: [
                          Expanded(
                              child: _ro('HARGA BELI',
                                  rupiah(_num(product!['buy_price'])))),
                          Expanded(
                              child: _ro('HARGA JUAL',
                                  rupiah(_num(product!['sell_price'])))),
                        ],
                      ),
                      RitaInput(
                        controller: qtyCtrl,
                        title: 'Banyak Barang',
                        hint: 'contoh : 100',
                        maxLength: 12,
                        keyboardType: TextInputType.number,
                      ),
                      if (info != null)
                        Text(info!,
                            style:
                                const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: saving || loading ? null : _save,
            child: Text(saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ),
      ),
    );
  }

  num _num(Object? v) => v is num ? v : 0;

  Widget _ro(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: RitaColors.red),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF616161),
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
