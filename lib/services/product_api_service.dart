import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';

class ProductApiService {
  Future<List<Product>> getProducts() async {
    final response = await http.get(
      Uri.parse('https://fakestoreapi.com/products'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      return data.map((item) {
        return Product(
          id: item['id'],
          title: item['title'],
          price: (item['price'] as num).toDouble(),
          image: item['image'],
        );
      }).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }
}