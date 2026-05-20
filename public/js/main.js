/**
 * JavaScript file for tokei-api
 */

// Reset Analyze button state when navigating back
window.addEventListener("pageshow", function (event) {
  if (event.persisted) {
    const repoForm = document.querySelector('form[action="/analyses"]');
    if (repoForm) {
      const submitBtn = repoForm.querySelector('button[type="submit"]');
      if (submitBtn) {
        submitBtn.disabled = false;
        const initialLabel = submitBtn.getAttribute("data-initial-label") || "Analyze";
        submitBtn.textContent = initialLabel;
      }
    }
  }
});

document.addEventListener("DOMContentLoaded", function () {
  const exampleRepoLink = document.getElementById("example-repo-link");
  if (exampleRepoLink) {
    exampleRepoLink.addEventListener("click", fillExampleRepo);
  }

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
  setupCopyButtons();
  initializeResultCharts();
});

function fillExampleRepo(event) {
  event.preventDefault();
  const repoUrlInput = document.getElementById("repo_url");
  if (!repoUrlInput) return;

  repoUrlInput.value = "https://github.com/kojix2/tokei-api";
  repoUrlInput.focus();
}

// Setup toggle functionality for language rows
function setupLanguageRowToggles() {
  const languageRows = document.querySelectorAll(".language-row");
  if (languageRows.length === 0) return;

  languageRows.forEach((row) => {
    // Add click event to the toggle icon only
    const toggleIcon = row.querySelector(".toggle-icon");
    if (!toggleIcon) return;

    toggleIcon.addEventListener("click", function (e) {
      // Use stopPropagation to prevent the click from bubbling up to the row
      e.stopPropagation();

      const language = row.dataset.language;
      const escapedLanguage = cssEscape(language);
      const fileDetailsRow = document.querySelector(
        `.file-details-row[data-language="${escapedLanguage}"]`
      );
      if (!fileDetailsRow) return;

      // Toggle visibility
      const isExpanded = !fileDetailsRow.classList.contains("d-none");

      if (isExpanded) {
        // Collapse
        fileDetailsRow.classList.add("d-none");
        toggleIcon.textContent = "▶";
        row.classList.remove("active-language-row");
      } else {
        // Expand
        fileDetailsRow.classList.remove("d-none");
        toggleIcon.textContent = "▼";
        row.classList.add("active-language-row");

        // Initialize sorting for file details table if not already initialized
        const fileDetailsTable = fileDetailsRow.querySelector(
          ".file-details-table"
        );
        if (
          fileDetailsTable &&
          !fileDetailsTable.classList.contains("sort-initialized")
        ) {
          initTableSort(fileDetailsTable);
          fileDetailsTable.classList.add("sort-initialized");
        }
      }
    });
  });
}

// Initialize and perform initial sort on main language table
function initializeMainTableSort() {
  const languageTable = document.getElementById("language-stats-table");
  if (!languageTable) return;

  // Initialize sorting
  initTableSort(languageTable);

  // Find the Code column (usually the 3rd column, index 2)
  const codeColumnHeader = languageTable.querySelector(
    'th.sortable[data-sort="number"]:nth-child(3)'
  );
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
  const headers = table.querySelectorAll("th.sortable");
  let currentSortColumn = null;
  let currentSortDirection = "desc"; // Default to descending order

  headers.forEach((header, index) => {
    // Header click event
    header.addEventListener("click", () => {
      // Reverse sort direction if the same column is clicked again
      if (currentSortColumn === index) {
        currentSortDirection = currentSortDirection === "asc" ? "desc" : "asc";
      } else {
        currentSortDirection = "desc"; // Start with descending when clicking a new column
        currentSortColumn = index;
      }

      // Reset sort icon state
      headers.forEach((h) => {
        h.classList.remove("sort-asc", "sort-desc");
      });

      // Display current sort state
      header.classList.add(
        currentSortDirection === "asc" ? "sort-asc" : "sort-desc"
      );

      // Sort the table
      sortTable(table, index, currentSortDirection, header.dataset.sort);
    });
  });
}

// Compare cell values for sorting
function compareValues(cellA, cellB, dataType) {
  if (dataType === "number") {
    // Sort as numbers
    const numA = parseFloat(cellA.replace(/,/g, "")) || 0;
    const numB = parseFloat(cellB.replace(/,/g, "")) || 0;
    return numA - numB;
  } else {
    // Sort as strings
    return cellA.localeCompare(cellB, "ja");
  }
}

