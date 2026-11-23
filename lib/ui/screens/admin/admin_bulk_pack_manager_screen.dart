import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_custom_theme.dart';
import '../../../data/models/cms_models.dart';
import '../../../data/services/admin/admin_cms_quiz_mixin.dart';
import '../../../data/services/admin/bulk_question_json_validator.dart';
import '../../../data/services/admin_service.dart';
import '../../../data/services/cms_cache_service.dart';
import 'widgets/admin_ui_kit.dart';

/// Full-parity mobile admin screen for Plan 20:
/// - JSON-only bulk question importer (pick `.json` file via `FileType.any`
///   for Android 11–16 SAF compatibility OR paste from clipboard)
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
  static const List<({String id, String name})> _builtInDefaults = [
    (id: 'quran', name: 'القرآن الكريم'),
    (id: 'hadith', name: 'الحديث الشريف'),
    (id: 'fiqh', name: 'الفقه الإسلامي'),
    (id: 'seerah', name: 'السيرة النبوية'),
    (id: 'history', name: 'التاريخ الإسلامي'),
    (id: 'aqeedah', name: 'العقيدة الإسلامية'),
  ];

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
    _categories = _buildCategoriesFromCache();
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

  List<DynamicQuizCategoryData> _buildCategoriesFromCache() {
    final map = <String, DynamicQuizCategoryData>{
      for (final d in _builtInDefaults)
        d.id: DynamicQuizCategoryData(id: d.id, name: d.name),
    };
    for (final entry
        in CmsCacheService.instance.snapshot.quizCategories.entries) {
      map[entry.key] = entry.value;
    }
    return map.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  void _hydrateConfigFromCategory(DynamicQuizCategoryData cat) {
    _totalLevelsCtrl.text = '${cat.totalLevels}';
    _qPerLevelCtrl.text = '${cat.questionsPerLevel}';
    _drawMode = cat.levelDrawMode == 'rotating_pool' ? 'rotating_pool' : 'fixed';
  }

  String _activeCategoryId() {
    if (_isNewCategoryMode) {
      return _newCatIdCtrl.text.trim().toLowerCase();
    }
    return _selectedCategoryId.trim().toLowerCase();
  }

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
      // Use FileType.any so Android 11–16 SAF never grays out `.json` files
      // shared via WhatsApp/Telegram with generic MIME types; check extension below.
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      if (!file.name.toLowerCase().endsWith('.json')) {
        if (mounted) {
          showAdminFeedback(
            context,
            'يرجى اختيار ملف بامتداد .json فقط (الملف المختار: ${file.name}).',
            isError: true,
          );
        }
        return;
      }
      String rawText;
      if (file.bytes != null) {
        rawText = utf8.decode(file.bytes!);
      } else if (file.path != null && file.path!.isNotEmpty) {
        rawText = await File(file.path!).readAsString();
      } else {
        if (mounted) {
          showAdminFeedback(context, 'تعذر قراءة محتوى الملف.', isError: true);
        }
        return;
      }
      if (!mounted) return;
      await _applyParsedJson(rawText, 'ملف: ${file.name}');
    } catch (e) {
      if (!mounted) return;
      showAdminFeedback(context, 'تعذر فتح ملف JSON: $e', isError: true);
    }
  }

  Future<void> _pasteJsonFromClipboard() async {
    if (_isBusy) return;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      showAdminFeedback(
        context,
        'الحافظة فارغة — انسخ نص JSON أولاً.',
        isError: true,
      );
      return;
    }
    await _applyParsedJson(text, 'نص من الحافظة (${text.length} حرف)');
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
      await AdminService().upsertQuizCategory(
        id: catId,
        name: name,
        description: _newCatDescCtrl.text.trim(),
        iconName: _validation?.meta?.iconName ?? 'quiz_rounded',
        colorHex: _newCatColorCtrl.text.trim().isEmpty
            ? '#1B5E20'
            : _newCatColorCtrl.text.trim(),
        totalLevels: totalLevels,
      );
      final updated = await AdminService().updateQuizCategoryConfig(
        categoryId: catId,
        totalLevels: totalLevels,
        questionsPerLevel: qPerLevel,
        levelDrawMode: _drawMode,
      );
      if (mounted) {
        setState(() {
          final added = updated ??
              DynamicQuizCategoryData(
                id: catId,
                name: name,
                totalLevels: totalLevels,
                questionsPerLevel: qPerLevel,
                levelDrawMode: _drawMode,
              );
          _categories = [
            ..._categories.where((c) => c.id != catId),
            added,
          ]..sort((a, b) => a.id.compareTo(b.id));
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
      if (updated != null && mounted) {
        setState(() {
          _categories = [
            ..._categories.where((c) => c.id != catId),
            updated,
          ]..sort((a, b) => a.id.compareTo(b.id));
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
            setState(() {
              _progressLog = 'جارٍ رفع الأسئلة ($done / $total)...';
            });
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
          // Immediately reflect updated packVersion & packStoragePath in dropdown
          _categories = _categories.map((c) {
            if (c.id != res.categoryId) return c;
            return DynamicQuizCategoryData(
              id: c.id,
              name: c.name,
              description: c.description,
              iconName: c.iconName,
              colorHex: c.colorHex,
              totalLevels: c.totalLevels,
              questionsPerLevel: c.questionsPerLevel,
              levelDrawMode: c.levelDrawMode,
              packVersion: res.packVersion,
              packStoragePath: res.storagePath,
              sortOrder: c.sortOrder,
              isVisible: c.isVisible,
              isLocked: c.isLocked,
              cmsRevision: c.cmsRevision,
            );
          }).toList();
          _progressLog =
              '✅ نُشرت الحزمة ${res.storagePath} (${res.questionsCount} سؤالاً — $rawKb KB ← $gzKb KB Gzip).';
        });
        showAdminFeedback(context, 'تم نشر حزمة Gzip CDN بنجاح ($gzKb KB) ✅');
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
    final accent = AppCustomTheme.of(context).sovereignAccent;
    final val = _validation;

    return AdminScaffoldShell(
      title: 'استيراد JSON وحزم Gzip CDN',
      subtitle: 'إدارة المستويات المرنة ورفع آلاف الأسئلة من الجوال',
      isLoading: _isBusy,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          AdminSectionCard(
            title: '1. القسم المستهدف وإعدادات المستويات',
            icon: Icons.layers_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(
                        'قسم موجود',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                      ),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(
                        'قسم جديد',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                      ),
                    ),
                  ],
                  selected: {_isNewCategoryMode},
                  onSelectionChanged: _isBusy
                      ? null
                      : (sel) {
                          setState(() {
                            _isNewCategoryMode = sel.first;
                            if (!_isNewCategoryMode) {
                              final cat = _categories
                                  .where((c) => c.id == _selectedCategoryId)
                                  .firstOrNull;
                              if (cat != null) _hydrateConfigFromCategory(cat);
                            }
                          });
                        },
                ),
                const SizedBox(height: 12),
                if (!_isNewCategoryMode)
                  DropdownButtonFormField<String>(
                    key: const Key('bulk_existing_category_dropdown'),
                    isExpanded: true,
                    value: _categories.any((c) => c.id == _selectedCategoryId)
                        ? _selectedCategoryId
                        : (_categories.isNotEmpty ? _categories.first.id : null),
                    dropdownColor: AppCustomTheme.of(context).surfaceCard,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'اختر القسم',
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              '${c.name} (${c.id}) — v${c.packVersion}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _isBusy
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _selectedCategoryId = v;
                              final cat = _categories
                                  .where((c) => c.id == v)
                                  .firstOrNull;
                              if (cat != null) _hydrateConfigFromCategory(cat);
                            });
                          },
                  )
                else ...[
                  AdminTextField(
                    controller: _newCatIdCtrl,
                    label: 'معرّف القسم الجديد (إنجليزي صغير مثل: ghazawat)',
                  ),
                  const SizedBox(height: 10),
                  AdminTextField(
                    controller: _newCatNameCtrl,
                    label: 'اسم القسم العربي',
                  ),
                  const SizedBox(height: 10),
                  AdminTextField(
                    controller: _newCatDescCtrl,
                    label: 'وصف مختصر للقسم',
                  ),
                  const SizedBox(height: 10),
                  AdminTextField(
                    controller: _newCatColorCtrl,
                    label: 'لون القسم (Hex مثل #1B5E20)',
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AdminTextField(
                        controller: _totalLevelsCtrl,
                        label: 'المستويات (1–100)',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminTextField(
                        controller: _qPerLevelCtrl,
                        label: 'الأسئلة/مستوى',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('bulk_draw_mode_dropdown'),
                  isExpanded: true,
                  value: _drawMode,
                  dropdownColor: AppCustomTheme.of(context).surfaceCard,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'نمط السحب',
                    labelStyle: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'fixed',
                      child: Text(
                        'ثابت (fixed)',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'rotating_pool',
                      child: Text(
                        'وعاء متجدد تلقائياً (rotating_pool)',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                  onChanged: _isBusy
                      ? null
                      : (v) {
                          if (v != null) setState(() => _drawMode = v);
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AdminSectionCard(
            title: '2. تحميل وفحص ملف الأسئلة (JSON فقط)',
            icon: Icons.upload_file_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      key: const Key('btn_pick_json_file'),
                      onPressed: _isBusy ? null : _pickJsonFile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text(
                        'اختيار ملف JSON',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('btn_paste_json_clipboard'),
                      onPressed: _isBusy ? null : _pasteJsonFromClipboard,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      label: const Text(
                        'لصق من الحافظة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                if (_sourceLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _sourceLabel,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (val != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: val.isValid
                            ? const Color(0xFF10B981).withValues(alpha: 0.6)
                            : Colors.redAccent.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          val.isValid
                              ? '✅ جاهز للرفع: ${val.normalizedQuestions.length} سؤالاً عبر ${val.distinctLevelsCount} مستوى (أعلى مستوى: ${val.maxLevel})'
                              : '❌ يوجد ${val.errors.length} خطأ يمنع الرفع:',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: val.isValid
                                ? const Color(0xFF34D399)
                                : Colors.redAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        for (final err in val.errors.take(6))
                          Text(
                            '• $err',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        if (val.warnings.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '⚠️ تنبيهات (${val.warnings.length}): ${val.warnings.take(2).join(' | ')}',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.amberAccent,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          AdminSectionCard(
            title: '3. التنفيذ والنشر السحابي (Gzip CDN)',
            icon: Icons.cloud_upload_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('btn_mobile_bulk_upload'),
                    onPressed: (_isBusy || val == null || !val.isValid)
                        ? null
                        : _handleBulkUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.upload_rounded, size: 19),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'رفع الأسئلة للقاعدة (دفعات 200)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('btn_mobile_save_config'),
                    onPressed: _isBusy ? null : _handleSaveConfigOnly,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 19),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'حفظ إعدادات المستويات والنمط للقسم',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const Key('btn_mobile_publish_gzip'),
                    onPressed: _isBusy ? null : _handlePublishGzipPack,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981)),
                      foregroundColor: const Color(0xFF34D399),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.archive_rounded, size: 19),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ضغط ونشر حزمة Gzip CDN للقسم',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_progressLog.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _progressLog,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
