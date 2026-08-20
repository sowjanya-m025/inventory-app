import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/forecast.dart';
import '../services/api_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _api = ApiService();
  late Future<List<ForecastPoint>> _forecastFuture;
  late Future<ReorderSuggestion> _reorderFuture;

  final _quantityController = TextEditingController();
  String _transactionType = 'inbound';
  bool _submittingTransaction = false;

  @override
  void initState() {
    super.initState();
    _forecastFuture = _api.getForecast(widget.product.productId);
    _reorderFuture = _api.getReorderSuggestion(widget.product.productId);
  }

  Future<void> _submitTransaction() async {
    final qty = int.tryParse(_quantityController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }

    setState(() => _submittingTransaction = true);
    try {
      await _api.createTransaction(
        productId: widget.product.productId,
        warehouseId: 1, // single-warehouse setup from seed data
        transactionType: _transactionType,
        quantity: qty,
      );
      _quantityController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction recorded')),
        );
        setState(() {
          _reorderFuture = _api.getReorderSuggestion(widget.product.productId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submittingTransaction = false);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SKU: ${widget.product.sku}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text('\$${widget.product.unitPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Reorder Suggestion (the AI payoff) ----------
          Text('Reorder Recommendation', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FutureBuilder<ReorderSuggestion>(
            future: _reorderFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  color: Colors.grey.shade100,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No forecast data yet. Run ml/train_forecast.py on the backend.'),
                  ),
                );
              }
              final suggestion = snapshot.data!;
              return Card(
                color: suggestion.reorderRecommended
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            suggestion.reorderRecommended ? Icons.warning_amber : Icons.check_circle,
                            color: suggestion.reorderRecommended ? Colors.orange.shade700 : Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            suggestion.reorderRecommended ? 'Reorder Recommended' : 'Stock Level Healthy',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Current stock: ${suggestion.currentStock} units'),
                      Text(
                        'Predicted demand (next 14 days): ${suggestion.predictedDemandNext14Days.toStringAsFixed(1)} units',
                      ),
                      if (suggestion.reorderRecommended)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Suggested reorder quantity: ${suggestion.suggestedReorderQty.toStringAsFixed(0)} units',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // ---------- 30-Day Demand Forecast Chart ----------
          Text('30-Day Demand Forecast', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: FutureBuilder<List<ForecastPoint>>(
              future: _forecastFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || (snapshot.data?.isEmpty ?? true)) {
                  return const Center(child: Text('No forecast data available yet.'));
                }
                final points = snapshot.data!;
                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 5,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= points.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat('M/d').format(points[index].forecastDate),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (int i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].predictedDemand),
                        ],
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // ---------- Record Stock Movement ----------
          Text('Record Stock Movement', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _transactionType,
                          decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'inbound', child: Text('Inbound (restock)')),
                            DropdownMenuItem(value: 'outbound', child: Text('Outbound (sale)')),
                            DropdownMenuItem(value: 'adjustment', child: Text('Adjustment')),
                            DropdownMenuItem(value: 'return', child: Text('Return')),
                          ],
                          onChanged: (value) => setState(() => _transactionType = value!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _quantityController,
                          decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submittingTransaction ? null : _submitTransaction,
                      child: _submittingTransaction
                          ? const SizedBox(
                              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
