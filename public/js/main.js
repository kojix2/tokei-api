/**
 * JavaScript file for tokei-api
 */

// Function to fill the repository URL input with the example URL
function fillExampleRepo(event) {
  event.preventDefault();
  const repoUrlInput = document.getElementById("repo_url");
  repoUrlInput.value = "https://github.com/kojix2/tokei-api";
  repoUrlInput.focus();
}

// Styles for table sorting
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
  // Form submission handling
  const repoForm = document.querySelector('form[action="/analyze"]');
  if (repoForm) {
    repoForm.addEventListener("submit", function (e) {
      const repoUrl = document.getElementById("repo_url").value.trim();

      // Display during submission
      const submitBtn = repoForm.querySelector('button[type="submit"]');
      submitBtn.disabled = true;
      submitBtn.innerHTML =
        '<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span> Analyzing...';
    });
  }

  // JSON formatting
  const jsonResult = document.getElementById("jsonResult");
  if (jsonResult && jsonResult.textContent) {
    try {
      const jsonObj = JSON.parse(jsonResult.textContent);
      jsonResult.textContent = JSON.stringify(jsonObj, null, 2);
    } catch (e) {
      console.error("Failed to parse JSON:", e);
    }
  }

  // Initialize tooltips
  const tooltipTriggerList = [].slice.call(
    document.querySelectorAll('[data-bs-toggle="tooltip"]')
  );
  if (typeof bootstrap !== "undefined") {
    tooltipTriggerList.map(function (tooltipTriggerEl) {
      return new bootstrap.Tooltip(tooltipTriggerEl);
    });
  }

  // Active state for navigation
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

  // Table sorting functionality
  const languageTable = document.getElementById('language-stats-table');
  if (languageTable) {
    initTableSort(languageTable);
  }
});

// Initialize table sorting functionality
function initTableSort(table) {
  const headers = table.querySelectorAll('th.sortable');
  let currentSortColumn = null;
  let currentSortDirection = 'asc';

  headers.forEach((header, index) => {
    // Header click event
    header.addEventListener('click', () => {
      // Reverse sort direction if the same column is clicked again
      if (currentSortColumn === index) {
        currentSortDirection = currentSortDirection === 'asc' ? 'desc' : 'asc';
      } else {
        currentSortDirection = 'asc';
        currentSortColumn = index;
      }

      // Reset sort icon state
      headers.forEach(h => {
        h.classList.remove('sort-asc', 'sort-desc');
      });

      // Display current sort state
      header.classList.add(currentSortDirection === 'asc' ? 'sort-asc' : 'sort-desc');

      // Sort the table
      sortTable(table, index, currentSortDirection, header.dataset.sort);
    });
  });
}

// Table sorting process
function sortTable(table, columnIndex, direction, dataType) {
  const tbody = table.querySelector('tbody');
  const rows = Array.from(tbody.querySelectorAll('tr'));
  const tfoot = table.querySelector('tfoot');
  
  // Sort excluding footer rows
  const sortedRows = rows.sort((rowA, rowB) => {
    const cellA = rowA.cells[columnIndex].textContent.trim();
    const cellB = rowB.cells[columnIndex].textContent.trim();
    
    let comparison = 0;
    
    if (dataType === 'number') {
      // Sort as numbers
      const numA = parseFloat(cellA.replace(/,/g, '')) || 0;
      const numB = parseFloat(cellB.replace(/,/g, '')) || 0;
      comparison = numA - numB;
    } else {
      // Sort as strings
      comparison = cellA.localeCompare(cellB, 'ja');
    }
    
    // Reverse result based on sort direction
    return direction === 'asc' ? comparison : -comparison;
  });
  
  // Apply sort results to the table
  while (tbody.firstChild) {
    tbody.removeChild(tbody.firstChild);
  }
  
  sortedRows.forEach(row => {
    tbody.appendChild(row);
  });
}

// Copy button functionality
function copyToClipboard(text, buttonElement) {
  navigator.clipboard.writeText(text).then(
    function () {
      const originalText = buttonElement.textContent;
      buttonElement.textContent = "Copied!";

      setTimeout(function () {
        buttonElement.textContent = originalText;
      }, 2000);
    },
    function (err) {
      console.error("Failed to copy to clipboard:", err);
      alert("Failed to copy to clipboard.");
    }
  );
}
