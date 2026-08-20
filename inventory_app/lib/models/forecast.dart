class ForecastPoint {
  final DateTime forecastDate;
  final double predictedDemand;
  final double? lowerBound;
  final double? upperBound;

  ForecastPoint({
    required this.forecastDate,
    required this.predictedDemand,
    this.lowerBound,
    this.upperBound,
  });

  factory ForecastPoint.fromJson(Map<String, dynamic> json) {
    return ForecastPoint(
      forecastDate: DateTime.parse(json['forecast_date']),
      predictedDemand: (json['predicted_demand'] as num).toDouble(),
      lowerBound: json['lower_bound'] != null ? (json['lower_bound'] as num).toDouble() : null,
      upperBound: json['upper_bound'] != null ? (json['upper_bound'] as num).toDouble() : null,
    );
  }
}

class ReorderSuggestion {
  final int productId;
  final String productName;
  final int currentStock;
  final double predictedDemandNext14Days;
  final bool reorderRecommended;
  final double suggestedReorderQty;

  ReorderSuggestion({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.predictedDemandNext14Days,
    required this.reorderRecommended,
    required this.suggestedReorderQty,
  });

  factory ReorderSuggestion.fromJson(Map<String, dynamic> json) {
    return ReorderSuggestion(
      productId: json['product_id'],
      productName: json['product_name'],
      currentStock: json['current_stock'],
      predictedDemandNext14Days: (json['predicted_demand_next_14_days'] as num).toDouble(),
      reorderRecommended: json['reorder_recommended'],
      suggestedReorderQty: (json['suggested_reorder_qty'] as num).toDouble(),
    );
  }
}
