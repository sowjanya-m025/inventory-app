import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/forecast.dart';

class ApiService {
  // Your FastAPI server, running locally via `uvicorn app.main:app --reload`.
  // If you deploy the backend later, change this to the deployed URL.
  static const String baseUrl = 'http://127.0.0.1:8000';

  // ---------- Products ----------

  Future<List<Product>> getProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products/'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load products (${response.statusCode})');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Product.fromJson(json)).toList();
  }

  Future<Product> createProduct(Product product) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(product.toCreateJson()),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to create product');
    }
    return Product.fromJson(jsonDecode(response.body));
  }

  Future<void> deleteProduct(int productId) async {
    final response = await http.delete(Uri.parse('$baseUrl/products/$productId'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete product (${response.statusCode})');
    }
  }

  // ---------- Stock Transactions ----------

  Future<StockTransaction> createTransaction({
    required int productId,
    required int warehouseId,
    required String transactionType,
    required int quantity,
    String? referenceNote,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'product_id': productId,
        'warehouse_id': warehouseId,
        'transaction_type': transactionType,
        'quantity': quantity,
        if (referenceNote != null) 'reference_note': referenceNote,
      }),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to record transaction');
    }
    return StockTransaction.fromJson(jsonDecode(response.body));
  }

  Future<List<StockTransaction>> getTransactions({int? productId}) async {
    final uri = productId != null
        ? Uri.parse('$baseUrl/transactions/?product_id=$productId')
        : Uri.parse('$baseUrl/transactions/');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load transactions (${response.statusCode})');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => StockTransaction.fromJson(json)).toList();
  }

  // ---------- Forecasting ----------

  Future<List<ForecastPoint>> getForecast(int productId) async {
    final response = await http.get(Uri.parse('$baseUrl/forecasts/$productId?days=30'));
    if (response.statusCode != 200) {
      throw Exception('No forecast available for this product yet');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => ForecastPoint.fromJson(json)).toList();
  }

  Future<ReorderSuggestion> getReorderSuggestion(int productId) async {
    final response = await http.get(Uri.parse('$baseUrl/forecasts/$productId/reorder-suggestion'));
    if (response.statusCode != 200) {
      throw Exception('No reorder suggestion available for this product yet');
    }
    return ReorderSuggestion.fromJson(jsonDecode(response.body));
  }
}
