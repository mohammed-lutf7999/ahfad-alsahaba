import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/models/cms_models.dart';
import '../../../data/services/admin/admin_cms_quiz_mixin.dart';
import '../../../data/services/admin/bulk_question_json_validator.dart';
import '../../../data/services/admin_service.dart';
import 'bulk/bulk_category_config_card.dart';
import 'bulk/bulk_json_import_card.dart';
import 'bulk/bulk_json_source_picker.dart';
import 'bulk/bulk_pack_publish_card.dart';
import 'widgets/admin_ui_kit.dart';

/// Full-parity mobile admin screen for Plan 20:
/// - JSON-only bulk question importer (`FileType.any` SAF-safe OR clipboard)
/// - Off-UI-thread Isolate JSON parsing & validation via `compute`
/// - Existing category (preserving custom config) OR new category creation
/// - Flexible levels (`1–100`), questions/level (`1–100`), & `fixed`/`rotating_pool`
/// - Native `dart:io` Gzip compression (Isolate) & CDN Storage pack publishing
/// - Zero network calls on screen open (reads categories from `CmsCacheService`)
class AdminBulkPackManagerScreen extends StatefulWidget {
  const AdminBulkPackManagerScreen({super.key});

  @override
  State<AdminBulkPackManagerScreen> createState() =>
      _AdminBulkPackManagerScreenState();
}

