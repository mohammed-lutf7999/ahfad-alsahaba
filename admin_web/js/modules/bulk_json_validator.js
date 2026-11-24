/* Pure JSON validator & native browser CompressionStream('gzip') helper for Plan 20 */

export function normalizeQuestionText(text) {
  return String(text || '')
    .trim()
    .toLowerCase()
    .replace(/[\u0640\u064B-\u065F\u0670]/g, '')
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/\s+/g, ' ');
}

export function stripUtf8Bom(rawText) {
  const s = String(rawText ?? '');
  return s.charCodeAt(0) === 0xfeff ? s.slice(1) : s;
}

export function validateAndNormalizeJson(rawData) {
  const errors = [];
  const warnings = [];
  const normalized = [];
  let meta = null;

  const pushCandidate = (item, fallbackLevel, indexInLevel) => {
    if (!item || typeof item !== 'object') {
      errors.push(`عنصر غير صالح في المستوى ${fallbackLevel} (فهرس ${indexInLevel}).`);
      return;
    }
    const rawId = String(item.id || '').trim();
    const levelNum = Number(item.levelNumber ?? item.level_number ?? fallbackLevel);
    const qText = String(item.question ?? item.question_text ?? '').trim();
    const rawOptions = Array.isArray(item.options) ? item.options : [];
    const cleanOptions = rawOptions.map((o) => String(o ?? '').trim());
    const correct = Number(item.correct ?? item.correct_index ?? -1);
    const explanation = String(item.explanation ?? '').trim();
    const sortOrder = Number(item.sortOrder ?? item.sort_order ?? 100 + indexInLevel);

    if (!/^[a-zA-Z0-9_-]{3,80}$/.test(rawId)) {
      errors.push(`معرّف السؤال غير صالح "${rawId}" (يجب 3–80 حرفاً إنجليزياً/أرقاماً/شرطة).`);
      return;
    }
    if (!Number.isInteger(levelNum) || levelNum < 1 || levelNum > 100) {
      errors.push(`رقم المستوى غير صالح (${levelNum}) للسؤال ${rawId} (المسموح 1..100).`);
      return;
    }
    if (qText.length < 3) {
      errors.push(`نص السؤال قصير جداً للمعرّف ${rawId}.`);
      return;
    }
    if (cleanOptions.length !== 4 || cleanOptions.some((o) => o.length === 0)) {
      errors.push(`السؤال ${rawId} يجب أن يحتوي على 4 خيارات غير فارغة تماماً.`);
      return;
    }
    if (!Number.isInteger(correct) || correct < 0 || correct > 3) {
      errors.push(`فهرس الإجابة الصحيحة (${correct}) غير صالح للسؤال ${rawId} (المسموح 0..3).`);
      return;
    }
    if (!explanation) {
      warnings.push(`السؤال ${rawId} بدون شرح تاريخي/شرعي (explanation).`);
    }

    const rawSyncScope = item.syncScope ?? item.sync_scope;
    const rawIsVisible = item.isVisible !== undefined ? item.isVisible : item.is_visible;

    normalized.push({
      id: rawId,
      level_number: levelNum,
      question_text: qText,
      options: cleanOptions,
      correct_index: correct,
      explanation,
      sync_scope: rawSyncScope === 'all_with_fallback' ? 'all_with_fallback' : 'solo_only',
      sort_order: Number.isFinite(sortOrder) ? Math.trunc(sortOrder) : 100,
      is_visible: rawIsVisible !== false,
    });
  };

  if (Array.isArray(rawData)) {
    rawData.forEach((item, idx) => pushCandidate(item, Number(item?.levelNumber ?? item?.level_number ?? 1), idx));
  } else if (rawData && typeof rawData === 'object' && rawData.levels && typeof rawData.levels === 'object') {
    const rawDrawMode = rawData.levelDrawMode ?? rawData.level_draw_mode;
    meta = {
      categoryId: String(rawData.categoryId || rawData.category_id || '').trim().toLowerCase(),
      categoryName: String(rawData.categoryName || rawData.category_name || '').trim(),
      description: String(rawData.description || '').trim(),
      colorHex: String(rawData.colorHex || rawData.color_hex || '#1B5E20').trim(),
      iconName: String(rawData.iconName || rawData.icon_name || rawData.iconKey || 'quiz_rounded').trim(),
      totalLevels: Number(rawData.totalLevels || rawData.total_levels || 0) || null,
      questionsPerLevel: Number(rawData.questionsPerLevel || rawData.questions_per_level || 10) || 10,
      levelDrawMode: rawDrawMode === 'rotating_pool' ? 'rotating_pool' : 'fixed',
    };
    const levelKeys = Object.keys(rawData.levels).sort((a, b) => Number(a) - Number(b));
    for (const lk of levelKeys) {
      const lvlNum = Number(lk);
      const list = rawData.levels[lk];
      if (!Array.isArray(list)) {
        errors.push(`المستوى "${lk}" يجب أن يكون مصفوفة أسئلة.`);
        continue;
      }
      list.forEach((item, idx) => pushCandidate(item, lvlNum, idx));
    }
  } else {
    errors.push('صيغة JSON غير مدعومة: يجب أن يحتوي الملف على كائن به حقل "levels" أو مصفوفة أسئلة.');
  }

  const seenIds = new Set();
  const seenTexts = new Map();
  for (const q of normalized) {
    if (seenIds.has(q.id)) {
      errors.push(`تكرار معرّف السؤال "${q.id}" داخل الملف.`);
    } else {
      seenIds.add(q.id);
    }
    const normText = normalizeQuestionText(q.question_text);
    if (seenTexts.has(normText)) {
      warnings.push(`نص سؤال مكرر بين (${seenTexts.get(normText)}) و(${q.id}).`);
    } else {
      seenTexts.set(normText, q.id);
    }
  }

  if (normalized.length === 0 && errors.length === 0) {
    errors.push('الملف لا يحتوي على أي أسئلة صالحة للاستيراد.');
  }

  return { normalized, meta, errors, warnings };
}

export async function compressJsonToGzipBytes(obj) {
  const jsonText = JSON.stringify(obj);
  const rawBytes = new TextEncoder().encode(jsonText);
  if (typeof CompressionStream === 'undefined') {
    throw new Error('المتصفح الحالي لا يدعم CompressionStream("gzip"). استخدم Edge أو Chrome حديثاً.');
  }
  const stream = new Blob([rawBytes]).stream().pipeThrough(new CompressionStream('gzip'));
  const compressedBuffer = await new Response(stream).arrayBuffer();
  return { rawBytes, gzBytes: new Uint8Array(compressedBuffer) };
}
