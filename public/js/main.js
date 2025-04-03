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
  const repoForm = document.querySelector('form[action="/analyses"]');
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
  
  // Setup toggle functionality for language rows
  setupLanguageRowToggles();

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

  // Initialize and perform initial sort on main language table
  initializeMainTableSort();
});

// Setup toggle functionality for language rows
function setupLanguageRowToggles() {
  const languageRows = document.querySelectorAll('.language-row');
  if (languageRows.length === 0) return;
  
  languageRows.forEach(row => {
    // Add click event to the toggle icon only
    const toggleIcon = row.querySelector('.toggle-icon');
    if (!toggleIcon) return;
    
    toggleIcon.addEventListener('click', function(e) {
      // Use stopPropagation to prevent the click from bubbling up to the row
      e.stopPropagation();
      
      const language = row.dataset.language;
      const fileDetailsRow = document.querySelector(`.file-details-row[data-language="${language}"]`);
      if (!fileDetailsRow) return;
      
      // Toggle visibility
      const isExpanded = fileDetailsRow.style.display !== 'none';
      
      if (isExpanded) {
        // Collapse
        fileDetailsRow.style.display = 'none';
        toggleIcon.textContent = '▶';
        row.classList.remove('active-language-row');
      } else {
        // Expand
        fileDetailsRow.style.display = 'table-row';
        toggleIcon.textContent = '▼';
        row.classList.add('active-language-row');
        
        // Initialize sorting for file details table if not already initialized
        const fileDetailsTable = fileDetailsRow.querySelector('.file-details-table');
        if (fileDetailsTable && !fileDetailsTable.classList.contains('sort-initialized')) {
          initTableSort(fileDetailsTable);
          fileDetailsTable.classList.add('sort-initialized');
        }
      }
    });
  });
}

// Initialize and perform initial sort on main language table
function initializeMainTableSort() {
  const languageTable = document.getElementById('language-stats-table');
  if (!languageTable) return;
  
  // Initialize sorting
  initTableSort(languageTable);
  
  // Find the Code column (usually the 3rd column, index 2)
  const codeColumnHeader = languageTable.querySelector('th.sortable[data-sort="number"]:nth-child(3)');
  if (codeColumnHeader) {
    // Trigger a click on the Code column to sort initially
    // Using requestAnimationFrame instead of setTimeout for better performance
    requestAnimationFrame(() => {
      codeColumnHeader.click();
    });
  }
}

// Initialize table sorting functionality
function initTableSort(table) {
  const headers = table.querySelectorAll('th.sortable');
  let currentSortColumn = null;
  let currentSortDirection = 'desc'; // Default to descending order

  headers.forEach((header, index) => {
    // Header click event
    header.addEventListener('click', () => {
      // Reverse sort direction if the same column is clicked again
      if (currentSortColumn === index) {
        currentSortDirection = currentSortDirection === 'asc' ? 'desc' : 'asc';
      } else {
        currentSortDirection = 'desc'; // Start with descending when clicking a new column
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

// Compare cell values for sorting
function compareValues(cellA, cellB, dataType) {
  if (dataType === 'number') {
    // Sort as numbers
    const numA = parseFloat(cellA.replace(/,/g, '')) || 0;
    const numB = parseFloat(cellB.replace(/,/g, '')) || 0;
    return numA - numB;
  } else {
    // Sort as strings
    return cellA.localeCompare(cellB, 'ja');
  }
}

// Table sorting process
function sortTable(table, columnIndex, direction, dataType) {
  if (!table || !table.querySelector('tbody')) return;
  
  const tbody = table.querySelector('tbody');
  const isMainTable = table.id === 'language-stats-table';
  
  if (isMainTable) {
    // Sort main language table (with nested file details)
    sortMainTable(tbody, columnIndex, direction, dataType);
  } else {
    // Sort file details table
    sortDetailTable(tbody, columnIndex, direction, dataType);
  }
}

// Sort main language table with nested file details
function sortMainTable(tbody, columnIndex, direction, dataType) {
  // Get all language rows
  const languageRows = Array.from(tbody.querySelectorAll('tr.language-row'));
  if (languageRows.length === 0) return;
  
  // Create a map of language rows and their associated detail rows
  const rowPairs = {};
  languageRows.forEach(row => {
    const language = row.dataset.language;
    const detailRow = tbody.querySelector(`.file-details-row[data-language="${language}"]`);
    if (detailRow) {
      rowPairs[language] = { languageRow: row, detailRow: detailRow };
    }
  });
  
  // Sort languages based on the selected column
  const sortedLanguages = Object.keys(rowPairs).sort((langA, langB) => {
    const rowA = rowPairs[langA].languageRow;
    const rowB = rowPairs[langB].languageRow;
    
    const cellA = rowA.cells[columnIndex].textContent.trim();
    const cellB = rowB.cells[columnIndex].textContent.trim();
    
    const comparison = compareValues(cellA, cellB, dataType);
    
    // Apply sort direction
    return direction === 'asc' ? comparison : -comparison;
  });
  
  // Clear tbody
  while (tbody.firstChild) {
    tbody.removeChild(tbody.firstChild);
  }
  
  // Append rows in sorted order, keeping language and detail rows together
  sortedLanguages.forEach(language => {
    const { languageRow, detailRow } = rowPairs[language];
    tbody.appendChild(languageRow);
    tbody.appendChild(detailRow);
  });
}

// Sort file details table
function sortDetailTable(tbody, columnIndex, direction, dataType) {
  // Get all rows
  const rows = Array.from(tbody.querySelectorAll('tr'));
  if (rows.length === 0) return;
  
  // Sort rows
  const sortedRows = rows.sort((rowA, rowB) => {
    const cellA = rowA.cells[columnIndex].textContent.trim();
    const cellB = rowB.cells[columnIndex].textContent.trim();
    
    const comparison = compareValues(cellA, cellB, dataType);
    
    // Apply sort direction
    return direction === 'asc' ? comparison : -comparison;
  });
  
  // Clear tbody
  while (tbody.firstChild) {
    tbody.removeChild(tbody.firstChild);
  }
  
  // Append sorted rows
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
