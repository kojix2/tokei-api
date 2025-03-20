/**
 * tokei-api用のJavaScriptファイル
 */

// テーブルソート用のスタイル
document.head.insertAdjacentHTML('beforeend', `
  <style>
    .sortable {
      cursor: pointer;
      user-select: none;
    }
    .sortable:hover {
      background-color: rgba(255, 255, 255, 0.2);
    }
    .sort-icon {
      opacity: 0.5;
      display: inline-block;
      margin-left: 5px;
    }
    .sort-asc .sort-icon::after {
      content: "↑";
    }
    .sort-desc .sort-icon::after {
      content: "↓";
    }
    .sort-asc .sort-icon, .sort-desc .sort-icon {
      opacity: 1;
    }
  </style>
`);

document.addEventListener("DOMContentLoaded", function () {
  // フォームの送信処理
  const repoForm = document.querySelector('form[action="/analyze"]');
  if (repoForm) {
    repoForm.addEventListener("submit", function (e) {
      const repoUrl = document.getElementById("repo_url").value.trim();

      // 送信中の表示
      const submitBtn = repoForm.querySelector('button[type="submit"]');
      submitBtn.disabled = true;
      submitBtn.innerHTML =
        '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> 解析中...';
    });
  }

  // JSONフォーマット
  const jsonResult = document.getElementById("jsonResult");
  if (jsonResult && jsonResult.textContent) {
    try {
      const jsonObj = JSON.parse(jsonResult.textContent);
      jsonResult.textContent = JSON.stringify(jsonObj, null, 2);
    } catch (e) {
      console.error("JSONのパースに失敗しました:", e);
    }
  }

  // ツールチップの初期化
  const tooltipTriggerList = [].slice.call(
    document.querySelectorAll('[data-bs-toggle="tooltip"]')
  );
  if (typeof bootstrap !== "undefined") {
    tooltipTriggerList.map(function (tooltipTriggerEl) {
      return new bootstrap.Tooltip(tooltipTriggerEl);
    });
  }

  // ナビゲーションのアクティブ状態
  const currentPath = window.location.pathname;
  const navLinks = document.querySelectorAll(".nav-link");

  navLinks.forEach((link) => {
    const linkPath = link.getAttribute("href");
    if (
      linkPath === currentPath ||
      (currentPath.startsWith("/result/") && linkPath === "/")
    ) {
      link.classList.add("active");
    }
  });

  // テーブルソート機能
  const languageTable = document.getElementById('language-stats-table');
  if (languageTable) {
    initTableSort(languageTable);
  }
});

// テーブルソート機能の初期化
function initTableSort(table) {
  const headers = table.querySelectorAll('th.sortable');
  let currentSortColumn = null;
  let currentSortDirection = 'asc';

  headers.forEach((header, index) => {
    // ヘッダークリックイベント
    header.addEventListener('click', () => {
      // 前回と同じカラムがクリックされた場合はソート方向を反転
      if (currentSortColumn === index) {
        currentSortDirection = currentSortDirection === 'asc' ? 'desc' : 'asc';
      } else {
        currentSortDirection = 'asc';
        currentSortColumn = index;
      }

      // ソートアイコンの状態をリセット
      headers.forEach(h => {
        h.classList.remove('sort-asc', 'sort-desc');
      });

      // 現在のソート状態を表示
      header.classList.add(currentSortDirection === 'asc' ? 'sort-asc' : 'sort-desc');

      // テーブルをソート
      sortTable(table, index, currentSortDirection, header.dataset.sort);
    });
  });
}

// テーブルのソート処理
function sortTable(table, columnIndex, direction, dataType) {
  const tbody = table.querySelector('tbody');
  const rows = Array.from(tbody.querySelectorAll('tr'));
  const tfoot = table.querySelector('tfoot');
  
  // フッター行を除外してソート
  const sortedRows = rows.sort((rowA, rowB) => {
    const cellA = rowA.cells[columnIndex].textContent.trim();
    const cellB = rowB.cells[columnIndex].textContent.trim();
    
    let comparison = 0;
    
    if (dataType === 'number') {
      // 数値としてソート
      const numA = parseFloat(cellA.replace(/,/g, '')) || 0;
      const numB = parseFloat(cellB.replace(/,/g, '')) || 0;
      comparison = numA - numB;
    } else {
      // 文字列としてソート
      comparison = cellA.localeCompare(cellB, 'ja');
    }
    
    // ソート方向に応じて結果を反転
    return direction === 'asc' ? comparison : -comparison;
  });
  
  // ソート結果をテーブルに反映
  while (tbody.firstChild) {
    tbody.removeChild(tbody.firstChild);
  }
  
  sortedRows.forEach(row => {
    tbody.appendChild(row);
  });
}

// コピーボタンの機能
function copyToClipboard(text, buttonElement) {
  navigator.clipboard.writeText(text).then(
    function () {
      const originalText = buttonElement.textContent;
      buttonElement.textContent = "コピーしました！";

      setTimeout(function () {
        buttonElement.textContent = originalText;
      }, 2000);
    },
    function (err) {
      console.error("クリップボードへのコピーに失敗しました:", err);
      alert("クリップボードへのコピーに失敗しました。");
    }
  );
}
