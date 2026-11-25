import { mountLevelManager } from './cms_level_manager.js';
import { loadLibraryContent, mountLibrary } from './cms_library.js';
import { loadQuestionBrowser, mountQuestionBrowser } from './cms_question_browser.js';
import { loadQuizContent, mountQuiz, onQuizSubtabActivated } from './cms_quiz.js';

let mounted = false;
let activeSubtab = 'library';

function switchSubtab(container, target) {
  activeSubtab = target;
  container.querySelectorAll('button[data-cms-subtab]').forEach((b) => {
    b.classList.toggle('active', b.dataset.cmsSubtab === target);
  });
  document.getElementById('cms-sub-library')?.classList.toggle('hidden', target !== 'library');
  document.getElementById('cms-sub-quiz')?.classList.toggle('hidden', target !== 'quiz');
  document.getElementById('cms-sub-levels')?.classList.toggle('hidden', target !== 'levels');
  document.getElementById('cms-sub-browser')?.classList.toggle('hidden', target !== 'browser');
  if (target === 'quiz') {
    onQuizSubtabActivated();
  } else if (target === 'browser') {
    loadQuestionBrowser();
  }
}

function jumpToQuizPublisher(container, catId) {
  switchSubtab(container, 'quiz');
  const existingSel = document.getElementById('bulk-existing-cat');
  const modeSel = document.getElementById('bulk-target-mode');
  if (modeSel && existingSel && catId) {
    modeSel.value = 'existing';
    existingSel.value = catId;
    modeSel.dispatchEvent(new Event('change'));
  }
  document.getElementById('btn-bulk-publish-gzip')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

export function mount(container) {
  if (mounted || !container) return;
  container.innerHTML = `
    <div class="subtabs-bar mb-md">
      <button class="subtab-btn active" data-cms-subtab="library" type="button">📖 المكتبة الإسلامية وأقسامها</button>
      <button class="subtab-btn" data-cms-subtab="quiz" type="button">❓ المسابقات، المراحل والأسئلة</button>
      <button class="subtab-btn" data-cms-subtab="levels" type="button">⏳ إدارة المستويات وقريباً</button>
      <button class="subtab-btn" data-cms-subtab="browser" type="button">🔍 متصفح الأسئلة والإدارة الجماعية</button>
    </div>
    <div id="cms-sub-library" class="two-col-grid"></div>
    <div id="cms-sub-quiz" class="two-col-grid hidden"></div>
    <div id="cms-sub-levels" class="two-col-grid hidden"></div>
    <div id="cms-sub-browser" class="two-col-grid hidden"></div>
  `;

  mountLibrary(document.getElementById('cms-sub-library'));
  mountQuiz(document.getElementById('cms-sub-quiz'));
  mountLevelManager(document.getElementById('cms-sub-levels'), {
    onMutated: loadQuizContent,
    onJumpToPublish: (catId) => jumpToQuizPublisher(container, catId),
  });
  mountQuestionBrowser(document.getElementById('cms-sub-browser'), {
    onMutated: loadQuizContent,
    onJumpToPublish: (catId) => jumpToQuizPublisher(container, catId),
  });

  container.querySelectorAll('button[data-cms-subtab]').forEach((btn) => {
    btn.addEventListener('click', () => switchSubtab(container, btn.dataset.cmsSubtab));
  });

  mounted = true;
}

export async function load() {
  await Promise.all([loadLibraryContent(), loadQuizContent()]);
  if (activeSubtab === 'quiz') {
    onQuizSubtabActivated();
  } else if (activeSubtab === 'browser') {
    await loadQuestionBrowser();
  }
}
