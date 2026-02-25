import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class ScanRecord {
  final DateTime date;
  final List<String> ingredients;
  final bool isSafe;
  final String imagePath;

  ScanRecord({
    required this.date, 
    required this.ingredients, 
    required this.isSafe,
    required this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'ingredients': ingredients,
        'isSafe': isSafe,
        'imagePath': imagePath,
      };

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      date: DateTime.parse(json['date']),
      ingredients: List<String>.from(json['ingredients']),
      isSafe: json['isSafe'],
      imagePath: json['imagePath'] ?? '',
    );
  }
}

class HistoryLogic {
  static const String _key = 'scan_history';

  static Future<void> saveScan(List<String> ingredients, File originalImage) async {
    final prefs = await SharedPreferences.getInstance();
    
    // copy image to safe storage
    final directory = await getApplicationDocumentsDirectory();
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File localImage = await originalImage.copy('${directory.path}/$fileName');

    final newRecord = ScanRecord(
      date: DateTime.now(),
      ingredients: ingredients,
      isSafe: ingredients.isEmpty,
      imagePath: localImage.path,
    );

    List<String> historyList = prefs.getStringList(_key) ?? [];
    historyList.insert(0, jsonEncode(newRecord.toJson()));
    await prefs.setStringList(_key, historyList);
  }

  static Future<List<ScanRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyList = prefs.getStringList(_key) ?? [];
    return historyList.map((item) => ScanRecord.fromJson(jsonDecode(item))).toList();
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}