import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: product.isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.shade300,
          child: Text(
            product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
          ),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('SKU: ${product.sku}  •  \$${product.unitPrice.toStringAsFixed(2)}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
          tooltip: 'Delete product',
        ),
      ),
    );
  }
}