// Table sorting process
function sortTable(table, columnIndex, direction, dataType) {
  if (!table || !table.querySelector("tbody")) return;

  const tbody = table.querySelector("tbody");
  const isMainTable = table.id === "language-stats-table";

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
  const languageRows = Array.from(tbody.querySelectorAll("tr.language-row"));
  if (languageRows.length === 0) return;

  // Create a map of language rows and their associated detail rows
  const rowPairs = {};
  languageRows.forEach((row) => {
    const language = row.dataset.language;
    const escapedLanguage = cssEscape(language);
    const detailRow = tbody.querySelector(
      `.file-details-row[data-language="${escapedLanguage}"]`
    );
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
    return direction === "asc" ? comparison : -comparison;
  });

  // Clear tbody
  while (tbody.firstChild) {
    tbody.removeChild(tbody.firstChild);
  }

  // Append rows in sorted order, keeping language and detail rows together
  sortedLanguages.forEach((language) => {
    const { languageRow, detailRow } = rowPairs[language];
    tbody.appendChild(languageRow);
    tbody.appendChild(detailRow);
  });
}

// Sort file details table
function sortDetailTable(tbody, columnIndex, direction, dataType) {
  // Get all rows
  const rows = Array.from(tbody.querySelectorAll("tr"));
  if (rows.length === 0) return;

  // Sort rows
  const sortedRows = rows.sort((rowA, rowB) => {
    const cellA = rowA.cells[columnIndex].textContent.trim();
    const cellB = rowB.cells[columnIndex].textContent.trim();

    const comparison = compareValues(cellA, cellB, dataType);

    // Apply sort direction
    return direction === "asc" ? comparison : -comparison;
  });

  // Clear tbody
  while (tbody.firstChild) {
    tbody.removeChild(tbody.firstChild);
  }

  // Append sorted rows
  sortedRows.forEach((row) => {
    tbody.appendChild(row);
  });
}

function cssEscape(value) {
  if (typeof CSS !== "undefined" && CSS.escape) {
    return CSS.escape(value);
  }

  return value.replace(/["\\]/g, "\\$&");
}

function setupCopyButtons() {
  document.querySelectorAll(".js-copy-button").forEach((button) => {
    button.addEventListener("click", function () {
      copyToClipboard(button.dataset.copyText || "", button);
    });
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

function initializeResultCharts() {
  const resultJsonTemplate = document.getElementById("analysis-result-json");
  const languageCanvas = document.getElementById("languageChart");
  const codeTypeCanvas = document.getElementById("codeTypeChart");

  if (!resultJsonTemplate || !languageCanvas || !codeTypeCanvas) return;
  if (typeof Chart === "undefined") return;

  let resultJson;
  try {
    resultJson = JSON.parse(resultJsonTemplate.textContent);
  } catch (e) {
    console.error("Failed to parse analysis result JSON:", e);
    return;
  }

  const languageData = {};
  Object.entries(resultJson).forEach(([language, stats]) => {
    if (language !== "Total") {
      languageData[language] = stats.code || 0;
    }
  });

  const topLanguages = Object.entries(languageData)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);
  const languageNames = topLanguages.map((item) => item[0]);
  const codeCounts = topLanguages.map((item) => item[1]);

  new Chart(languageCanvas.getContext("2d"), {
    type: "bar",
    data: {
      labels: languageNames,
      datasets: [
        {
          label: "Lines of Code",
          data: codeCounts,
          backgroundColor: generateChartColors(languageNames.length),
          borderWidth: 1,
        },
      ],
    },
    options: {
      indexAxis: "y",
      responsive: true,
      maintainAspectRatio: true,
      aspectRatio: 2,
      scales: {
        x: {
          beginAtZero: true,
        },
      },
    },
  });

  let totalCode = 0;
  let totalComments = 0;
  let totalBlanks = 0;

  Object.values(resultJson).forEach((stats) => {
    if (stats && typeof stats === "object") {
      totalCode += stats.code || 0;
      totalComments += stats.comments || 0;
      totalBlanks += stats.blanks || 0;
    }
  });

  new Chart(codeTypeCanvas.getContext("2d"), {
    type: "pie",
    data: {
      labels: ["Code", "Comments", "Blanks"],
      datasets: [
        {
          data: [totalCode, totalComments, totalBlanks],
          backgroundColor: ["#4CAF50", "#2196F3", "#FFC107"],
          borderWidth: 1,
        },
      ],
    },
    options: {
      responsive: true,
      plugins: {
        legend: {
          position: "bottom",
        },
      },
    },
  });
}

function generateChartColors(count) {
  const colors = [];
  for (let i = 0; i < count; i++) {
    const hue = ((i * 360) / count) % 360;
    colors.push(`hsl(${hue}, 70%, 60%)`);
  }
  return colors;
}
