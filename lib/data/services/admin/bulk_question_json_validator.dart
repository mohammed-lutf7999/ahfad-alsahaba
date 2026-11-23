import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../models/control/admin_player_dossier_models.dart';

/// Top-level Isolate function compressing a JSON-serializable pack Map into
/// raw Gzip bytes via `dart:io` `gzip.encode`.
({Uint8List rawBytes, Uint8List gzBytes}) encodeJsonToGzipBytes(
  Map<String, dynamic> payload,
) {
  final rawBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  final gzBytes = Uint8List.fromList(gzip.encode(rawBytes));
  return (rawBytes: rawBytes, gzBytes: gzBytes);
}

/// Optional category metadata extracted from a bulk JSON pack file.
class BulkQuestionPackMeta {
  final String categoryId;
  final String categoryName;
  final String description;
  final String colorHex;
  final String iconName;
  final int? totalLevels;
  final int questionsPerLevel;
  final String levelDrawMode;

  const BulkQuestionPackMeta({
    this.categoryId = '',
    this.categoryName = '',
    this.description = '',
    this.colorHex = '#1B5E20',
    this.iconName = 'quiz_rounded',
    this.totalLevels,
    this.questionsPerLevel = 10,
    this.levelDrawMode = 'fixed',
  });
}

/// Validation output for bulk JSON question imports.
class BulkQuestionValidationResult {
  final List<Map<String, dynamic>> normalizedQuestions;
  final BulkQuestionPackMeta? meta;
  final List<String> errors;
  final List<String> warnings;
  final int maxLevel;
  final int distinctLevelsCount;

  const BulkQuestionValidationResult({
    required this.normalizedQuestions,
    this.meta,
    required this.errors,
    required this.warnings,
    required this.maxLevel,
    required this.distinctLevelsCount,
  });

  bool get isValid => errors.isEmpty && normalizedQuestions.isNotEmpty;
}

/// Pure validator & normalizer for JSON-only bulk question imports and
/// formula-injection-safe CSV export of players.
class BulkQuestionJsonValidator {
  BulkQuestionJsonValidator._();

  static final RegExp _validIdRegex = RegExp(r'^[a-zA-Z0-9_-]{3,80}$');
  static final RegExp _arabicDiacriticsRegex =
      RegExp(r'[\u0640\u064B-\u065F\u0670]');

