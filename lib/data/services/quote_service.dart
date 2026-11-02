import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/quote_model.dart';

/// خدمة إدارة المقولات
class QuoteService {
  static QuoteService? _instance;
  static QuoteService get instance {
    _instance ??= QuoteService._();
    return _instance!;
  }
  QuoteService._();

  List<Quote> _allQuotes = [];
  List<Quote> _dailyQuotes = [];
  final Random _random = Random();
  
  /// تحميل المقولات من ملف JSON
  Future<void> loadQuotes() async {
    if (_allQuotes.isNotEmpty) return;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/data/salaf_quotes.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      _allQuotes = (jsonData['quotes'] as List)
          .map((q) => Quote.fromJson(q))
          .toList();
          
      // اختيار 3 مقولات عشوائية لليوم
      _selectDailyQuotes();
    } catch (e) {
      print('Error loading quotes: $e');
      _allQuotes = [];
    }
  }

  /// اختيار 3 مقولات عشوائية
  void _selectDailyQuotes() {
    if (_allQuotes.isEmpty) return;
    
    final shuffled = List<Quote>.from(_allQuotes)..shuffle(_random);
    _dailyQuotes = shuffled.take(3).toList();
  }
  
  /// الحصول على مقولات اليوم
  List<Quote> get dailyQuotes => _dailyQuotes;
  
  /// تحديث المقولات بمقولات جديدة
  void refreshQuotes() {
    _selectDailyQuotes();
  }
  
  /// الحصول على جميع المقولات
  List<Quote> get allQuotes => _allQuotes;
}