class _AdminBulkPackManagerScreenState
    extends State<AdminBulkPackManagerScreen> {
  final _newCatIdCtrl = TextEditingController();
  final _newCatNameCtrl = TextEditingController();
  final _newCatDescCtrl = TextEditingController();
  final _newCatColorCtrl = TextEditingController(text: '#1B5E20');
  final _totalLevelsCtrl = TextEditingController(text: '10');
  final _qPerLevelCtrl = TextEditingController(text: '10');

  bool _isNewCategoryMode = false;
  String _selectedCategoryId = 'seerah';
  String _drawMode = 'fixed';
  bool _isBusy = false;
  String _sourceLabel = '';
  String _progressLog = '';
  BulkQuestionValidationResult? _validation;

  late List<DynamicQuizCategoryData> _categories;

  @override
  void initState() {
    super.initState();
    _categories = buildBulkCategoriesFromCache();
    if (_categories.isNotEmpty) {
      _selectedCategoryId = _categories.first.id;
      _hydrateConfigFromCategory(_categories.first);
    }
  }

  @override
  void dispose() {
    _newCatIdCtrl.dispose();
    _newCatNameCtrl.dispose();
    _newCatDescCtrl.dispose();
    _newCatColorCtrl.dispose();
    _totalLevelsCtrl.dispose();
    _qPerLevelCtrl.dispose();
    super.dispose();
  }

  void _hydrateConfigFromCategory(DynamicQuizCategoryData cat) {
    _totalLevelsCtrl.text = '${cat.totalLevels}';
    _qPerLevelCtrl.text = '${cat.questionsPerLevel}';
    _drawMode = cat.levelDrawMode == 'rotating_pool' ? 'rotating_pool' : 'fixed';
  }

  String _activeCategoryId() => _isNewCategoryMode
      ? _newCatIdCtrl.text.trim().toLowerCase()
      : _selectedCategoryId.trim().toLowerCase();

  Future<void> _applyParsedJson(String rawText, String label) async {
    if (mounted) {
      setState(() {
        _isBusy = true;
        _progressLog = 'جارٍ فحص وتحليل ملف JSON...';
      });
    }
    try {
      final result = await compute(parseAndValidateBulkJsonIsolate, rawText);
      if (!mounted) return;
      setState(() {
        _sourceLabel = label;
        _validation = result;
        _progressLog = '';
        final meta = result.meta;
        if (meta != null) {
          if (meta.categoryId.isNotEmpty) {
            final existing =
                _categories.where((c) => c.id == meta.categoryId).firstOrNull;
            if (existing != null) {
              _isNewCategoryMode = false;
              _selectedCategoryId = existing.id;
              _hydrateConfigFromCategory(existing);
            } else {
              _isNewCategoryMode = true;
              _newCatIdCtrl.text = meta.categoryId;
              _newCatNameCtrl.text = meta.categoryName;
              _newCatDescCtrl.text = meta.description;
              if (meta.colorHex.isNotEmpty) {
                _newCatColorCtrl.text = meta.colorHex;
              }
            }
          }
          // Only override config fields if explicitly present in JSON metadata
          // (never silently reset an existing category's custom config!).
          if (meta.totalLevels != null) {
            _totalLevelsCtrl.text = '${meta.totalLevels}';
          }
          if (meta.questionsPerLevel != null) {
            _qPerLevelCtrl.text = '${meta.questionsPerLevel}';
          }
          if (meta.levelDrawMode != null) {
            _drawMode = meta.levelDrawMode!;
          }
        }
        if (_isNewCategoryMode &&
            (meta == null || meta.totalLevels == null) &&
            result.normalizedQuestions.isNotEmpty) {
          _totalLevelsCtrl.text = '${result.maxLevel}';
        }
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _pickJsonFile() async {
    if (_isBusy) return;
    try {
      final src = await pickBulkJsonFileSource();
      if (!mounted) return;
      if (src.error != null) {
        showAdminFeedback(context, src.error!, isError: true);
        return;
      }
      if (src.rawText != null && src.label != null) {
        await _applyParsedJson(src.rawText!, src.label!);
      }
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر فتح ملف JSON: $e', isError: true);
    }
  }

  Future<void> _pasteJsonFromClipboard() async {
    if (_isBusy) return;
    final src = await readBulkJsonClipboardSource();
    if (!mounted) return;
    if (src.error != null) {
      showAdminFeedback(context, src.error!, isError: true);
      return;
    }
    if (src.rawText != null && src.label != null) {
      await _applyParsedJson(src.rawText!, src.label!);
    }
  }

  Future<String> _ensureCategoryReady({
    required bool saveConfigForExisting,
  }) async {
    final catId = _activeCategoryId();
    if (!RegExp(r'^[a-z0-9_]{2,48}$').hasMatch(catId)) {
      throw ArgumentError(
        'معرّف القسم غير صالح (أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط).',
      );
    }
    final totalLevels =
        (int.tryParse(_totalLevelsCtrl.text.trim()) ?? 10).clamp(1, 100);
    final qPerLevel =
        (int.tryParse(_qPerLevelCtrl.text.trim()) ?? 10).clamp(1, 100);

    if (_isNewCategoryMode) {
      final name = _newCatNameCtrl.text.trim();
      if (name.length < 2) {
        throw ArgumentError('يرجى إدخال اسم القسم العربي قبل الحفظ.');
      }
      final created = await AdminService().upsertQuizCategory(
        id: catId,
        name: name,
        description: _newCatDescCtrl.text.trim(),
        iconName: _validation?.meta?.iconName ?? 'quiz_rounded',
        colorHex: _newCatColorCtrl.text.trim().isEmpty
            ? '#1B5E20'
            : _newCatColorCtrl.text.trim(),
        totalLevels: totalLevels,
      );
      if (created == null) {
        throw StateError('تعذر إنشاء القسم؛ تحقق من الاتصال وصلاحيات المشرف.');
      }
      final updated = await AdminService().updateQuizCategoryConfig(
        categoryId: catId,
        totalLevels: totalLevels,
        questionsPerLevel: qPerLevel,
        levelDrawMode: _drawMode,
      );
      if (mounted) {
        setState(() {
          final added = updated ?? created;
          _categories = [..._categories.where((c) => c.id != catId), added]
            ..sort((a, b) => a.id.compareTo(b.id));
          _selectedCategoryId = catId;
          _isNewCategoryMode = false;
        });
      }
      return catId;
    }

    if (saveConfigForExisting) {
      final updated = await AdminService().updateQuizCategoryConfig(
        categoryId: catId,
        totalLevels: totalLevels,
        questionsPerLevel: qPerLevel,
        levelDrawMode: _drawMode,
      );
      if (updated == null) {
        throw StateError('تعذر حفظ إعدادات القسم؛ تحقق من الاتصال وصلاحيات المشرف.');
      }
      if (mounted) {
        setState(() {
          _categories = [..._categories.where((c) => c.id != catId), updated]
            ..sort((a, b) => a.id.compareTo(b.id));
        });
      }
    }
    return catId;
  }

  Future<void> _handleBulkUpload() async {
    final val = _validation;
    if (_isBusy || val == null || !val.isValid) return;
    setState(() {
      _isBusy = true;
      _progressLog = 'جارٍ تجهيز القسم...';
    });
    try {
      final catId = await _ensureCategoryReady(saveConfigForExisting: false);
      final uploaded = await AdminService().bulkUpsertQuizQuestions(
        categoryId: catId,
        questions: val.normalizedQuestions,
        onProgress: (done, total) {
          if (mounted) {
            setState(() => _progressLog = 'جارٍ رفع الأسئلة ($done / $total)...');
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _progressLog =
            '✅ تم رفع $uploaded سؤالاً إلى ($catId). اضغط الآن "ضغط ونشر حزمة Gzip CDN" لتوزيعها للاعبين.';
      });
      showAdminFeedback(context, 'تم استيراد $uploaded سؤالاً بنجاح ✅');
    } catch (e) {
      if (!mounted) return;
      setState(() => _progressLog = '❌ فشل الاستيراد: $e');
      showAdminFeedback(context, 'فشل الاستيراد: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleSaveConfigOnly() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _progressLog = 'جارٍ حفظ إعدادات المستويات والنمط...';
    });
    try {
      final catId = await _ensureCategoryReady(saveConfigForExisting: true);
      if (!mounted) return;
      setState(() {
        _progressLog = '✅ تم حفظ إعدادات القسم ($catId) وبث التحديث.';
      });
      showAdminFeedback(context, 'تم حفظ إعدادات القسم بنجاح ✅');
    } catch (e) {
      if (!mounted) return;
      setState(() => _progressLog = '❌ تعذر حفظ الإعدادات: $e');
      showAdminFeedback(context, 'تعذر حفظ الإعدادات: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handlePublishGzipPack() async {
    if (_isBusy) return;
    final catId = _activeCategoryId();
    if (catId.isEmpty) {
      showAdminFeedback(context, 'اختر القسم المستهدف أولاً.', isError: true);
      return;
    }
    setState(() {
      _isBusy = true;
      _progressLog = 'جارٍ تصدير وضغط حزمة ($catId)...';
    });
    try {
      final AdminGzipPackPublishResult? res =
          await AdminService().exportAndPublishGzipPack(
        categoryId: catId,
        onStage: (stage) {
          if (mounted) setState(() => _progressLog = stage);
        },
      );
      if (!mounted) return;
      if (res != null) {
        final rawKb = (res.rawBytesLength / 1024).toStringAsFixed(1);
        final gzKb = (res.gzipBytesLength / 1024).toStringAsFixed(1);
        setState(() {
          _categories = applyPublishedPackVersion(_categories, res);
          _progressLog =
              '✅ نُشرت الحزمة ${res.storagePath} (${res.questionsCount} سؤالاً — $rawKb KB ← $gzKb KB Gzip).';
        });
        showAdminFeedback(context, 'تم نشر حزمة Gzip CDN بنجاح ($gzKb KB) ✅');
      } else {
        const msg = 'تعذر نشر الحزمة؛ تحقق من الاتصال وصلاحيات المشرف.';
        setState(() => _progressLog = '❌ $msg');
        showAdminFeedback(context, msg, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _progressLog = '❌ فشل نشر الحزمة: $e');
      showAdminFeedback(context, 'فشل نشر الحزمة: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final val = _validation;
    return AdminScaffoldShell(
      title: 'استيراد JSON وحزم Gzip CDN',
      subtitle: 'إدارة المستويات المرنة ورفع آلاف الأسئلة من الجوال',
      isLoading: _isBusy,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          BulkCategoryConfigCard(
            isNewCategoryMode: _isNewCategoryMode,
            isBusy: _isBusy,
            categories: _categories,
            selectedCategoryId: _selectedCategoryId,
            drawMode: _drawMode,
            newCatIdCtrl: _newCatIdCtrl,
            newCatNameCtrl: _newCatNameCtrl,
            newCatDescCtrl: _newCatDescCtrl,
            newCatColorCtrl: _newCatColorCtrl,
            totalLevelsCtrl: _totalLevelsCtrl,
            qPerLevelCtrl: _qPerLevelCtrl,
            onModeChanged: (isNew) {
              setState(() {
                _isNewCategoryMode = isNew;
                if (!_isNewCategoryMode) {
                  final cat = _categories
                      .where((c) => c.id == _selectedCategoryId)
                      .firstOrNull;
                  if (cat != null) _hydrateConfigFromCategory(cat);
                }
              });
            },
            onCategorySelected: (v) {
              setState(() {
                _selectedCategoryId = v;
                final cat = _categories.where((c) => c.id == v).firstOrNull;
                if (cat != null) _hydrateConfigFromCategory(cat);
              });
            },
            onDrawModeChanged: (v) => setState(() => _drawMode = v),
          ),
          const SizedBox(height: 14),
          BulkJsonImportCard(
            isBusy: _isBusy,
            sourceLabel: _sourceLabel,
            validation: val,
            onPickFile: _pickJsonFile,
            onPasteClipboard: _pasteJsonFromClipboard,
          ),
          const SizedBox(height: 14),
          BulkPackPublishCard(
            isBusy: _isBusy,
            canUpload: val != null && val.isValid,
            progressLog: _progressLog,
            onUpload: _handleBulkUpload,
            onSaveConfig: _handleSaveConfigOnly,
            onPublishGzip: _handlePublishGzipPack,
          ),
        ],
      ),
    );
  }
}
