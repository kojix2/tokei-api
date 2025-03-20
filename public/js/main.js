/**
 * tokei-api用のJavaScriptファイル
 */

document.addEventListener('DOMContentLoaded', function() {
  // フォームのバリデーション
  const repoForm = document.querySelector('form[action="/analyze"]');
  if (repoForm) {
    repoForm.addEventListener('submit', function(e) {
      const repoUrl = document.getElementById('repo_url').value.trim();
      
      // 基本的なURLバリデーション
      const urlPattern = /^(https?:\/\/|git@)([a-zA-Z0-9_.-]+\.[a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_.-\/]+)(\.git)?$/;
      
      if (!urlPattern.test(repoUrl)) {
        e.preventDefault();
        alert('有効なGitリポジトリURLを入力してください。');
        return false;
      }
      
      // 送信中の表示
      const submitBtn = repoForm.querySelector('button[type="submit"]');
      submitBtn.disabled = true;
      submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> 解析中...';
    });
  }
  
  // JSONフォーマット
  const jsonResult = document.getElementById('jsonResult');
  if (jsonResult && jsonResult.textContent) {
    try {
      const jsonObj = JSON.parse(jsonResult.textContent);
      jsonResult.textContent = JSON.stringify(jsonObj, null, 2);
    } catch (e) {
      console.error('JSONのパースに失敗しました:', e);
    }
  }
  
  // ツールチップの初期化
  const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
  if (typeof bootstrap !== 'undefined') {
    tooltipTriggerList.map(function (tooltipTriggerEl) {
      return new bootstrap.Tooltip(tooltipTriggerEl);
    });
  }
  
  // 最近の解析結果のリンクをクリックした時の処理
  const recentLinks = document.querySelectorAll('.list-group-item');
  recentLinks.forEach(link => {
    link.addEventListener('click', function() {
      // クリック時のアニメーション
      this.classList.add('active');
    });
  });
  
  // ナビゲーションのアクティブ状態
  const currentPath = window.location.pathname;
  const navLinks = document.querySelectorAll('.nav-link');
  
  navLinks.forEach(link => {
    const linkPath = link.getAttribute('href');
    if (linkPath === currentPath || 
        (currentPath.startsWith('/result/') && linkPath === '/')) {
      link.classList.add('active');
    }
  });
});

// コピーボタンの機能
function copyToClipboard(text, buttonElement) {
  navigator.clipboard.writeText(text).then(function() {
    const originalText = buttonElement.textContent;
    buttonElement.textContent = 'コピーしました！';
    
    setTimeout(function() {
      buttonElement.textContent = originalText;
    }, 2000);
  }, function(err) {
    console.error('クリップボードへのコピーに失敗しました:', err);
    alert('クリップボードへのコピーに失敗しました。');
  });
}
