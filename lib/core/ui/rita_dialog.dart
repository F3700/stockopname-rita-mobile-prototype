import 'package:flutter/material.dart';

import 'design_system/rita_tokens.dart';

/// Guard global anti-tumpuk: hanya 1 dialog Rita yang boleh terbuka.
/// Dialog kedua yang diminta selagi ada dialog terbuka langsung diabaikan
/// (return null) kecuali [force] = true (untuk dialog blocking seperti sync).
bool _ritaDialogOpen = false;

/// Wrapper aman untuk semua pop-up Rita.
///
/// - Anti-menumpuk via [_ritaDialogOpen].
/// - Anti-overflow via `scrollable: true`, inset/padding longgar,
///   dan shape konsisten.
Future<T?> showRitaDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext ctx) builder,
  bool barrierDismissible = true,
  bool force = false,
  RouteSettings? routeSettings,
}) async {
  if (_ritaDialogOpen && !force) return null;
  final wasOpen = _ritaDialogOpen;
  _ritaDialogOpen = true;
  try {
    return await showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      routeSettings: routeSettings,
      builder: (ctx) => builder(ctx),
    );
  } finally {
    // Hanya reset bila kita yang mengunci; dialog `force` di atas dialog
    // biasa tidak boleh membuka kunci milik dialog bawah.
    if (!wasOpen) _ritaDialogOpen = false;
  }
}

/// AlertDialog standar Rita: scrollable + padding aman keyboard & layar kecil.
class RitaAlert extends StatelessWidget {
  const RitaAlert({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    // 3+ aksi (mis. Batal/Ganti/Tambah) dibungkus Wrap satu baris penuh
    // agar turun baris otomatis — AlertDialog menata `actions` secara
    // horizontal dan rawan RenderFlex overflow bila diisi banyak tombol.
    final effectiveActions = actions.length > 2
        ? [
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ),
          ]
        : actions;
    return AlertDialog(
      scrollable: true,
      clipBehavior: Clip.antiAlias,
      backgroundColor: RitaPalette.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: RitaType.cardTitle,
      contentTextStyle: RitaType.meta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RitaRadius.lg),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: RitaSpace.screen,
        vertical: RitaSpace.lg,
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: title,
      content: content,
      actions: effectiveActions,
    );
  }
}

/// Judul dialog dengan ikon + teks yang tidak overflow di layar sempit.
class RitaDialogTitle extends StatelessWidget {
  const RitaDialogTitle({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: RitaSizes.iconGlyph, color: RitaPalette.primary),
        const SizedBox(width: RitaSpace.xs),
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Baris aksi yang otomatis wrap (turun baris) di layar sempit,
/// menggantikan `Row` yang rawan `RenderFlex overflow`.
class RitaActions extends StatelessWidget {
  const RitaActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// Pop-up notifikasi error (mis. gagal masuk sesi): ikon error + pesan +
/// satu tombol OK. Pakai `force: true` agar selalu tampil meski ada guard.
Future<void> showRitaError({
  required BuildContext context,
  required String message,
  String title = 'Gagal',
  String okLabel = 'OK',
}) {
  return showRitaDialog<void>(
    context: context,
    force: true,
    builder: (ctx) => RitaAlert(
      title: RitaDialogTitle(icon: Icons.error_outline, text: title),
      content: Text(message),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(okLabel)),
      ],
    ),
  ).then((_) {});
}

/// Dialog konfirmasi sederhana (OK / Batal-Hapus / dsb) — pengganti
/// AlertDialog mentah di home/rack/sync agar konsisten & anti-overflow.
Future<bool?> showRitaConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Batal',
  String confirmLabel = 'OK',
  bool destructive = false,
  bool force = false,
}) {
  return showRitaDialog<bool>(
    context: context,
    force: force,
    builder: (ctx) => RitaAlert(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: RitaPalette.primary)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// Sembunyikan SnackBar yang sedang tampil agar pesan tidak antre menumpuk.
void hideStackedSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
}