  static String normalizeArabicText(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(_arabicDiacriticsRegex, '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Parses and validates raw JSON text (either `{ levels: {...} }` or `[...]`).
  static BulkQuestionValidationResult parseAndValidateJsonString(
    String rawJsonText,
  ) {
    try {
      final decoded = jsonDecode(rawJsonText);
      return validateDecoded(decoded);
    } catch (e) {
      return BulkQuestionValidationResult(
        normalizedQuestions: const [],
        errors: ['ملف JSON غير صالح: $e'],
        warnings: const [],
        maxLevel: 1,
        distinctLevelsCount: 0,
      );
    }
  }

  static BulkQuestionValidationResult validateDecoded(dynamic rawData) {
    final errors = <String>[];
    final warnings = <String>[];
    final normalized = <Map<String, dynamic>>[];
    BulkQuestionPackMeta? meta;

    void pushCandidate(dynamic rawItem, int fallbackLevel, int indexInLevel) {
      if (rawItem is! Map) {
        errors.add(
          'عنصر غير صالح في المستوى $fallbackLevel (فهرس $indexInLevel).',
        );
        return;
      }
      final item = Map<String, dynamic>.from(rawItem);
      final rawId = (item['id'] ?? '').toString().trim();
      final levelNum =
          _toInt(item['levelNumber'] ?? item['level_number']) ?? fallbackLevel;
      final qText =
          (item['question'] ?? item['question_text'] ?? '').toString().trim();
      final rawOptions = item['options'] is List ? item['options'] as List : [];
      final cleanOptions =
          rawOptions.map((o) => (o ?? '').toString().trim()).toList();
      final correct = _toInt(
            item['correct'] ?? item['correctIndex'] ?? item['correct_index'],
          ) ??
          -1;
      final explanation = (item['explanation'] ?? '').toString().trim();
      final sortOrder =
          _toInt(item['sortOrder'] ?? item['sort_order']) ??
              (100 + indexInLevel);
      final rawScope =
          (item['syncScope'] ?? item['sync_scope'] ?? 'solo_only')
              .toString()
              .trim();
      final rawVisible = item.containsKey('isVisible')
          ? item['isVisible']
          : item['is_visible'];

      if (!_validIdRegex.hasMatch(rawId)) {
        errors.add(
          'معرّف السؤال غير صالح "$rawId" (يجب 3–80 حرفاً إنجليزياً/أرقاماً/شرطة).',
        );
        return;
      }
      if (levelNum < 1 || levelNum > 100) {
        errors.add(
          'رقم المستوى غير صالح ($levelNum) للسؤال $rawId (المسموح 1..100).',
        );
        return;
      }
      if (qText.length < 3) {
        errors.add('نص السؤال قصير جداً للمعرّف $rawId.');
        return;
      }
      if (cleanOptions.length != 4 || cleanOptions.any((o) => o.isEmpty)) {
        errors.add('السؤال $rawId يجب أن يحتوي على 4 خيارات غير فارغة تماماً.');
        return;
      }
      if (correct < 0 || correct > 3) {
        errors.add(
          'فهرس الإجابة الصحيحة ($correct) غير صالح للسؤال $rawId (المسموح 0..3).',
        );
        return;
      }
      if (explanation.isEmpty) {
        warnings.add('السؤال $rawId بدون شرح (explanation).');
      }

      normalized.add({
        'id': rawId,
        'level_number': levelNum,
        'question_text': qText,
        'options': cleanOptions,
        'correct_index': correct,
        'explanation': explanation,
        'sync_scope': rawScope == 'all_with_fallback'
            ? 'all_with_fallback'
            : 'solo_only',
        'sort_order': sortOrder,
        'is_visible': rawVisible != false,
      });
    }

    if (rawData is List) {
      for (var i = 0; i < rawData.length; i++) {
        final item = rawData[i];
        final fallbackLvl = item is Map
            ? (_toInt(item['levelNumber'] ?? item['level_number']) ?? 1)
            : 1;
        pushCandidate(item, fallbackLvl, i);
      }
    } else if (rawData is Map && rawData['levels'] is Map) {
      final map = Map<String, dynamic>.from(rawData);
      final rawDrawMode =
          (map['levelDrawMode'] ?? map['level_draw_mode'] ?? 'fixed')
              .toString()
              .trim();
      final parsedTotal =
          _toInt(map['totalLevels'] ?? map['total_levels']);
      meta = BulkQuestionPackMeta(
        categoryId: (map['categoryId'] ?? map['category_id'] ?? '')
            .toString()
            .trim()
            .toLowerCase(),
        categoryName:
            (map['categoryName'] ?? map['category_name'] ?? '').toString().trim(),
        description: (map['description'] ?? '').toString().trim(),
        colorHex:
            (map['colorHex'] ?? map['color_hex'] ?? '#1B5E20').toString().trim(),
        iconName: (map['iconName'] ??
                map['icon_name'] ??
                map['iconKey'] ??
                'quiz_rounded')
            .toString()
            .trim(),
        totalLevels: (parsedTotal != null && parsedTotal > 0)
            ? parsedTotal.clamp(1, 100)
            : null,
        questionsPerLevel:
            (_toInt(map['questionsPerLevel'] ?? map['questions_per_level']) ??
                    10)
                .clamp(1, 100),
        levelDrawMode:
            rawDrawMode == 'rotating_pool' ? 'rotating_pool' : 'fixed',
      );

      final levelsMap = Map<String, dynamic>.from(map['levels'] as Map);
      final sortedKeys = levelsMap.keys.toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
      for (final lk in sortedKeys) {
        final lvlNum = int.tryParse(lk) ?? -1;
        final list = levelsMap[lk];
        if (list is! List) {
          errors.add('المستوى "$lk" يجب أن يكون مصفوفة أسئلة.');
          continue;
        }
        for (var i = 0; i < list.length; i++) {
          pushCandidate(list[i], lvlNum, i);
        }
      }
    } else {
      errors.add(
        'صيغة JSON غير مدعومة: يجب أن يحتوي الملف على كائن به حقل "levels" أو مصفوفة أسئلة.',
      );
    }

    // Duplicate ID (error) & duplicate question text (warning) checks
    final seenIds = <String>{};
    final seenTexts = <String, String>{};
    final levelSet = <int>{};
    var maxLvl = 1;

    for (final q in normalized) {
      final id = q['id'] as String;
      final lvl = q['level_number'] as int;
      levelSet.add(lvl);
      if (lvl > maxLvl) maxLvl = lvl;

      if (!seenIds.add(id)) {
        errors.add('تكرار معرّف السؤال "$id" داخل الملف.');
      }
      final normText = normalizeArabicText(q['question_text'] as String);
      final prevId = seenTexts[normText];
      if (prevId != null) {
        warnings.add('نص سؤال مكرر بين ($prevId) و($id).');
      } else {
        seenTexts[normText] = id;
      }
    }

    if (normalized.isEmpty && errors.isEmpty) {
      errors.add('الملف لا يحتوي على أي أسئلة صالحة للاستيراد.');
    }

    return BulkQuestionValidationResult(
      normalizedQuestions: normalized,
      meta: meta,
      errors: errors,
      warnings: warnings,
      maxLevel: maxLvl,
      distinctLevelsCount: levelSet.length,
    );
  }

  static int? _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  /// Escapes a CSV cell safely and neutralizes spreadsheet formula injection
  /// (`=`, `+`, `-`, `@`, `\t`, `\r`).
  static String escapeCsvCell(Object? value) {
    var str = (value ?? '').toString().replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (str.isNotEmpty) {
      final first = str[0];
      if (first == '=' ||
          first == '+' ||
          first == '-' ||
          first == '@' ||
          first == '\t' ||
          first == '\r') {
        str = "'$str";
      }
    }
    final escaped = str.replaceAll('"', '""');
    return '"$escaped"';
  }

  /// Builds a UTF-8 BOM CSV string for [players] safe for Excel & Google Sheets.
  static String buildPlayersCsv(List<AdminPlayerSearchResult> players) {
    final buf = StringBuffer('\uFEFF');
    buf.writeln(
      [
        'player_name',
        'player_code',
        'user_id',
        'email',
        'total_score',
        'trophies',
        'player_level',
        'is_guest',
        'platform',
        'app_version',
      ].map(escapeCsvCell).join(','),
    );
    for (final p in players) {
      buf.writeln(
        [
          p.displayName,
          p.playerCode ?? '',
          p.userId ?? '',
          p.email ?? '',
          p.totalScore,
          p.trophies,
          p.playerLevel,
          p.isGuest ? 'guest' : 'google',
          p.platform ?? '',
          p.appVersion ?? '',
        ].map(escapeCsvCell).join(','),
      );
    }
    return buf.toString();
  }
}
