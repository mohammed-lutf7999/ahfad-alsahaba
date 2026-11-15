import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/quote_model.dart';

List<Quote> _parseQuotesJson(String jsonString) {
  final Map<String, dynamic> jsonData =
      json.decode(jsonString) as Map<String, dynamic>;
  return (jsonData['quotes'] as List<dynamic>)
      .map((q) => Quote.fromJson(Map<String, dynamic>.from(q as Map)))
      .toList();
}

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
  Future<void>? _inFlightLoad;
  
  /// تحميل المقولات من ملف JSON في خلفية Isolate لتفادي تعطيل واجهة المستخدم
  Future<void> loadQuotes() {
    if (_allQuotes.isNotEmpty) return Future<void>.value();
    _inFlightLoad ??= _loadQuotesInternal().whenComplete(() {
      _inFlightLoad = null;
    });
    return _inFlightLoad!;
  }

  Future<void> _loadQuotesInternal() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/salaf_quotes.json');
      _allQuotes = await compute(_parseQuotesJson, jsonString);

      // اختيار 3 مقولات عشوائية لليوم
      _selectDailyQuotes();
    } catch (e) {
      debugPrint('Error loading quotes: $e');
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
