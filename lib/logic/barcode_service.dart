import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class BarcodeService {
  static Future<String?> getIngredientsFromBarcode(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    
    try {
      final headers = {
        'User-Agent': 'TayyibScan - Android - Version 1.0'
      };

      debugPrint("Fetching: $url");
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // check if product exists
        if (data['status'] == 1 || data['status_verbose'] == 'product found') {
          final product = data['product'];
          
          // try to find any ingredients field
          String? ingredients = product['ingredients_text_en'] ?? 
                                product['ingredients_text'] ?? 
                                product['ingredients_text_with_allergens'];
          
          if (ingredients != null && ingredients.isNotEmpty) {
            return ingredients;
          } else {
            debugPrint("Product found, but no ingredients text listed.");
            return null;
          }
        } else {
          debugPrint("Product Status: ${data['status_verbose']}");
        }
      }
      return null; 
    } catch (e) {
      debugPrint("API Error: $e");
      return null;
    }
  }
}