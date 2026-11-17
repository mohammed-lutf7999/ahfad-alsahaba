(() => {
  'use strict';

  const cmsState = {
    storeItems: [],
    storeFilter: 'all',
    editingStoreId: null,
    libSections: [],
    libItems: [],
    quizCategories: [],
    quizQuestions: [],
    playerSearchRows: [],
    currentPlayerDetail: null,
    ghosts: [],
    auditLogs: [],
    adminsMeta: { is_owner: false, admins: [] },
    loadedOnce: false,
  };

  function bridge() {
    return window.SahabaAdminBridge;
  }

  function sb() {
    return bridge()?.getSupabase?.();
  }

  function esc(v) {
    return bridge().escapeHtml(v);
  }

  function safeHex(v, fb = '#D4AF37') {
    return bridge().safeHexColor(v, fb);
  }

  function toast(msg, isErr = false) {
    bridge().showToast(msg, isErr);
  }

  function fmtDate(iso) {
    return bridge().formatDateDisplay(iso);
  }

  function bumpOverview() {
    return bridge().loadOverview?.();
  }

  // ==================== VERSION BREAKDOWN ====================

  function renderVersionBreakdown(ov) {
    const listEl = document.getElementById('version-breakdown-list');
    const totalEl = document.getElementById('version-breakdown-total');
    if (!listEl || !totalEl) return;

    const rows = Array.isArray(ov?.version_breakdown) ? ov.version_breakdown : [];
    const total = rows.reduce((sum, r) => sum + Number(r.players_count || 0), 0);
    totalEl.textContent = `إجمالي الدليل: ${total}`;

    if (!rows.length) {
      listEl.innerHTML = '<p class="muted-text">لا توجد بيانات توزيع إصدارات مسجّلة بعد.</p>';
      return;
    }

    listEl.innerHTML = rows
      .map((row) => {
        const count = Number(row.players_count || 0);
        const pct = total > 0 ? Math.round((count / total) * 100) : 0;
        const verLabel = row.app_version
          ? `${esc(row.app_version)} (b${esc(row.version_code ?? '?')})`
          : `Build ${esc(row.version_code ?? '?')}`;
        return `
          <div class="version-row">
            <span class="code-tag">${verLabel}</span>
            <div class="version-track">
              <div class="version-fill" style="width:${Math.max(4, pct)}%;"></div>
            </div>
            <span class="muted-text">${count} (${pct}%)</span>
          </div>
        `;
      })
      .join('');
  }

  // ==================== GENERIC VISIBILITY TOGGLE ====================

  async function toggleEntityVisibility(entityType, id, nextVisible, afterSuccess) {
    const client = sb();
    if (!client) return;
    try {
      const { data, error } = await client.rpc('admin_set_content_visibility', {
        p_entity_type: entityType,
        p_id: id,
        p_is_visible: nextVisible,
      });
      if (error) throw error;
      toast(nextVisible ? 'تم إظهار العنصر فوراً ✅' : 'تم إخفاء العنصر بأمان 👁️‍🗨️');
      if (data?.cms_version) {
        const pill = document.getElementById('topbar-cms-ver');
        if (pill) pill.textContent = `#${data.cms_version}`;
      }
      await Promise.all([afterSuccess?.(), bumpOverview(), loadAuditLogs()]);
    } catch (err) {
      toast(`تعذر تغيير حالة الظهور: ${err.message}`, true);
      await afterSuccess?.();
    }
  }

  // ==================== STORE CMS ====================

  function syncStoreMetadataPanels() {
    const cat = document.getElementById('st-category').value;
    document.getElementById('store-meta-theme').classList.toggle('hidden', cat !== 'theme');
    document.getElementById('store-meta-frame').classList.toggle('hidden', cat !== 'frame');
    document
      .getElementById('store-meta-badge')
      .classList.toggle('hidden', cat !== 'title' && cat !== 'powerup');
    updateStorePreview();
  }

  function collectStoreMetadata(cat) {
    if (cat === 'theme') {
      const bg1 = safeHex(document.getElementById('st-th-bg1').value, '#1a0b2e').toUpperCase();
      const bg2 = safeHex(document.getElementById('st-th-bg2').value, '#2d1b4e').toUpperCase();
      const card = safeHex(document.getElementById('st-th-card').value, '#24143d').toUpperCase();
      const gold = safeHex(document.getElementById('st-th-gold').value, '#f3c644').toUpperCase();
      const sec = safeHex(document.getElementById('st-th-sec').value, '#38bdf8').toUpperCase();
      return {
        deepBackground: bg1,
        surfaceCard: card,
        sovereignAccent: gold,
        secondaryAccent: sec,
        previewColor: gold,
        bg_primary: bg1,
        bg_secondary: bg2,
        surface_card: card,
        accent_gold: gold,
        accent_secondary: sec,
      };
    }
    if (cat === 'frame') {
      const c1 = safeHex(document.getElementById('st-fr-c1').value, '#f3c644').toUpperCase();
      const c2 = safeHex(document.getElementById('st-fr-c2').value, '#10b981').toUpperCase();
      const glow = safeHex(document.getElementById('st-fr-glow').value, '#f3c644').toUpperCase();
      const pattern = document.getElementById('st-fr-pattern').value || 'aurora';
      const gems = document.getElementById('st-fr-gems').checked;
      return {
        primaryColor: c1,
        secondaryColor: c2,
        highlightColor: glow,
        previewColor: c2,
        hasCornerGems: gems,
        hasOctagonalStar: true,
        pattern_type: pattern,
      };
    }
    const qtyRaw = document.getElementById('st-powerup-qty').value.trim();
    const badgeHex = safeHex(document.getElementById('st-badge-color').value, '#f3c644').toUpperCase();
    const meta = {
      previewColor: badgeHex,
      sovereignAccent: badgeHex,
    };
    if (qtyRaw && Number.isFinite(Number(qtyRaw))) {
      meta.quantity = Number.parseInt(qtyRaw, 10);
    }
    return meta;
  }

  function updateStorePreview() {
    const previewEl = document.getElementById('store-live-preview');
    if (!previewEl) return;
    const cat = document.getElementById('st-category').value;
    const title = document.getElementById('st-title').value.trim() || 'اسم عنصر المتجر';
    const desc = document.getElementById('st-desc').value.trim() || 'وصف عنصر سوق الفرسان يظهر هنا';
    const coins = Number.parseInt(document.getElementById('st-coins').value || '0', 10) || 0;
    const gems = Number.parseInt(document.getElementById('st-gems').value || '0', 10) || 0;
    const visible = document.getElementById('st-visible').checked;
    const meta = collectStoreMetadata(cat);

    let visualHtml = '<div style="font-size:2rem;">🎖️</div>';
    let cardStyle = '';
    if (cat === 'theme') {
      cardStyle = `background:linear-gradient(145deg, ${meta.bg_primary}, ${meta.bg_secondary});border-color:${meta.sovereignAccent};`;
      visualHtml = `<span class="preview-badge" style="background:${meta.surfaceCard};color:${meta.sovereignAccent};border:1px solid ${meta.secondaryAccent};">معاينة الثيم الملكي</span>`;
    } else if (cat === 'frame') {
      visualHtml = `
        <div class="preview-frame-ring" style="border:3px solid ${meta.primaryColor};box-shadow:0 0 18px ${meta.highlightColor};background:linear-gradient(135deg, ${meta.primaryColor}22, ${meta.secondaryColor}33);">
          ${meta.hasCornerGems ? '💎' : '⚔️'}
        </div>
      `;
    } else {
      visualHtml = `<span class="preview-badge" style="background:${meta.previewColor}25;color:${meta.previewColor};border:1px solid ${meta.previewColor};">${cat === 'powerup' ? '⚡ قدرة' : '👑 وسام'}</span>`;
    }

    const priceTag = gems > 0 ? `💎 ${gems} ياقوتة` : `🪙 ${coins} دينار`;
    previewEl.innerHTML = `
      <div class="preview-dialog" style="${cardStyle}">
        ${visualHtml}
        <h3 style="margin:6px 0 4px;">${esc(title)}</h3>
        <p class="muted-text">${esc(desc)}</p>
        <div style="margin-top:10px;display:flex;justify-content:center;gap:8px;flex-wrap:wrap;">
          <span class="badge-pill">${priceTag}</span>
          <span class="${visible ? 'badge-visible' : 'badge-hidden'}">${visible ? 'مرئي بالمتجر' : 'مخفي عن الشراء'}</span>
        </div>
      </div>
    `;
  }

  function resetStoreForm() {
    cmsState.editingStoreId = null;
    document.getElementById('store-cms-form').reset();
    document.getElementById('st-id').readOnly = false;
    document.getElementById('store-form-heading').textContent = '🛒 إضافة / تعديل عنصر متجر';
    document.getElementById('st-coins').value = '500';
    document.getElementById('st-gems').value = '0';
    document.getElementById('st-min-level').value = '1';
    document.getElementById('st-sort').value = '100';
    document.getElementById('st-visible').checked = true;
    syncStoreMetadataPanels();
  }

  function populateStoreForm(item) {
    cmsState.editingStoreId = item.id;
    document.getElementById('store-form-heading').textContent = `✏️ تعديل: ${item.title}`;
    const idInput = document.getElementById('st-id');
    idInput.value = item.id ?? '';
    idInput.readOnly = true;
    document.getElementById('st-category').value = item.category ?? 'title';
    document.getElementById('st-title').value = item.title ?? '';
    document.getElementById('st-desc').value = item.description ?? '';
    document.getElementById('st-coins').value = item.price_coins ?? 0;
    document.getElementById('st-gems').value = item.price_gems ?? 0;
    document.getElementById('st-min-level').value = item.min_level ?? 1;
    document.getElementById('st-asset-key').value = item.asset_key ?? '';
    document.getElementById('st-sort').value = item.sort_order ?? 100;
    document.getElementById('st-visible').checked = item.is_visible !== false;

    const meta = item.metadata && typeof item.metadata === 'object' ? item.metadata : {};
    if (item.category === 'theme') {
      document.getElementById('st-th-bg1').value = safeHex(
        meta.deepBackground ?? meta.bg_primary,
        '#1a0b2e',
      ).toLowerCase();
      document.getElementById('st-th-bg2').value = safeHex(
        meta.bg_secondary ?? meta.surfaceCard,
        '#2d1b4e',
      ).toLowerCase();
      document.getElementById('st-th-card').value = safeHex(
        meta.surfaceCard ?? meta.surface_card,
        '#24143d',
      ).toLowerCase();
      document.getElementById('st-th-gold').value = safeHex(
        meta.sovereignAccent ?? meta.accent_gold,
        '#f3c644',
      ).toLowerCase();
      document.getElementById('st-th-sec').value = safeHex(
        meta.secondaryAccent ?? meta.accent_secondary,
        '#38bdf8',
      ).toLowerCase();
    } else if (item.category === 'frame') {
      document.getElementById('st-fr-c1').value = safeHex(
        meta.primaryColor ?? meta.primary_color,
        '#f3c644',
      ).toLowerCase();
      document.getElementById('st-fr-c2').value = safeHex(
        meta.secondaryColor ?? meta.secondary_color,
        '#10b981',
      ).toLowerCase();
      document.getElementById('st-fr-glow').value = safeHex(
        meta.highlightColor ?? meta.glow_color,
        '#f3c644',
      ).toLowerCase();
      document.getElementById('st-fr-pattern').value = meta.pattern_type || 'aurora';
      document.getElementById('st-fr-gems').checked =
        (meta.hasCornerGems ?? meta.show_gems) !== false;
    } else {
      document.getElementById('st-badge-color').value = safeHex(
        meta.previewColor ?? meta.sovereignAccent ?? meta.accent_color,
        '#f3c644',
      ).toLowerCase();
      document.getElementById('st-powerup-qty').value = meta.quantity ?? '';
    }
    syncStoreMetadataPanels();
  }

  async function loadStoreItems() {
    const client = sb();
    if (!client) return;
    const { data, error } = await client.rpc('admin_list_store_items');
    if (error) {
      toast(`تعذر تحميل عناصر المتجر: ${error.message}`, true);
      return;
    }
    cmsState.storeItems = Array.isArray(data) ? data : [];
    renderStoreItems();
  }

  function renderStoreItems() {
    const listEl = document.getElementById('store-items-list');
    const pillEl = document.getElementById('store-count-pill');
    if (!listEl || !pillEl) return;

    const filtered =
      cmsState.storeFilter === 'all'
        ? cmsState.storeItems
        : cmsState.storeItems.filter((it) => it.category === cmsState.storeFilter);
    pillEl.textContent = filtered.length;

    if (!filtered.length) {
      listEl.innerHTML = '<p class="muted-text">لا توجد عناصر في هذا التصنيف حالياً.</p>';
      return;
    }

    listEl.innerHTML = filtered
      .map((item) => {
        const vis = item.is_visible !== false;
        const priceStr =
          Number(item.price_gems || 0) > 0
            ? `💎 ${esc(item.price_gems)}`
            : `🪙 ${esc(item.price_coins ?? 0)}`;
        return `
          <article class="record-card">
            <div class="record-top">
              <div class="record-actions">
                <span class="badge-pill">${esc(item.category)}</span>
                <strong>${esc(item.title)}</strong>
                <span class="code-tag">${esc(item.id)}</span>
              </div>
              <div class="record-actions">
                <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
                <button class="btn btn-outline btn-sm" type="button" data-edit-store="${esc(item.id)}">تعديل</button>
                <label class="switch" title="إظهار / إخفاء">
                  <input type="checkbox" data-vis-store="${esc(item.id)}" ${vis ? 'checked' : ''} />
                  <span class="slider"></span>
                </label>
              </div>
            </div>
            <p class="muted-text">${esc(item.description || '')}</p>
            <div class="record-actions muted-text">
              <span>${priceStr}</span>
              <span>المستوى: ${esc(item.min_level ?? 1)}</span>
              <span>مراجعة #${esc(item.cms_revision ?? 1)}</span>
            </div>
          </article>
        `;
      })
      .join('');

    listEl.querySelectorAll('button[data-edit-store]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const found = cmsState.storeItems.find((i) => i.id === btn.dataset.editStore);
        if (found) populateStoreForm(found);
      });
    });
    listEl.querySelectorAll('input[data-vis-store]').forEach((input) => {
      input.addEventListener('change', () => {
        toggleEntityVisibility('store_item', input.dataset.visStore, input.checked, loadStoreItems);
      });
    });
  }

  async function handleSaveStoreItem(e) {
    e.preventDefault();
    const client = sb();
    if (!client) return;
    const id = document.getElementById('st-id').value.trim().toLowerCase();
    const category = document.getElementById('st-category').value;
    const title = document.getElementById('st-title').value.trim();
    const description = document.getElementById('st-desc').value.trim();
    const priceCoins = Number.parseInt(document.getElementById('st-coins').value || '0', 10) || 0;
    const priceGems = Number.parseInt(document.getElementById('st-gems').value || '0', 10) || 0;
    const minLevel = Number.parseInt(document.getElementById('st-min-level').value || '1', 10) || 1;
    const assetKey = document.getElementById('st-asset-key').value.trim();
    const sortOrder = Number.parseInt(document.getElementById('st-sort').value || '100', 10) || 100;
    const isVisible = document.getElementById('st-visible').checked;

    if (!/^[a-z0-9_]{3,64}$/.test(id)) {
      toast('معرّف العنصر يجب أن يحتوي 3..64 حرفاً إنجليزياً صغيراً أو أرقاماً أو _.', true);
      return;
    }

    const btn = document.getElementById('btn-save-store-item');
    btn.disabled = true;
    try {
      const { error } = await client.rpc('admin_upsert_store_item', {
        p_id: id,
        p_title: title,
        p_description: description,
        p_category: category,
        p_price_coins: priceCoins,
        p_price_gems: priceGems,
        p_min_level: minLevel,
        p_asset_key: assetKey,
        p_is_visible: isVisible,
        p_sort_order: sortOrder,
        p_metadata: collectStoreMetadata(category),
      });
      if (error) throw error;
      toast('تم حفظ عنصر المتجر وتحديث الكتالوغ السحابي ✅');
      resetStoreForm();
      await Promise.all([loadStoreItems(), bumpOverview(), loadAuditLogs()]);
    } catch (err) {
      toast(`فشل حفظ العنصر: ${err.message}`, true);
    } finally {
      btn.disabled = false;
    }
  }

  // ==================== LIBRARY CMS ====================

  async function loadLibraryContent() {
    const client = sb();
    if (!client) return;
    const filterSec = document.getElementById('lib-filter-section')?.value || null;
    const { data, error } = await client.rpc('admin_list_library_content', {
      p_section_id: filterSec || null,
    });
    if (error) {
      toast(`تعذر تحميل المكتبة السحابية: ${error.message}`, true);
      return;
    }
    cmsState.libSections = Array.isArray(data?.sections) ? data.sections : [];
    cmsState.libItems = Array.isArray(data?.items) ? data.items : [];
    populateLibrarySelects();
    renderLibrarySections();
    renderLibraryItems();
  }

  function populateLibrarySelects() {
    const itemSecSel = document.getElementById('lib-item-section');
    const filterSel = document.getElementById('lib-filter-section');
    if (!itemSecSel || !filterSel) return;

    const prevItemSec = itemSecSel.value;
    const prevFilter = filterSel.value;

    itemSecSel.innerHTML = cmsState.libSections
      .map((s) => `<option value="${esc(s.id)}">${esc(s.title)} (${esc(s.id)})</option>`)
      .join('');
    if (prevItemSec && cmsState.libSections.some((s) => s.id === prevItemSec)) {
      itemSecSel.value = prevItemSec;
    }

    filterSel.innerHTML =
      '<option value="">كل الأقسام</option>' +
      cmsState.libSections
        .map((s) => `<option value="${esc(s.id)}">${esc(s.title)}</option>`)
        .join('');
    filterSel.value = prevFilter;
  }

  function renderLibrarySections() {
    const listEl = document.getElementById('lib-sections-list');
    document.getElementById('lib-sec-count').textContent = cmsState.libSections.length;
    if (!cmsState.libSections.length) {
      listEl.innerHTML = '<p class="muted-text">لا توجد أقسام مكتبة.</p>';
      return;
    }
    listEl.innerHTML = cmsState.libSections
      .map((sec) => {
        const vis = sec.is_visible !== false;
        const hex = safeHex(sec.color_hex, '#D4AF37');
        return `
          <article class="record-card" style="border-right:3px solid ${hex};">
            <div class="record-top">
              <div class="record-actions">
                <strong>${esc(sec.title)}</strong>
                <span class="code-tag">${esc(sec.id)}</span>
                <span class="muted-text">• ${esc(sec.items_count ?? 0)} عنصر</span>
              </div>
              <div class="record-actions">
                <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
                <button class="btn btn-outline btn-sm" type="button" data-edit-lib-sec="${esc(sec.id)}">تعديل</button>
                <label class="switch">
                  <input type="checkbox" data-vis-lib-sec="${esc(sec.id)}" ${vis ? 'checked' : ''} />
                  <span class="slider"></span>
                </label>
              </div>
            </div>
          </article>
        `;
      })
      .join('');

    listEl.querySelectorAll('button[data-edit-lib-sec]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const sec = cmsState.libSections.find((s) => s.id === btn.dataset.editLibSec);
        if (!sec) return;
        document.getElementById('lib-sec-id').value = sec.id;
        document.getElementById('lib-sec-id').readOnly = true;
        document.getElementById('lib-sec-title').value = sec.title ?? '';
        document.getElementById('lib-sec-icon').value = sec.icon_name ?? 'auto_stories_rounded';
        const hex = safeHex(sec.color_hex, '#D4AF37');
        document.getElementById('lib-sec-color').value = hex;
        document.getElementById('lib-sec-color-picker').value = hex.toLowerCase();
        document.getElementById('lib-sec-sort').value = sec.sort_order ?? 10;
        document.getElementById('lib-sec-visible').checked = sec.is_visible !== false;
        document.getElementById('lib-sec-heading').textContent = `✏️ تعديل قسم: ${sec.title}`;
      });
    });
    listEl.querySelectorAll('input[data-vis-lib-sec]').forEach((input) => {
      input.addEventListener('change', () => {
        toggleEntityVisibility(
          'library_section',
          input.dataset.visLibSec,
          input.checked,
          loadLibraryContent,
        );
      });
    });
  }

  function renderLibraryItems() {
    const listEl = document.getElementById('lib-items-list');
    if (!cmsState.libItems.length) {
      listEl.innerHTML = '<p class="muted-text">لا توجد عناصر سحابية مضافة في هذا القسم بعد.</p>';
      return;
    }
    listEl.innerHTML = cmsState.libItems
      .map((item) => {
        const vis = item.is_visible !== false;
        return `
          <article class="record-card">
            <div class="record-top">
              <div class="record-actions">
                <span class="badge-pill">${esc(item.section_id)}</span>
                <strong>${esc(item.title)}</strong>
              </div>
              <div class="record-actions">
                <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
                <button class="btn btn-outline btn-sm" type="button" data-edit-lib-item="${esc(item.id)}">تعديل</button>
                <label class="switch">
                  <input type="checkbox" data-vis-lib-item="${esc(item.id)}" ${vis ? 'checked' : ''} />
                  <span class="slider"></span>
                </label>
              </div>
            </div>
            ${item.subtitle ? `<div class="gold-text muted-text">${esc(item.subtitle)}</div>` : ''}
            <p class="muted-text">${esc((item.content || '').slice(0, 140))}${(item.content || '').length > 140 ? '…' : ''}</p>
            ${item.source_ref ? `<span class="muted-text">📚 المصدر: ${esc(item.source_ref)}</span>` : ''}
          </article>
        `;
      })
      .join('');

    listEl.querySelectorAll('button[data-edit-lib-item]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const item = cmsState.libItems.find((i) => i.id === btn.dataset.editLibItem);
        if (!item) return;
        document.getElementById('lib-item-id').value = item.id;
        document.getElementById('lib-item-section').value = item.section_id ?? '';
        document.getElementById('lib-item-title').value = item.title ?? '';
        document.getElementById('lib-item-subtitle').value = item.subtitle ?? '';
        document.getElementById('lib-item-content').value = item.content ?? '';
        document.getElementById('lib-item-source').value = item.source_ref ?? '';
        document.getElementById('lib-item-sort').value = item.sort_order ?? 10;
        document.getElementById('lib-item-visible').checked = item.is_visible !== false;
        document.getElementById('lib-item-heading').textContent = `✏️ تعديل بطاقة: ${item.title}`;
      });
    });
    listEl.querySelectorAll('input[data-vis-lib-item]').forEach((input) => {
      input.addEventListener('change', () => {
        toggleEntityVisibility(
          'library_item',
          input.dataset.visLibItem,
          input.checked,
          loadLibraryContent,
        );
      });
    });
  }

  async function handleSaveLibSection(e) {
    e.preventDefault();
    const client = sb();
    if (!client) return;
    const btn = document.getElementById('btn-save-lib-sec');
    btn.disabled = true;
    try {
      const { error } = await client.rpc('admin_upsert_library_section', {
        p_id: document.getElementById('lib-sec-id').value.trim().toLowerCase(),
        p_title: document.getElementById('lib-sec-title').value.trim(),
        p_icon_name: document.getElementById('lib-sec-icon').value,
        p_color_hex: safeHex(document.getElementById('lib-sec-color').value),
        p_sort_order: Number.parseInt(document.getElementById('lib-sec-sort').value || '10', 10) || 10,
        p_is_visible: document.getElementById('lib-sec-visible').checked,
      });
      if (error) throw error;
      toast('تم حفظ قسم المكتبة ✅');
      document.getElementById('lib-section-form').reset();
      document.getElementById('lib-sec-id').readOnly = false;
      document.getElementById('lib-sec-visible').checked = true;
      document.getElementById('lib-sec-heading').textContent = '🗂️ قسم مكتبة (إضافة / تعديل)';
      await Promise.all([loadLibraryContent(), bumpOverview(), loadAuditLogs()]);
    } catch (err) {
      toast(`فشل حفظ القسم: ${err.message}`, true);
    } finally {
      btn.disabled = false;
    }
  }

  async function handleSaveLibItem(e) {
    e.preventDefault();
    const client = sb();
    if (!client) return;
    const btn = document.getElementById('btn-save-lib-item');
    btn.disabled = true;
    try {
      const idRaw = document.getElementById('lib-item-id').value.trim();
      const { error } = await client.rpc('admin_upsert_library_item', {
        p_id: idRaw || null,
        p_section_id: document.getElementById('lib-item-section').value,
        p_title: document.getElementById('lib-item-title').value.trim(),
        p_subtitle: document.getElementById('lib-item-subtitle').value.trim(),
        p_content: document.getElementById('lib-item-content').value.trim(),
        p_source_ref: document.getElementById('lib-item-source').value.trim(),
        p_sort_order: Number.parseInt(document.getElementById('lib-item-sort').value || '10', 10) || 10,
        p_is_visible: document.getElementById('lib-item-visible').checked,
      });
      if (error) throw error;
      toast('تم حفظ عنصر المكتبة ✅');
      document.getElementById('lib-item-form').reset();
      document.getElementById('lib-item-id').value = '';
      document.getElementById('lib-item-visible').checked = true;
      document.getElementById('lib-item-heading').textContent = '📝 مقال / قصة / بطاقة معرفة';
      await Promise.all([loadLibraryContent(), bumpOverview(), loadAuditLogs()]);
    } catch (err) {
      toast(`فشل حفظ العنصر: ${err.message}`, true);
    } finally {
      btn.disabled = false;
    }
  }

  // ==================== QUIZ CMS ====================

  async function loadQuizContent() {
    const client = sb();
    if (!client) return;
    const cat = document.getElementById('quiz-filter-cat')?.value || null;
    const lvlRaw = document.getElementById('quiz-filter-level')?.value.trim();
    const lvl = lvlRaw ? Number.parseInt(lvlRaw, 10) : null;
    const { data, error } = await client.rpc('admin_list_quiz_content', {
      p_category_id: cat || null,
      p_level_number: Number.isFinite(lvl) ? lvl : null,
      p_limit: 120,
    });
    if (error) {
      toast(`تعذر تحميل المسابقات والأسئلة: ${error.message}`, true);
      return;
    }
    cmsState.quizCategories = Array.isArray(data?.categories) ? data.categories : [];
    cmsState.quizQuestions = Array.isArray(data?.questions) ? data.questions : [];
    populateQuizSelects();
    renderQuizCategories();
    renderQuizQuestions();
  }

  function populateQuizSelects() {
    const qCatSel = document.getElementById('qz-q-cat');
    const filterSel = document.getElementById('quiz-filter-cat');
    if (!qCatSel || !filterSel) return;

    const prevQCat = qCatSel.value;
    const prevFilter = filterSel.value;

    qCatSel.innerHTML = cmsState.quizCategories
      .map((c) => `<option value="${esc(c.id)}">${esc(c.name)} (${esc(c.total_levels ?? 10)} مراحل)</option>`)
      .join('');
    if (prevQCat && cmsState.quizCategories.some((c) => c.id === prevQCat)) {
      qCatSel.value = prevQCat;
    }

    filterSel.innerHTML =
      '<option value="">كل الأقسام</option>' +
      cmsState.quizCategories
        .map((c) => `<option value="${esc(c.id)}">${esc(c.name)}</option>`)
        .join('');
    filterSel.value = prevFilter;
  }

  function renderQuizCategories() {
    const listEl = document.getElementById('quiz-categories-list');
    document.getElementById('quiz-cat-count').textContent = cmsState.quizCategories.length;
    if (!cmsState.quizCategories.length) {
      listEl.innerHTML = '<p class="muted-text">لا توجد أقسام مسابقات.</p>';
      return;
    }
    listEl.innerHTML = cmsState.quizCategories
      .map((cat) => {
        const vis = cat.is_visible !== false;
        const hex = safeHex(cat.color_hex, '#1B5E20');
        return `
          <article class="record-card" style="border-right:3px solid ${hex};">
            <div class="record-top">
              <div class="record-actions">
                <strong>${esc(cat.name)}</strong>
                <span class="code-tag">${esc(cat.id)}</span>
                <span class="muted-text">• ${esc(cat.total_levels ?? 10)} مستوى</span>
                <span class="muted-text">• ${esc(cat.custom_questions_count ?? 0)} سؤال سحابي</span>
                ${cat.is_locked ? '<span class="badge-hidden">مقفل</span>' : ''}
              </div>
              <div class="record-actions">
                <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
                <button class="btn btn-outline btn-sm" type="button" data-edit-qz-cat="${esc(cat.id)}">تعديل</button>
                <label class="switch">
                  <input type="checkbox" data-vis-qz-cat="${esc(cat.id)}" ${vis ? 'checked' : ''} />
                  <span class="slider"></span>
                </label>
              </div>
            </div>
          </article>
        `;
      })
      .join('');

    listEl.querySelectorAll('button[data-edit-qz-cat]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const cat = cmsState.quizCategories.find((c) => c.id === btn.dataset.editQzCat);
        if (!cat) return;
        document.getElementById('qz-cat-id').value = cat.id;
        document.getElementById('qz-cat-id').readOnly = true;
        document.getElementById('qz-cat-name').value = cat.name ?? '';
        document.getElementById('qz-cat-desc').value = cat.description ?? '';
        document.getElementById('qz-cat-levels').value = cat.total_levels ?? 10;
        document.getElementById('qz-cat-icon').value = cat.icon_name ?? 'quiz_rounded';
        const hex = safeHex(cat.color_hex, '#1B5E20');
        document.getElementById('qz-cat-color').value = hex;
        document.getElementById('qz-cat-color-picker').value = hex.toLowerCase();
        document.getElementById('qz-cat-sort').value = cat.sort_order ?? 10;
        document.getElementById('qz-cat-visible').checked = cat.is_visible !== false;
        document.getElementById('qz-cat-locked').checked = Boolean(cat.is_locked);
        document.getElementById('quiz-cat-heading').textContent = `✏️ تعديل قسم: ${cat.name}`;
      });
    });
    listEl.querySelectorAll('input[data-vis-qz-cat]').forEach((input) => {
      input.addEventListener('change', () => {
        toggleEntityVisibility(
          'quiz_category',
          input.dataset.visQzCat,
          input.checked,
          loadQuizContent,
        );
      });
    });
  }

  function renderQuizQuestions() {
    const listEl = document.getElementById('quiz-questions-list');
    if (!cmsState.quizQuestions.length) {
      listEl.innerHTML = '<p class="muted-text">لا توجد أسئلة سحابية مطابقة للتصفية الحالية.</p>';
      return;
    }
    listEl.innerHTML = cmsState.quizQuestions
      .map((q) => {
        const vis = q.is_visible !== false;
        const opts = Array.isArray(q.options) ? q.options : [];
        const ansText = opts[q.correct_index] ?? '';
        return `
          <article class="record-card">
            <div class="record-top">
              <div class="record-actions">
                <span class="badge-pill">${esc(q.category_id)} • م${esc(q.level_number)}</span>
                <span class="code-tag">${esc(q.sync_scope || 'solo_only')}</span>
              </div>
              <div class="record-actions">
                <span class="${vis ? 'badge-visible' : 'badge-hidden'}">${vis ? 'مرئي' : 'مخفي'}</span>
                <button class="btn btn-outline btn-sm" type="button" data-edit-qz-q="${esc(q.id)}">تعديل</button>
                <label class="switch">
                  <input type="checkbox" data-vis-qz-q="${esc(q.id)}" ${vis ? 'checked' : ''} />
                  <span class="slider"></span>
                </label>
              </div>
            </div>
            <strong>${esc(q.question_text)}</strong>
            <div class="muted-text">✅ الصحيح (${esc(q.correct_index)}): ${esc(ansText)}</div>
          </article>
        `;
      })
      .join('');

    listEl.querySelectorAll('button[data-edit-qz-q]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const q = cmsState.quizQuestions.find((item) => item.id === btn.dataset.editQzQ);
        if (!q) return;
        const opts = Array.isArray(q.options) ? q.options : ['', '', '', ''];
        document.getElementById('qz-q-id').value = q.id;
        document.getElementById('qz-q-cat').value = q.category_id ?? 'quran';
        document.getElementById('qz-q-level').value = q.level_number ?? 1;
        document.getElementById('qz-q-scope').value = q.sync_scope || 'solo_only';
        document.getElementById('qz-q-text').value = q.question_text ?? '';
        document.getElementById('qz-opt-0').value = opts[0] ?? '';
        document.getElementById('qz-opt-1').value = opts[1] ?? '';
        document.getElementById('qz-opt-2').value = opts[2] ?? '';
        document.getElementById('qz-opt-3').value = opts[3] ?? '';
        document.getElementById('qz-q-correct').value = String(q.correct_index ?? 0);
        document.getElementById('qz-q-sort').value = q.sort_order ?? 10;
        document.getElementById('qz-q-exp').value = q.explanation ?? '';
        document.getElementById('qz-q-visible').checked = q.is_visible !== false;
        document.getElementById('quiz-q-heading').textContent = '✏️ تعديل سؤال سحابي';
      });
    });
    listEl.querySelectorAll('input[data-vis-qz-q]').forEach((input) => {
      input.addEventListener('change', () => {
        toggleEntityVisibility(
          'quiz_question',
          input.dataset.visQzQ,
          input.checked,
          loadQuizContent,
        );
      });
    });
  }

  async function handleSaveQuizCategory(e) {
    e.preventDefault();
    const client = sb();
    if (!client) return;
    const btn = document.getElementById('btn-save-quiz-cat');
    btn.disabled = true;
    try {
      const { error } = await client.rpc('admin_upsert_quiz_category', {
        p_id: document.getElementById('qz-cat-id').value.trim().toLowerCase(),
        p_name: document.getElementById('qz-cat-name').value.trim(),
        p_description: document.getElementById('qz-cat-desc').value.trim(),
        p_icon_name: document.getElementById('qz-cat-icon').value,
        p_color_hex: safeHex(document.getElementById('qz-cat-color').value, '#1B5E20'),
        p_total_levels: Number.parseInt(document.getElementById('qz-cat-levels').value || '10', 10) || 10,
        p_sort_order: Number.parseInt(document.getElementById('qz-cat-sort').value || '10', 10) || 10,
        p_is_visible: document.getElementById('qz-cat-visible').checked,
        p_is_locked: document.getElementById('qz-cat-locked').checked,
      });
      if (error) throw error;
      toast('تم حفظ قسم المسابقة ✅');
      document.getElementById('quiz-category-form').reset();
      document.getElementById('qz-cat-id').readOnly = false;
      document.getElementById('qz-cat-levels').value = '10';
      document.getElementById('qz-cat-visible').checked = true;
      document.getElementById('quiz-cat-heading').textContent = '🏆 قسم مسابقة (إضافة / تعديل)';
      await Promise.all([loadQuizContent(), bumpOverview(), loadAuditLogs()]);
    } catch (err) {
      toast(`فشل حفظ القسم: ${err.message}`, true);
    } finally {
      btn.disabled = false;
    }
  }

  async function handleSaveQuizQuestion(e) {
    e.preventDefault();
    const client = sb();
    if (!client) return;
    const options = [
      document.getElementById('qz-opt-0').value.trim(),
      document.getElementById('qz-opt-1').value.trim(),
      document.getElementById('qz-opt-2').value.trim(),
      document.getElementById('qz-opt-3').value.trim(),
    ];
    if (options.some((o) => !o)) {
      toast('جميع الخيارات الأربعة مطلوبة ولا يمكن ترك أي خيار فارغاً.', true);
      return;
    }
    const btn = document.getElementById('btn-save-quiz-q');
    btn.disabled = true;
    try {
      const idRaw = document.getElementById('qz-q-id').value.trim();
      const { error } = await client.rpc('admin_upsert_quiz_question', {
        p_id: idRaw || null,
        p_category_id: document.getElementById('qz-q-cat').value,
        p_level_number: Number.parseInt(document.getElementById('qz-q-level').value || '1', 10) || 1,
        p_question_text: document.getElementById('qz-q-text').value.trim(),
        p_options: options,
        p_correct_index: Number.parseInt(document.getElementById('qz-q-correct').value || '0', 10) || 0,
        p_explanation: document.getElementById('qz-q-exp').value.trim(),
        p_sync_scope: document.getElementById('qz-q-scope').value,
        p_sort_order: Number.parseInt(document.getElementById('qz-q-sort').value || '10', 10) || 10,
        p_is_visible: document.getElementById('qz-q-visible').checked,
      });
      if (error) throw error;
      toast('تم حفظ السؤال السحابي بنجاح ✅');
      document.getElementById('quiz-question-form').reset();
      document.getElementById('qz-q-id').value = '';
      document.getElementById('qz-q-level').value = '1';
      document.getElementById('qz-q-visible').checked = true;
      document.getElementById('quiz-q-heading').textContent = '❓ إضافة / تعديل سؤال سحابي';
      await Promise.all([loadQuizContent(), bumpOverview(), loadAuditLogs()]);
    } catch (err) {
      toast(`فشل حفظ السؤال: ${err.message}`, true);
    } finally {
      btn.disabled = false;
    }
  }

  // ==================== PLAYERS INSPECTOR, COMPENSATION & CSV ====================

  async function searchPlayersForInspector() {
    const client = sb();
    if (!client) return;
    const q = document.getElementById('player-inspector-query').value.trim();
    const { data, error } = await client.rpc('admin_search_users', {
      p_query: q,
      p_limit: 50,
    });
    if (error) {
      toast(`تعذر جلب اللاعبين: ${error.message}`, true);
      return;
    }
    cmsState.playerSearchRows = Array.isArray(data) ? data : [];
    renderInspectorList();
  }

  function renderInspectorList() {
    const listEl = document.getElementById('inspector-results-list');
    if (!cmsState.playerSearchRows.length) {
      listEl.innerHTML = '<p class="muted-text">لا توجد نتائج مطابقة.</p>';
      return;
    }
    listEl.innerHTML = cmsState.playerSearchRows
      .map((p, idx) => {
        const badge = p.is_guest ? 'ضيف 🎭' : esc(p.email || 'Google');
        return `
          <article class="record-card">
            <div class="record-top">
              <div>
                <strong>${esc(p.display_name || 'لاعب')}</strong>
                <div class="muted-text">${badge} ${p.player_code ? `• ${esc(p.player_code)}` : ''}</div>
              </div>
              <button class="btn btn-outline btn-sm" type="button" data-open-dossier="${idx}">فحص الملف</button>
            </div>
            <div class="record-actions muted-text">
              <span>🏆 ${esc(p.trophies ?? 1000)}</span>
              <span>⭐ م${esc(p.player_level ?? 1)}</span>
              <span>نقاط ${esc(p.total_score ?? 0)}</span>
              <span>${esc(p.app_version || '—')}</span>
            </div>
          </article>
        `;
      })
      .join('');

    listEl.querySelectorAll('button[data-open-dossier]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const row = cmsState.playerSearchRows[Number(btn.dataset.openDossier)];
        if (row) loadPlayerDetail(row.user_id || null, row.player_code || null, row.display_name);
      });
    });
  }

  async function loadPlayerDetail(userId, playerCode, fallbackName = 'لاعب') {
    const client = sb();
    if (!client) return;
    const { data, error } = await client.rpc('admin_get_player_detail', {
      p_user_id: userId || null,
      p_player_code: playerCode || null,
    });
    if (error) {
      toast(`تعذر فتح ملف اللاعب: ${error.message}`, true);
      return;
    }
    cmsState.currentPlayerDetail = data;
    renderPlayerDossier(data, fallbackName);
  }

  function renderPlayerDossier(d, fallbackName) {
    const box = document.getElementById('player-dossier-card');
    const msgBtn = document.getElementById('btn-target-player-msg');
    const compUid = document.getElementById('comp-user-id');
    const compLbl = document.getElementById('comp-target-label');
    const compBtn = document.getElementById('btn-grant-compensation');

    const dir = d?.directory || {};
    const prog = d?.progress || {};
    const lb = d?.leaderboard || {};
    const inv = Array.isArray(d?.inventory) ? d.inventory : [];
    const matches = Array.isArray(d?.recent_matches) ? d.recent_matches : [];
    const name = dir.display_name || lb.display_name || fallbackName;
    const hasUid = Boolean(d?.user_id);

    msgBtn.classList.toggle('hidden', !hasUid && !d?.player_code);
    if (hasUid) {
      compUid.value = d.user_id;
      compLbl.textContent = `🎯 المستهدف للتعويض: ${name} (${d.user_id.slice(0, 8)}…)`;
      compLbl.classList.remove('hidden');
      compBtn.disabled = !prog || Object.keys(prog).length === 0;
    } else {
      compUid.value = '';
      compLbl.textContent = '⚠️ حساب ضيف غير مربوط بحساب سحابي (التعويض يتطلب user_progress مسجّلاً)';
      compLbl.classList.remove('hidden');
      compBtn.disabled = true;
    }

    const invHtml = inv.length
      ? inv
          .map(
            (i) =>
              `<span class="code-tag">${esc(i.title || i.item_id)}${i.is_visible === false ? ' (مخفي)' : ''}</span>`,
          )
          .join(' ')
      : '<span class="muted-text">لا توجد مقتنيات متجر مسجلة</span>';

    const matchesHtml = matches.length
      ? matches
          .slice(0, 5)
          .map(
            (m) =>
              `<div class="muted-text">• ${m.is_ghost_match ? '👻' : '⚔️'} نتيجة ${esc(m.my_score ?? 0)} (${esc(m.status)}) — ${esc(fmtDate(m.created_at))}</div>`,
          )
          .join('')
      : '<div class="muted-text">لا توجد نزالات حديثة</div>';

    box.innerHTML = `
      <div><strong>${esc(name)}</strong> ${d?.player_code ? `<span class="code-tag">${esc(d.player_code)}</span>` : ''}</div>
      <div class="muted-text">${esc(dir.email || lb.email || 'ضيف محلي')} • آخر ظهور: ${esc(fmtDate(dir.last_seen_at))} • نسخة ${esc(dir.app_version || '—')} (b${esc(dir.version_code ?? '?')})</div>
      <div class="dossier-grid">
        <div class="stat-chip"><span class="muted-text">المستوى</span><strong>م${esc(prog.player_level ?? lb.player_level ?? 1)}</strong></div>
        <div class="stat-chip"><span class="muted-text">النقاط XP</span><strong>${esc(prog.total_score ?? lb.score ?? 0)}</strong></div>
        <div class="stat-chip"><span class="muted-text">الكؤوس</span><strong>🏆 ${esc(lb.trophies ?? dir.trophies ?? 1000)}</strong></div>
        <div class="stat-chip"><span class="muted-text">الدنانير</span><strong>🪙 ${esc(prog.coins ?? 0)}</strong></div>
        <div class="stat-chip"><span class="muted-text">الياقوت</span><strong>💎 ${esc(prog.gems ?? 0)}</strong></div>
        <div class="stat-chip"><span class="muted-text">السلسلة</span><strong>🔥 ${esc(prog.win_streak ?? 0)}</strong></div>
      </div>
      <div class="mb-md"><strong>المقتنيات (${inv.length}):</strong><div class="record-actions mt-xs">${invHtml}</div></div>
      <div><strong>آخر النزالات:</strong>${matchesHtml}</div>
    `;
  }

  async function handleGrantCompensation(e) {
    e.preventDefault();
    const client = sb();
    if (!client) return;
    const uid = document.getElementById('comp-user-id').value.trim();
    const coins = Number.parseInt(document.getElementById('comp-coins').value || '0', 10) || 0;
    const gems = Number.parseInt(document.getElementById('comp-gems').value || '0', 10) || 0;
    const xp = Number.parseInt(document.getElementById('comp-xp').value || '0', 10) || 0;
    const reason = document.getElementById('comp-reason').value.trim();

    if (!uid) {
      toast('اختر لاعباً مسجّلاً أولاً.', true);
      return;
    }
    if (coins < 0 || coins > 10000 || gems < 0 || gems > 100 || xp < 0 || xp > 5000) {
      toast('تجاوزت الحدود القصوى المسموحة للتعويض (10000 دنانير / 100 ياقوت / 5000 خبرة).', true);
      return;
    }
    if (coins === 0 && gems === 0 && xp === 0) {
      toast('أدخل قيمة واحدة على الأقل للتعويض.', true);
      return;
    }
    if (reason.length < 3) {
      toast('يجب كتابة سبب واضح للتعويض (3 أحرف على الأقل).', true);
      return;
    }
    if (
      !window.confirm(
        `تأكيد منح تعويض: 🪙 ${coins} | 💎 ${gems} | ⭐ ${xp}\nالسبب: ${reason}`,
      )
    ) {
      return;
    }

    const btn = document.getElementById('btn-grant-compensation');
    btn.disabled = true;
    try {
      const { error } = await client.rpc('admin_grant_player_compensation', {
        p_user_id: uid,
        p_coins_delta: coins,
        p_gems_delta: gems,
        p_xp_delta: xp,
        p_reason: reason,
      });
      if (error) throw error;
      toast('تم منح التعويض وتوثيقه في سجل التدقيق ✅');
      document.getElementById('comp-coins').value = '0';
      document.getElementById('comp-gems').value = '0';
      document.getElementById('comp-xp').value = '0';
      document.getElementById('comp-reason').value = '';
      await Promise.all([loadPlayerDetail(uid, null), loadAuditLogs(), bumpOverview()]);
    } catch (err) {
      toast(`فشل منح التعويض: ${err.message}`, true);
    } finally {
      btn.disabled = false;
    }
  }

  function safeCsvCell(raw) {
    let s = String(raw ?? '').replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (/^[=+\-@\t]/.test(s)) {
      s = `'${s}`;
    }
    return `"${s.replaceAll('"', '""')}"`;
  }

  function exportPlayersCsv() {
    if (!cmsState.playerSearchRows.length) {
      toast('قم بالبحث أو تحميل قائمة اللاعبين أولاً قبل التصدير.', true);
      return;
    }
    const headers = [
      'display_name',
      'player_code',
      'email',
      'is_guest',
      'player_level',
      'trophies',
      'total_score',
      'app_version',
      'platform',
      'last_seen_at',
    ];
    const lines = [headers.join(',')];
    for (const row of cmsState.playerSearchRows) {
      lines.push(headers.map((h) => safeCsvCell(row[h])).join(','));
    }
    const blob = new Blob([`\uFEFF${lines.join('\n')}`], {
      type: 'text/csv;charset=utf-8;',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sahaba_players_${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
    toast('تم تصدير ملف CSV الآمن بنجاح 📥');
  }

  // ==================== GHOSTS, AUDIT LOGS & ADMINS ====================

  async function loadGhosts() {
    const client = sb();
    if (!client) return;
    const { data, error } = await client.rpc('admin_list_ghosts', { p_limit: 50 });
    if (error) {
      toast(`تعذر تحميل الأشباح: ${error.message}`, true);
      return;
    }
    cmsState.ghosts = Array.isArray(data) ? data : [];
    const pill = document.getElementById('ghosts-count-pill');
    const listEl = document.getElementById('ghosts-list');
    pill.textContent = cmsState.ghosts.length;
    if (!cmsState.ghosts.length) {
      listEl.innerHTML = '<p class="muted-text">لا توجد تسجيلات أشباح بعد.</p>';
      return;
    }
    listEl.innerHTML = cmsState.ghosts
      .map((g) => {
        const active = g.is_active !== false;
        return `
          <article class="record-card">
            <div class="record-top">
              <div class="record-actions">
                <span class="badge-pill">${g.is_human ? 'شبح لاعب بشري 👤' : 'شبح اصطناعي 🤖'}</span>
                <strong>${esc(g.display_name || 'شبح')}</strong>
              </div>
              <label class="switch">
                <input type="checkbox" data-toggle-ghost="${esc(g.id)}" ${active ? 'checked' : ''} />
                <span class="slider"></span>
              </label>
            </div>
            <div class="record-actions muted-text">
              <span>م${esc(g.player_level ?? 1)}</span>
              <span>🏆 ${esc(g.trophies ?? 1000)}</span>
              <span>نقاط ${esc(g.total_score ?? 0)}</span>
              <span>استخدامات: ${esc(g.use_count ?? 0)}</span>
            </div>
          </article>
        `;
      })
      .join('');

    listEl.querySelectorAll('input[data-toggle-ghost]').forEach((input) => {
      input.addEventListener('change', async () => {
        const { error: tErr } = await client.rpc('admin_toggle_ghost', {
          p_ghost_id: input.dataset.toggleGhost,
          p_is_active: input.checked,
        });
        if (tErr) {
          toast(`تعذر تحديث الشبح: ${tErr.message}`, true);
          await loadGhosts();
          return;
        }
        toast(input.checked ? 'تم تفعيل الشبح ✅' : 'تم إيقاف الشبح ⏸️');
        await Promise.all([loadGhosts(), bumpOverview(), loadAuditLogs()]);
      });
    });
  }

  async function loadAuditLogs() {
    const client = sb();
    if (!client) return;
    const { data, error } = await client.rpc('admin_list_audit_logs', { p_limit: 60 });
    if (error) {
      toast(`تعذر تحميل سجل التدقيق: ${error.message}`, true);
      return;
    }
    cmsState.auditLogs = Array.isArray(data) ? data : [];
    const pill = document.getElementById('audit-count-pill');
    const listEl = document.getElementById('audit-logs-list');
    pill.textContent = cmsState.auditLogs.length;
    if (!cmsState.auditLogs.length) {
      listEl.innerHTML = '<p class="muted-text">سجل التدقيق نظيف ولم تُسجّل إجراءات CMS بعد.</p>';
      return;
    }
    listEl.innerHTML = cmsState.auditLogs
      .map(
        (log) => `
        <article class="record-card">
          <div class="record-top">
            <div class="record-actions">
              <span class="badge-pill">${esc(log.action)}</span>
              <span class="code-tag">${esc(log.target_type)}: ${esc(log.target_id)}</span>
            </div>
            <span class="muted-text">${esc(fmtDate(log.created_at))}</span>
          </div>
          <div>${esc(log.reason || '—')}</div>
          <div class="muted-text">المنفّذ: ${esc(log.admin_email || 'system')}</div>
        </article>
      `,
      )
      .join('');
  }

  async function loadAdminsRoster() {
    const client = sb();
    if (!client) return;
    const { data, error } = await client.rpc('admin_list_admins');
    if (error) {
      toast(`تعذر تحميل طاقم المشرفين: ${error.message}`, true);
      return;
    }
    cmsState.adminsMeta = data || { is_owner: false, admins: [] };
    const isOwner = Boolean(cmsState.adminsMeta.is_owner);
    const admins = Array.isArray(cmsState.adminsMeta.admins) ? cmsState.adminsMeta.admins : [];

    document.getElementById('admins-role-pill').textContent = isOwner ? 'المالك (Owner)' : 'مشرف (Admin)';
    document.getElementById('admins-owner-note').textContent = isOwner
      ? 'بصفتك المالك، يمكنك إضافة المشرفين أو ترقيتهم أو سحب صلاحيتهم بأمان.'
      : 'وضع العرض فقط — إضافة أو إزالة المشرفين محصورة لصلاحية المالك (Owner).';
    document.getElementById('admin-manage-form').classList.toggle('hidden', !isOwner);

    const listEl = document.getElementById('admins-list');
    listEl.innerHTML = admins
      .map(
        (a) => `
        <article class="record-card">
          <div class="record-top">
            <div>
              <strong>${esc(a.email)}</strong>
              <span class="badge-pill">${esc(a.role || 'admin')}</span>
            </div>
            ${
              isOwner
                ? `<button class="btn btn-danger-outline btn-sm" type="button" data-remove-admin="${esc(a.email)}">إزالة</button>`
                : ''
            }
          </div>
        </article>
      `,
      )
      .join('');

    if (isOwner) {
      listEl.querySelectorAll('button[data-remove-admin]').forEach((btn) => {
        btn.addEventListener('click', async () => {
          const email = btn.dataset.removeAdmin;
          if (!window.confirm(`هل تريد إزالة صلاحية الإشراف عن ${email}؟`)) return;
          const { error: rErr } = await client.rpc('admin_manage_admin', {
            p_action: 'remove',
            p_email: email,
          });
          if (rErr) {
            toast(`تعذر الإزالة: ${rErr.message}`, true);
            return;
          }
          toast('تم تحديث قائمة المشرفين ✅');
          await Promise.all([loadAdminsRoster(), loadAuditLogs()]);
        });
      });
    }
  }

  async function handleAddAdmin(e) {
    e.preventDefault();
    const client = sb();
    if (!client) return;
    const email = document.getElementById('new-admin-email').value.trim().toLowerCase();
    const role = document.getElementById('new-admin-role').value;
    const btn = document.getElementById('btn-add-admin');
    btn.disabled = true;
    try {
      const { error } = await client.rpc('admin_manage_admin', {
        p_action: 'add',
        p_email: email,
        p_role: role,
      });
      if (error) throw error;
      toast('تم حفظ صلاحية المشرف ✅');
      document.getElementById('admin-manage-form').reset();
      await Promise.all([loadAdminsRoster(), loadAuditLogs()]);
    } catch (err) {
      toast(`فشل تحديث المشرف: ${err.message}`, true);
    } finally {
      btn.disabled = false;
    }
  }

  // ==================== WIRING & EXPORTS ====================

  function bindCmsListeners() {
    // Store CMS
    document.getElementById('st-category')?.addEventListener('change', syncStoreMetadataPanels);
    document.getElementById('btn-reset-store-form')?.addEventListener('click', resetStoreForm);
    document.getElementById('store-cms-form')?.addEventListener('submit', handleSaveStoreItem);
    [
      'st-title',
      'st-desc',
      'st-coins',
      'st-gems',
      'st-visible',
      'st-th-bg1',
      'st-th-bg2',
      'st-th-card',
      'st-th-gold',
      'st-th-sec',
      'st-fr-c1',
      'st-fr-c2',
      'st-fr-glow',
      'st-fr-pattern',
      'st-fr-gems',
      'st-badge-color',
    ].forEach((id) => {
      const el = document.getElementById(id);
      if (!el) return;
      el.addEventListener('input', updateStorePreview);
      el.addEventListener('change', updateStorePreview);
    });
    document.querySelectorAll('button[data-store-filter]').forEach((btn) => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('button[data-store-filter]').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        cmsState.storeFilter = btn.dataset.storeFilter;
        renderStoreItems();
      });
    });

    // Content subtabs
    document.querySelectorAll('button[data-cms-subtab]').forEach((btn) => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('button[data-cms-subtab]').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        const sub = btn.dataset.cmsSubtab;
        document.getElementById('cms-sub-library').classList.toggle('hidden', sub !== 'library');
        document.getElementById('cms-sub-quiz').classList.toggle('hidden', sub !== 'quiz');
      });
    });

    // Library CMS
    document.getElementById('lib-section-form')?.addEventListener('submit', handleSaveLibSection);
    document.getElementById('lib-item-form')?.addEventListener('submit', handleSaveLibItem);
    document.getElementById('lib-filter-section')?.addEventListener('change', loadLibraryContent);
    document.getElementById('btn-reset-lib-sec')?.addEventListener('click', () => {
      document.getElementById('lib-section-form').reset();
      document.getElementById('lib-sec-id').readOnly = false;
      document.getElementById('lib-sec-visible').checked = true;
      document.getElementById('lib-sec-heading').textContent = '🗂️ قسم مكتبة (إضافة / تعديل)';
    });
    document.getElementById('btn-reset-lib-item')?.addEventListener('click', () => {
      document.getElementById('lib-item-form').reset();
      document.getElementById('lib-item-id').value = '';
      document.getElementById('lib-item-visible').checked = true;
      document.getElementById('lib-item-heading').textContent = '📝 مقال / قصة / بطاقة معرفة';
    });
    document.getElementById('lib-sec-color-picker')?.addEventListener('input', (e) => {
      document.getElementById('lib-sec-color').value = e.target.value.toUpperCase();
    });

    // Quiz CMS
    document.getElementById('quiz-category-form')?.addEventListener('submit', handleSaveQuizCategory);
    document.getElementById('quiz-question-form')?.addEventListener('submit', handleSaveQuizQuestion);
    document.getElementById('quiz-filter-cat')?.addEventListener('change', loadQuizContent);
    document.getElementById('quiz-filter-level')?.addEventListener('change', loadQuizContent);
    document.getElementById('btn-reset-quiz-cat')?.addEventListener('click', () => {
      document.getElementById('quiz-category-form').reset();
      document.getElementById('qz-cat-id').readOnly = false;
      document.getElementById('qz-cat-levels').value = '10';
      document.getElementById('qz-cat-visible').checked = true;
      document.getElementById('quiz-cat-heading').textContent = '🏆 قسم مسابقة (إضافة / تعديل)';
    });
    document.getElementById('btn-reset-quiz-q')?.addEventListener('click', () => {
      document.getElementById('quiz-question-form').reset();
      document.getElementById('qz-q-id').value = '';
      document.getElementById('qz-q-level').value = '1';
      document.getElementById('qz-q-visible').checked = true;
      document.getElementById('quiz-q-heading').textContent = '❓ إضافة / تعديل سؤال سحابي';
    });
    document.getElementById('qz-cat-color-picker')?.addEventListener('input', (e) => {
      document.getElementById('qz-cat-color').value = e.target.value.toUpperCase();
    });

    // Players & Compensation
    document.getElementById('btn-inspector-search')?.addEventListener('click', searchPlayersForInspector);
    document.getElementById('player-inspector-query')?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        searchPlayersForInspector();
      }
    });
    document.getElementById('btn-export-players-csv')?.addEventListener('click', exportPlayersCsv);
    document.getElementById('compensation-form')?.addEventListener('submit', handleGrantCompensation);
    document.getElementById('btn-target-player-msg')?.addEventListener('click', () => {
      const d = cmsState.currentPlayerDetail;
      if (!d) return;
      bridge().selectPlayerForAnnouncement?.({
        user_id: d.user_id,
        player_code: d.player_code,
        display_name: d.directory?.display_name || d.leaderboard?.display_name || 'لاعب',
      });
    });

    // Admins
    document.getElementById('admin-manage-form')?.addEventListener('submit', handleAddAdmin);

    syncStoreMetadataPanels();
  }

  async function onDashboardLoad() {
    cmsState.loadedOnce = true;
    await Promise.all([
      loadStoreItems(),
      loadLibraryContent(),
      loadQuizContent(),
      searchPlayersForInspector(),
      loadGhosts(),
      loadAuditLogs(),
      loadAdminsRoster(),
    ]);
  }

  window.SahabaCmsSuite = {
    onDashboardLoad,
    onOverview: renderVersionBreakdown,
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', bindCmsListeners);
  } else {
    bindCmsListeners();
  }
})();
