/// DTO 1:1 dengan backend Go. Jangan tambah field di luar kontrak.
///
/// Kontrak master saat ini (lihat docs/apispec.json backend):
/// - ProductResponse: {id, plu, barcode (utama), barcodes[], name, buy_price,
///   sell_price, date_created, date_updated, department_code}
/// - DeletedProductResponse: {plu}
class ProductDto {
  const ProductDto({
    required this.id,
    required this.plu,
    required this.barcode,
    required this.barcodes,
    required this.name,
    required this.buyPrice,
    required this.sellPrice,
    required this.dateCreated,
    required this.dateUpdated,
    required this.departmentCode,
  });

  final int id;

  /// PLU = business key produk di sistem legacy.
  final String plu;

  /// Barcode utama (elemen pertama [barcodes]) — untuk tampilan saja.
  final String barcode;

  /// Semua barcode produk. Lookup offline memakai tabel product_barcodes.
  final List<String> barcodes;

  final String name;
  final double buyPrice;
  final double sellPrice;
  final DateTime dateCreated;
  final DateTime dateUpdated;
  final String departmentCode;

  factory ProductDto.fromJson(Map<String, dynamic> json) => ProductDto(
    id: (json['id'] as num).toInt(),
    plu: (json['plu'] as String?) ?? '',
    barcode: (json['barcode'] as String?) ?? '',
    barcodes: ((json['barcodes'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
    name: json['name'] as String,
    buyPrice: (json['buy_price'] as num).toDouble(),
    sellPrice: (json['sell_price'] as num).toDouble(),
    dateCreated: DateTime.parse(json['date_created'] as String),
    dateUpdated: DateTime.parse(json['date_updated'] as String),
    departmentCode: json['department_code'] as String,
  );

  Map<String, dynamic> toDbMap() => {
    'product_id': id,
    'plu': plu,
    'barcode': barcode,
    'name': name,
    'buy_price': buyPrice,
    'sell_price': sellPrice,
    'department_code': departmentCode,
    'updated_at': dateUpdated.toIso8601String(),
  };
}

/// Tombstone master: dihapus berdasarkan PLU (bukan id).
class DeletedProductDto {
  const DeletedProductDto(this.plu);
  final String plu;

  factory DeletedProductDto.fromJson(Map<String, dynamic> json) =>
      DeletedProductDto((json['plu'] as String?) ?? '');
}

class InspectorSetupResult {
  const InspectorSetupResult({required this.inspectorId, required this.racks});

  final int inspectorId;
  final List<RackDto> racks;

  factory InspectorSetupResult.fromJson(Map<String, dynamic> json) {
    final racks = (json['rak'] as List)
        .map(
          (e) =>
              RackDto(id: (e['id'] as num).toInt(), name: e['name'] as String),
        )
        .toList();
    return InspectorSetupResult(
      inspectorId: (json['inspector_id'] as num).toInt(),
      racks: racks,
    );
  }
}

class RackDto {
  const RackDto({required this.id, required this.name});
  final int id;
  final String name;

  factory RackDto.fromJson(Map<String, dynamic> json) =>
      RackDto(id: (json['id'] as num).toInt(), name: json['name'] as String);
}

/// Item untuk POST /stockopname/results/racks.
/// Backend mengidentifikasi produk via barcode (hasil scan) atau PLU —
/// bukan product_id. Upsert per (rak_id, plu) membuat retry aman.
class SoUploadItem {
  const SoUploadItem({
    required this.rakId,
    required this.plu,
    required this.barcode,
    required this.quantity,
  });

  final int rakId;
  final String plu;

  /// Barcode yang benar-benar dipindai (bisa barcode sekunder); '' bila PLU.
  final String barcode;

  final int quantity;

  Map<String, dynamic> toJson() => {
    'rak_id': rakId,
    'quantity': quantity,
    if (plu.isNotEmpty) 'plu': plu,
    if (barcode.isNotEmpty) 'barcode': barcode,
  };
}
