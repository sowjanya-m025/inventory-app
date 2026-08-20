class StockTransaction {
  final int transactionId;
  final int productId;
  final int warehouseId;
  final String transactionType;
  final int quantity;
  final String? referenceNote;
  final DateTime transactionDate;

  StockTransaction({
    required this.transactionId,
    required this.productId,
    required this.warehouseId,
    required this.transactionType,
    required this.quantity,
    this.referenceNote,
    required this.transactionDate,
  });

  factory StockTransaction.fromJson(Map<String, dynamic> json) {
    return StockTransaction(
      transactionId: json['transaction_id'],
      productId: json['product_id'],
      warehouseId: json['warehouse_id'],
      transactionType: json['transaction_type'],
      quantity: json['quantity'],
      referenceNote: json['reference_note'],
      transactionDate: DateTime.parse(json['transaction_date']),
    );
  }
}
