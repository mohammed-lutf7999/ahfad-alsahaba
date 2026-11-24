import { loadLibraryContent, mountLibrary } from './cms_library.js';
import { loadQuizContent, mountQuiz, onQuizSubtabActivated } from './cms_quiz.js';

let mounted = false;
let activeSubtab = 'library';

export function mount(container) {
  if (mounted || !container) return;
  container.innerHTML = `
    <div class="subtabs-bar mb-md">
      <button class="subtab-btn active" data-cms-subtab="library" type="button">📖 المكتبة الإسلامية وأقسامها</button>
      <button class="subtab-btn" data-cms-subtab="quiz" type="button">❓ المسابقات، المراحل والأسئلة</button>
    </div>
    <div id="cms-sub-library" class="two-col-grid"></div>
    <div id="cms-sub-quiz" class="two-col-grid hidden"></div>
  `;

  mountLibrary(document.getElementById('cms-sub-library'));
  mountQuiz(document.getElementById('cms-sub-quiz'));

  container.querySelectorAll('button[data-cms-subtab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      container.querySelectorAll('button[data-cms-subtab]').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      activeSubtab = btn.dataset.cmsSubtab;
      document.getElementById('cms-sub-library').classList.toggle('hidden', activeSubtab !== 'library');
      document.getElementById('cms-sub-quiz').classList.toggle('hidden', activeSubtab !== 'quiz');
      if (activeSubtab === 'quiz') {
        onQuizSubtabActivated();
      }
    });
  });

  mounted = true;
}

export async function load() {
  await Promise.all([loadLibraryContent(), loadQuizContent()]);
  if (activeSubtab === 'quiz') {
    onQuizSubtabActivated();
  }
}
