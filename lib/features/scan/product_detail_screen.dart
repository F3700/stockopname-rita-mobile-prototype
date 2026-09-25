import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/product_repository.dart';
import '../../core/database/so_repository.dart';
import '../../core/error/app_error.dart';
import '../../core/ui/design_system/rita_band.dart';
import '../../core/ui/design_system/rita_buttons.dart';
import '../../core/ui/design_system/rita_card.dart';
import '../../core/ui/design_system/rita_pill.dart';
import '../../core/ui/design_system/rita_states.dart';
import '../../core/ui/design_system/rita_tokens.dart';
import '../../core/ui/rita_theme.dart';
import '../upload/upload_service.dart';
import 'rack_scan_screen.dart';

/// Detail produk (v5): info read-only + stepper qty → Simpan.
/// Dibuka dari tap list (edit/ganti) atau dari hasil scan baru (tambah).
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.rakId,
    required this.rakName,
    required this.productId,
    this.scannedProduct,
    this.scannedBarcode,
    this.mode = 'replace',
  });
  final int rakId;
  final String rakName;
  final int productId;

  /// Data master produk hasil scan (wajib bila item belum ada di rak).
  final Map<String, dynamic>? scannedProduct;

  /// Barcode yang benar-benar dipindai; null bila dibuka dari daftar item.
  /// Dipakai agar snapshot upload memakai kode yang di-scan, bukan barcode
  /// utama produk.
  final String? scannedBarcode;

  /// 'replace' = qty diinput jadi qty akhir, 'add' = qty diinput ditambahkan.
  final String mode;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
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
    final existing = await so.findByRakAndProduct(
      widget.rakId,
      widget.productId,
    );
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
        product = existing != null ? {...existing, ...?master} : master;
        loading = false;
      });
    }
  }

  void _step(int delta) {
    final current = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    final next = current + delta;
    if (next < 1) return;
    qtyCtrl.text = '$next';
    setState(() => info = null);
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
      await ref
          .read(soRepositoryProvider)
          .upsertScan(
            rakId: widget.rakId,
            rakName: widget.rakName,
            productId: widget.productId,
            plu: (p['plu'] as String?) ?? '',
            barcode: widget.scannedBarcode ?? (p['barcode'] as String? ?? ''),
            productName: (p['product_name'] ?? p['name']) as String,
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
    final p = product;
    return Scaffold(
      appBar: RitaBand(
        title: 'Detail produk',
        subtitle: 'Rak ${widget.rakName} - hasil pindaian',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: loading
          ? const RitaLoading(label: 'Memuat produk...')
          : p == null
          ? const Center(child: Text('Produk tidak ditemukan.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                RitaSpace.screen,
                RitaSpace.md,
                RitaSpace.screen,
                100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldCard(
                    label: 'BARCODE',
                    value: '${p['barcode'] ?? '-'}',
                    tag: true,
                  ),
                  const SizedBox(height: RitaSpace.sm),
                  _FieldCard(
                    label: 'NAMA PRODUK',
                    value: '${p['product_name'] ?? p['name']}',
                    tag: true,
                  ),
                  const SizedBox(height: RitaSpace.sm),
                  _FieldCard(
                    label: 'PLU / DEPARTEMEN',
                    value:
                        '${p['plu'] ?? '-'} · ${p['department_code'] ?? '-'}',
                  ),
                  const SizedBox(height: RitaSpace.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _FieldCard(
                          label: 'HARGA BELI',
                          value: rupiah(_num(p['buy_price'])),
                          valueStyle: RitaType.title,
                        ),
                      ),
                      const SizedBox(width: RitaSpace.sm),
                      Expanded(
                        child: _FieldCard(
                          label: 'HARGA JUAL',
                          value: rupiah(_num(p['sell_price'])),
                          valueStyle: RitaType.title,
                        ),
                      ),
                    ],
                  ),
                  if (widget.mode == 'add' && currentQty != null) ...[
                    const SizedBox(height: RitaSpace.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: RitaSpace.md,
                        vertical: RitaSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: RitaPalette.warningBg,
                        borderRadius: BorderRadius.circular(RitaRadius.md),
                      ),
                      child: Text(
                        'Tercatat $currentQty pcs - input di bawah ditambahkan.',
                        style: RitaType.caption.copyWith(
                          color: RitaPalette.warningText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: RitaSpace.md),
                  Text('BANYAK BARANG (PCS)', style: RitaType.fieldLabel),
                  const SizedBox(height: 6),
                  _QtyStepper(
                    controller: qtyCtrl,
                    onStep: _step,
                    onChanged: () => setState(() => info = null),
                  ),
                  if (info != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      info!,
                      style: RitaType.caption.copyWith(
                        color: RitaPalette.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RitaSpace.screen),
          child: RitaPrimaryButton(
            label: 'SIMPAN JUMLAH',
            loading: saving,
            onPressed: saving || loading ? null : _save,
          ),
        ),
      ),
    );
  }

  num _num(Object? v) => v is num ? v : 0;
}

/// Kartu field read-only v5: label 12/700 + nilai 16, tag opsional.
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.value,
    this.tag = false,
    this.valueStyle,
  });

  final String label;
  final String value;
  final bool tag;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return RitaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: RitaType.fieldLabel)),
              if (tag)
                RitaPill.tag(
                  'HASIL SCAN',
                  bg: RitaPalette.successBg,
                  fg: RitaPalette.successText,
                  border: null,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: valueStyle ?? RitaType.body),
        ],
      ),
    );
  }
}

/// Stepper qty v5: tombol − (outline) / field 224 dengan focus ring / + (merah).
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.controller,
    required this.onStep,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<int> onStep;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepButton(
          icon: Icons.remove,
          color: RitaPalette.primary,
          background: RitaPalette.white,
          border: RitaPalette.border,
          onPressed: () => onStep(-1),
          tooltip: 'Kurangi',
        ),
        const SizedBox(width: RitaSpace.xs),
        Expanded(
          child: SizedBox(
            height: RitaSizes.field,
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              keyboardType: TextInputType.number,
              style: RitaType.body,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: RitaSpace.md,
                ),
                filled: true,
                fillColor: RitaPalette.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RitaRadius.md),
                  borderSide: const BorderSide(color: RitaPalette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RitaRadius.md),
                  borderSide: const BorderSide(
                    color: RitaPalette.focus,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: RitaSpace.xs),
        _StepButton(
          icon: Icons.add,
          color: Colors.white,
          background: RitaPalette.primary,
          onPressed: () => onStep(1),
          tooltip: 'Tambah',
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onPressed,
    this.border,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final Color? border;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: RitaSizes.iconTarget,
      height: RitaSizes.iconTarget,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border!),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: RitaSizes.iconGlyph,
        icon: Icon(icon, color: color),
      ),
    );
  }
}
