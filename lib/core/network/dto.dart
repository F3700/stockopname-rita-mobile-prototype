/// DTO 1:1 dengan backend Go. Jangan tambah field di luar kontrak.
class ProductDto {
  const ProductDto({
    required this.id,
    required this.barcode,
    required this.name,
    required this.buyPrice,
    required this.sellPrice,
    required this.dateCreated,
    required this.dateUpdated,
    required this.categoryName,
    required this.departmentCode,
  });

  final int id;
  final String barcode;
  final String name;
  final double buyPrice;
  final double sellPrice;
  final DateTime dateCreated;
  final DateTime dateUpdated;
  final String categoryName;
  final String departmentCode;

  factory ProductDto.fromJson(Map<String, dynamic> json) => ProductDto(
        id: (json['id'] as num).toInt(),
        barcode: json['barcode'] as String,
        name: json['name'] as String,
        buyPrice: (json['buy_price'] as num).toDouble(),
        sellPrice: (json['sell_price'] as num).toDouble(),
        dateCreated: DateTime.parse(json['date_created'] as String),
        dateUpdated: DateTime.parse(json['date_updated'] as String),
        categoryName: json['category_name'] as String,
        departmentCode: json['department_code'] as String,
      );

  Map<String, dynamic> toDbMap() => {
        'product_id': id,
        'barcode': barcode,
        'name': name,
        'buy_price': buyPrice,
        'sell_price': sellPrice,
        'category_name': categoryName,
        'department_code': departmentCode,
        'updated_at': dateUpdated.toIso8601String(),
      };
}

class DeletedProductDto {
  const DeletedProductDto(this.id);
  final int id;

  factory DeletedProductDto.fromJson(Map<String, dynamic> json) =>
      DeletedProductDto((json['id'] as num).toInt());
}

class InspectorSetupResult {
  const InspectorSetupResult({required this.inspectorId, required this.racks});

  final int inspectorId;
  final List<RackDto> racks;

  factory InspectorSetupResult.fromJson(Map<String, dynamic> json) {
    final racks = (json['rak'] as List)
        .map((e) => RackDto(
            id: (e['id'] as num).toInt(), name: e['name'] as String))
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

  factory RackDto.fromJson(Map<String, dynamic> json) => RackDto(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
      );
}

/// Item untuk POST /stockopname/results/racks
class SoUploadItem {
  const SoUploadItem({
    required this.productId,
    required this.rakId,
    required this.quantity,
  });

  final int productId;
  final int rakId;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'rak_id': rakId,
        'quantity': quantity,
      };
}
