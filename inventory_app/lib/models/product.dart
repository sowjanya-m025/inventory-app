class Product {
  final int productId;
  final String sku;
  final String name;
  final String? description;
  final int? categoryId;
  final int? supplierId;
  final double unitPrice;
  final double unitCost;
  final int reorderPoint;
  final int reorderQty;
  final bool isActive;

  Product({
    required this.productId,
    required this.sku,
    required this.name,
    this.description,
    this.categoryId,
    this.supplierId,
    required this.unitPrice,
    required this.unitCost,
    required this.reorderPoint,
    required this.reorderQty,
    required this.isActive,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['product_id'],
      sku: json['sku'],
      name: json['name'],
      description: json['description'],
      categoryId: json['category_id'],
      supplierId: json['supplier_id'],
      unitPrice: (json['unit_price'] as num).toDouble(),
      unitCost: (json['unit_cost'] as num).toDouble(),
      reorderPoint: json['reorder_point'],
      reorderQty: json['reorder_qty'],
      isActive: json['is_active'],
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'sku': sku,
      'name': name,
      if (description != null) 'description': description,
      'unit_price': unitPrice,
      'unit_cost': unitCost,
      'reorder_point': reorderPoint,
      'reorder_qty': reorderQty,
    };
  }
}
