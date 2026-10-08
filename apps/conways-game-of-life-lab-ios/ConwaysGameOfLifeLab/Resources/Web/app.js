(() => {
  "use strict";

  const MIN_ROWS = 5;
  const MAX_ROWS = 100;
  const MIN_COLS = 5;
  const MAX_COLS = 100;
  const MIN_DELAY = 0.1;
  const MAX_DELAY = 10;
  const DEFAULT_SURVIVAL_MIN = 2;
  const DEFAULT_SURVIVAL_MAX = 3;
  const DEFAULT_BIRTH_COUNT = 3;
  const SAVE_VERSION = 1;
  const STORAGE_CANVASES = "conway.full.canvases.v1";
  const STORAGE_PATTERNS = "conway.full.patterns.v1";
  const STORAGE_PREFERENCES = "conway.full.preferences.v1";

  const DEFAULT_PATTERNS = [
    ["Block", [[1, 1], [1, 1]]],
    ["Beehive", [[0, 1, 1, 0], [1, 0, 0, 1], [0, 1, 1, 0]]],
    ["Tub", [[0, 1, 0], [1, 0, 1], [0, 1, 0]]],
    ["Seed", [[1, 0, 1], [1, 1, 0], [0, 1, 0]]],
    ["Blinker", [[1, 1, 1]]],
    ["Cross", [[0, 1, 0], [1, 1, 1], [0, 1, 0]]],
    ["Single Cell", [[1]]],
    ["Glider", [[0, 1, 0], [1, 0, 1], [0, 1, 1]]],
    ["Spaceship Seed", [[0, 1, 0, 0], [1, 0, 1, 0], [1, 0, 0, 1], [0, 1, 1, 0]]],
    ["Hollow Ring", [[0, 1, 1, 0], [1, 0, 0, 1], [1, 0, 0, 1], [0, 1, 1, 0]]]
  ];

  const $ = selector => document.querySelector(selector);
  const canvas = $("[data-life-canvas]");
  const canvasShell = $("[data-canvas-shell]");
  const context = canvas.getContext("2d", { alpha: false });
  const graphCanvas = $("[data-graph-canvas]");
  const graphContext = graphCanvas.getContext("2d");
  const generationLabel = $("[data-generation]");
  const liveCellsLabel = $("[data-live-cells]");
  const statusLabel = $("[data-status]");
  const rulesSummary = $("[data-rules-summary]");
  const runButton = $('[data-action="toggle"]');
  const selectButton = $('[data-action="selection-mode"]');
  const savePatternButton = $('[data-action="save-pattern"]');
  const cancelModeButton = $('[data-action="cancel-mode"]');
  const savedCanvasesSelect = $("[data-saved-canvases]");
  const rowsInput = $("[data-rows]");
  const colsInput = $("[data-cols]");
  const densityInput = $("[data-density]");
  const delayInput = $("[data-delay]");
  const themeSelect = $("select[data-theme]");
  const importInput = $("[data-import-file]");
  const folderStatus = $("[data-folder-status]");
  const dialog = $("[data-dialog]");
  const dialogTitle = $("[data-dialog-title]");
  const dialogBody = $("[data-dialog-body]");
  const dialogActions = $("[data-dialog-actions]");

  const folderState = {
    connected: false,
    filenames: new Map()
  };

  function postFolderMessage(action, values = {}) {
    const bridge = window.webkit?.messageHandlers?.dataFolder;
    if (!bridge) return false;
    bridge.postMessage({ action, ...values });
    return true;
  }

  function canvasFilename(name) {
    return `${sanitizeName(name)}.life.json`;
  }

  function writeCanvasToFolder(name, data) {
    if (!folderState.connected) return;
    const filename = folderState.filenames.get(name) || canvasFilename(name);
    folderState.filenames.set(name, filename);
    postFolderMessage("write", { filename, text: JSON.stringify(data, null, 2) });
  }

  function syncCanvasesFromFolder(files) {
    const localCanvases = storageRead(STORAGE_CANVASES);
    const beforeSync = { ...localCanvases };
    const namesInFolder = new Set();
    let imported = 0;
    (Array.isArray(files) ? files : []).forEach(file => {
      try {
        const data = JSON.parse(file.text);
        validateCanvasData(data);
        const fallbackName = String(file.filename || "canvas").replace(/\.life\.json$/i, "");
        const name = String(data.name || fallbackName).trim() || fallbackName;
        localCanvases[name] = data;
        folderState.filenames.set(name, file.filename);
        namesInFolder.add(name);
        imported += 1;
      } catch {
        // Ignore unrelated or malformed JSON without preventing valid saves from loading.
      }
    });
    storageWrite(STORAGE_CANVASES, localCanvases);
    Object.entries(beforeSync).forEach(([name, data]) => {
      if (!namesInFolder.has(name)) writeCanvasToFolder(name, data);
    });
    refreshSavedCanvases(savedCanvasesSelect.value);
    setStatus(`Files folder synced: ${imported} canvas file${imported === 1 ? "" : "s"} loaded.`);
  }

  window.nativeFolderStorage = {
    receive(payload) {
      if (!payload || typeof payload !== "object") return;
      if (payload.event === "status") {
        folderState.connected = Boolean(payload.available);
        folderStatus.textContent = folderState.connected ? `Files: ${payload.folderName}` : "Private storage";
        if (folderState.connected) postFolderMessage("list");
      } else if (payload.event === "files") {
        syncCanvasesFromFolder(payload.files);
      } else if (payload.event === "error") {
        setStatus(`Files folder error: ${payload.message}`);
      }
    }
  };

  const state = {
    rows: 20,
    cols: 30,
    grid: makeGrid(20, 30),
    generationZeroGrid: makeGrid(20, 30),
    history: [],
    editHistory: [],
    populationHistory: [0],
    generation: 0,
    running: false,
    timer: null,
    delaySeconds: 0.5,
    survivalMin: DEFAULT_SURVIVAL_MIN,
    survivalMax: DEFAULT_SURVIVAL_MAX,
    birthCount: DEFAULT_BIRTH_COUNT,
    theme: "Dark",
    dirty: false,
    cursor: { row: 0, col: 0 },
    selectionMode: false,
    selection: new Set(),
    clipboard: null,
    pointerActive: false,
    pointerCells: new Set(),
    lastPointerCell: null,
    pendingPattern: null,
    pendingPatternName: null,
    patternAnchor: null
  };

  function makeGrid(rows = state.rows, cols = state.cols) {
    return Array.from({ length: rows }, () => Array(cols).fill(0));
  }

  function copyGrid(grid) {
    return grid.map(row => row.slice());
  }

  function clampInt(value, minimum, maximum, fallback = minimum) {
    const parsed = Number.parseInt(value, 10);
    return Math.max(minimum, Math.min(maximum, Number.isFinite(parsed) ? parsed : fallback));
  }

  function clampDelay(value) {
    const parsed = Number.parseFloat(value);
    const valid = Number.isFinite(parsed) ? parsed : state.delaySeconds;
    return Math.round(Math.max(MIN_DELAY, Math.min(MAX_DELAY, valid)) * 100) / 100;
  }

  function countLiveCells(grid = state.grid) {
    return grid.reduce((total, row) => total + row.reduce((sum, cell) => sum + cell, 0), 0);
  }

  function setStatus(message) {
    statusLabel.textContent = message || "";
  }

  function markDirty() {
    state.dirty = true;
  }

  function markClean() {
    state.dirty = false;
  }

  function storageRead(key) {
    try {
      const value = JSON.parse(localStorage.getItem(key) || "{}");
      return value && typeof value === "object" && !Array.isArray(value) ? value : {};
    } catch {
      return {};
    }
  }

  function storageWrite(key, value) {
    localStorage.setItem(key, JSON.stringify(value));
  }

  function refreshLabels() {
    generationLabel.textContent = `Generation: ${state.generation}`;
    liveCellsLabel.textContent = `Live cells: ${countLiveCells()}`;
    rulesSummary.textContent = `S${state.survivalMin}–${state.survivalMax} / B${state.birthCount}`;
    runButton.textContent = state.running ? "Stop" : "Start";
    selectButton.setAttribute("aria-pressed", String(state.selectionMode));
    selectButton.textContent = state.selectionMode ? "Selecting…" : "Select Cells";
    savePatternButton.disabled = state.selection.size === 0;
    cancelModeButton.hidden = !state.selectionMode && !state.pendingPattern;
    rowsInput.value = String(state.rows);
    colsInput.value = String(state.cols);
  }

  function themeColors() {
    const styles = getComputedStyle(document.body);
    const value = name => styles.getPropertyValue(name).trim();
    return {
      grid: value("--grid"),
      dead: value("--dead"),
      alive: value("--alive"),
      cursor: value("--cursor"),
      selection: value("--selection"),
      preview: value("--preview"),
      previewOutline: value("--preview-outline"),
      text: value("--text"),
      muted: value("--muted"),
      line: value("--line"),
      graphLine: value("--graph-line")
    };
  }

  function resizeCanvas() {
    const availableWidth = Math.max(1, canvasShell.clientWidth);
    const availableHeight = Math.max(1, canvasShell.clientHeight);
    const ratio = state.cols / state.rows;
    let cssWidth = availableWidth;
    let cssHeight = cssWidth / ratio;
    if (cssHeight > availableHeight) {
      cssHeight = availableHeight;
      cssWidth = cssHeight * ratio;
    }
    const scale = Math.min(window.devicePixelRatio || 1, 2);
    canvas.style.width = `${Math.floor(cssWidth)}px`;
    canvas.style.height = `${Math.floor(cssHeight)}px`;
    const nextWidth = Math.max(1, Math.floor(cssWidth * scale));
    const nextHeight = Math.max(1, Math.floor(cssHeight * scale));
    if (canvas.width !== nextWidth || canvas.height !== nextHeight) {
      canvas.width = nextWidth;
      canvas.height = nextHeight;
    }
    drawAll();
  }

  function drawGrid() {
    const colors = themeColors();
    const cellWidth = canvas.width / state.cols;
    const cellHeight = canvas.height / state.rows;
    const gap = Math.min(cellWidth, cellHeight) >= 6 ? Math.max(1, Math.floor(window.devicePixelRatio || 1)) : 0;
    context.fillStyle = colors.grid;
    context.fillRect(0, 0, canvas.width, canvas.height);

    for (let row = 0; row < state.rows; row += 1) {
      for (let col = 0; col < state.cols; col += 1) {
        const key = `${row}:${col}`;
        let fill = state.grid[row][col] ? colors.alive : colors.dead;
        if (state.selection.has(key)) fill = colors.selection;
        context.fillStyle = fill;
        context.fillRect(
          col * cellWidth + gap,
          row * cellHeight + gap,
          Math.max(1, cellWidth - gap * 2),
          Math.max(1, cellHeight - gap * 2)
        );
      }
    }

    if (state.pendingPattern && state.patternAnchor) {
      const { row: anchorRow, col: anchorCol } = state.patternAnchor;
      state.pendingPattern.forEach((patternRow, rowOffset) => {
        patternRow.forEach((cell, colOffset) => {
          const row = anchorRow + rowOffset;
          const col = anchorCol + colOffset;
          if (!cell || row < 0 || row >= state.rows || col < 0 || col >= state.cols) return;
          context.globalAlpha = 0.62;
          context.fillStyle = colors.preview;
          context.fillRect(col * cellWidth + gap, row * cellHeight + gap, cellWidth - gap * 2, cellHeight - gap * 2);
          context.globalAlpha = 1;
          context.strokeStyle = colors.previewOutline;
          context.lineWidth = Math.max(1, window.devicePixelRatio || 1);
          context.strokeRect(col * cellWidth + gap, row * cellHeight + gap, cellWidth - gap * 2, cellHeight - gap * 2);
        });
      });
    }

    context.strokeStyle = colors.cursor;
    context.lineWidth = Math.max(2, (window.devicePixelRatio || 1) * 1.5);
    context.strokeRect(
      state.cursor.col * cellWidth + 1,
      state.cursor.row * cellHeight + 1,
      Math.max(1, cellWidth - 2),
      Math.max(1, cellHeight - 2)
    );
  }

  function resizeGraph() {
    const rect = graphCanvas.getBoundingClientRect();
    const scale = Math.min(window.devicePixelRatio || 1, 2);
    graphCanvas.width = Math.max(1, Math.floor(rect.width * scale));
    graphCanvas.height = Math.max(1, Math.floor(rect.height * scale));
  }

  function drawGraph() {
    resizeGraph();
    const colors = themeColors();
    const width = graphCanvas.width;
    const height = graphCanvas.height;
    const scale = Math.min(window.devicePixelRatio || 1, 2);
    const left = 40 * scale;
    const right = width - 12 * scale;
    const top = 22 * scale;
    const bottom = height - 22 * scale;
    const values = state.populationHistory.length ? state.populationHistory : [0];
    const maximum = Math.max(...values, 1);
    const last = Math.max(1, values.length - 1);

    graphContext.clearRect(0, 0, width, height);
    graphContext.fillStyle = colors.dead;
    graphContext.fillRect(0, 0, width, height);
    graphContext.strokeStyle = colors.line;
    graphContext.lineWidth = scale;
    graphContext.beginPath();
    graphContext.moveTo(left, top);
    graphContext.lineTo(left, bottom);
    graphContext.lineTo(right, bottom);
    graphContext.stroke();

    graphContext.fillStyle = colors.text;
    graphContext.font = `bold ${11 * scale}px -apple-system, system-ui`;
    graphContext.fillText(`Live cells over generations: ${values.at(-1)}`, left, 14 * scale);
    graphContext.fillStyle = colors.muted;
    graphContext.font = `${9 * scale}px -apple-system, system-ui`;
    graphContext.fillText("0", left - 3 * scale, bottom + 13 * scale);
    graphContext.fillText(String(state.generation), right - 8 * scale, bottom + 13 * scale);
    graphContext.fillText(String(maximum), 4 * scale, top + 3 * scale);

    graphContext.strokeStyle = colors.graphLine;
    graphContext.lineWidth = 2 * scale;
    graphContext.beginPath();
    values.forEach((value, index) => {
      const x = left + (index / last) * (right - left);
      const y = bottom - (value / maximum) * (bottom - top);
      if (index === 0) graphContext.moveTo(x, y);
      else graphContext.lineTo(x, y);
    });
    graphContext.stroke();
    const lastX = left + ((values.length - 1) / last) * (right - left);
    const lastY = bottom - (values.at(-1) / maximum) * (bottom - top);
    graphContext.fillStyle = colors.graphLine;
    graphContext.beginPath();
    graphContext.arc(lastX, lastY, 3 * scale, 0, Math.PI * 2);
    graphContext.fill();
  }

  function drawAll() {
    refreshLabels();
    drawGrid();
    drawGraph();
  }

  function recordGenerationZeroEdit() {
    if (state.generation === 0) state.editHistory.push(copyGrid(state.grid));
  }

  function recordCurrentPopulation() {
    const live = countLiveCells();
    if (state.populationHistory.length) state.populationHistory[state.populationHistory.length - 1] = live;
    else state.populationHistory = [live];
    if (state.generation === 0) state.generationZeroGrid = copyGrid(state.grid);
  }

  function stop() {
    state.running = false;
    window.clearTimeout(state.timer);
    state.timer = null;
    refreshLabels();
  }

  function advanceGeneration() {
    const oldGrid = copyGrid(state.grid);
    state.history.push({
      grid: oldGrid,
      generation: state.generation,
      populationHistory: state.populationHistory.slice()
    });
    const next = makeGrid();
    for (let row = 0; row < state.rows; row += 1) {
      for (let col = 0; col < state.cols; col += 1) {
        let neighbours = 0;
        for (let rowOffset = -1; rowOffset <= 1; rowOffset += 1) {
          for (let colOffset = -1; colOffset <= 1; colOffset += 1) {
            if (rowOffset === 0 && colOffset === 0) continue;
            const otherRow = row + rowOffset;
            const otherCol = col + colOffset;
            if (otherRow >= 0 && otherRow < state.rows && otherCol >= 0 && otherCol < state.cols) {
              neighbours += state.grid[otherRow][otherCol];
            }
          }
        }
        next[row][col] = state.grid[row][col]
          ? Number(neighbours >= state.survivalMin && neighbours <= state.survivalMax)
          : Number(neighbours === state.birthCount);
      }
    }
    state.grid = next;
    state.generation += 1;
    state.populationHistory.push(countLiveCells());
    markDirty();
    const stable = gridsEqual(oldGrid, next);
    drawAll();
    if (stable && countLiveCells() > 0) setStatus(`Stable at Generation ${state.generation}: live cells are unchanged.`);
    return stable;
  }

  function gridsEqual(left, right) {
    return left.every((row, rowIndex) => row.every((cell, colIndex) => cell === right[rowIndex][colIndex]));
  }

  function tick() {
    if (!state.running) return;
    advanceGeneration();
    if (countLiveCells() === 0) {
      stop();
      setStatus(`Stopped at Generation ${state.generation}: all cells died.`);
      return;
    }
    state.timer = window.setTimeout(tick, state.delaySeconds * 1000);
  }

  function toggleRunning() {
    if (state.running) {
      stop();
      setStatus(`Paused at Generation ${state.generation}.`);
      return;
    }
    if (countLiveCells() === 0) {
      setStatus("Add live cells before starting.");
      return;
    }
    state.delaySeconds = clampDelay(delayInput.value);
    delayInput.value = state.delaySeconds.toFixed(2);
    state.running = true;
    refreshLabels();
    tick();
  }

  function stepOnce() {
    stop();
    advanceGeneration();
  }

  function clearGrid() {
    stop();
    if (state.generation === 0 && countLiveCells() > 0) recordGenerationZeroEdit();
    else if (state.generation !== 0) state.editHistory = [];
    state.grid = makeGrid();
    state.generationZeroGrid = copyGrid(state.grid);
    state.history = [];
    state.populationHistory = [0];
    state.generation = 0;
    clearSelection();
    markDirty();
    setStatus("Canvas cleared.");
    drawAll();
  }

  function randomize() {
    stop();
    if (state.generation === 0) recordGenerationZeroEdit();
    else state.editHistory = [];
    const density = clampInt(densityInput.value, 1, 100, 25);
    densityInput.value = String(density);
    state.grid = makeGrid().map(row => row.map(() => Number(Math.random() * 100 < density)));
    state.generation = 0;
    state.history = [];
    state.populationHistory = [countLiveCells()];
    state.generationZeroGrid = copyGrid(state.grid);
    clearSelection();
    markDirty();
    setStatus(`Generated Generation 0 at ${density}% density.`);
    drawAll();
  }

  function undoEdit() {
    if (state.generation !== 0) {
      setStatus("Use Back to return to earlier generations.");
      return;
    }
    if (!state.editHistory.length) {
      setStatus("Nothing to undo in Generation 0.");
      return;
    }
    state.grid = state.editHistory.pop();
    state.populationHistory = [countLiveCells()];
    state.generationZeroGrid = copyGrid(state.grid);
    markDirty();
    setStatus("Undid the last Generation 0 edit.");
    drawAll();
  }

  function backGeneration() {
    if (!state.history.length) {
      setStatus("No previous generation to go back to.");
      return;
    }
    stop();
    const snapshot = state.history.pop();
    state.grid = snapshot.grid;
    state.generation = snapshot.generation;
    state.populationHistory = snapshot.populationHistory;
    if (state.generation === 0) state.generationZeroGrid = copyGrid(state.grid);
    markDirty();
    setStatus(`Back to Generation ${state.generation}.`);
    drawAll();
  }

  function resetGenerationZero() {
    stop();
    state.grid = copyGrid(state.generationZeroGrid);
    state.history = [];
    state.generation = 0;
    state.populationHistory = [countLiveCells()];
    clearSelection();
    markDirty();
    setStatus("Reset to Generation 0.");
    drawAll();
  }

  function applyDimensions() {
    const rows = clampInt(rowsInput.value, MIN_ROWS, MAX_ROWS, state.rows);
    const cols = clampInt(colsInput.value, MIN_COLS, MAX_COLS, state.cols);
    rowsInput.value = String(rows);
    colsInput.value = String(cols);
    if (rows === state.rows && cols === state.cols) return;
    stop();
    const old = state.grid;
    const oldRows = state.rows;
    const oldCols = state.cols;
    state.rows = rows;
    state.cols = cols;
    state.grid = makeGrid();
    for (let row = 0; row < Math.min(rows, oldRows); row += 1) {
      for (let col = 0; col < Math.min(cols, oldCols); col += 1) state.grid[row][col] = old[row][col];
    }
    state.cursor.row = Math.min(state.cursor.row, rows - 1);
    state.cursor.col = Math.min(state.cursor.col, cols - 1);
    state.history = [];
    state.editHistory = [];
    state.generation = 0;
    state.populationHistory = [countLiveCells()];
    state.generationZeroGrid = copyGrid(state.grid);
    clearSelection();
    markDirty();
    setStatus(`Board resized to ${rows} rows × ${cols} columns.`);
    resizeCanvas();
  }

  function cellForPointer(event) {
    const rect = canvas.getBoundingClientRect();
    const col = Math.floor(((event.clientX - rect.left) / rect.width) * state.cols);
    const row = Math.floor(((event.clientY - rect.top) / rect.height) * state.rows);
    return row >= 0 && row < state.rows && col >= 0 && col < state.cols ? { row, col } : null;
  }

  function cellsBetween(start, end) {
    const rowDistance = end.row - start.row;
    const colDistance = end.col - start.col;
    const steps = Math.max(Math.abs(rowDistance), Math.abs(colDistance));
    if (steps === 0) return [start];
    const cells = [];
    for (let step = 0; step <= steps; step += 1) {
      const cell = {
        row: Math.round(start.row + rowDistance * step / steps),
        col: Math.round(start.col + colDistance * step / steps)
      };
      const previous = cells.at(-1);
      if (!previous || previous.row !== cell.row || previous.col !== cell.col) cells.push(cell);
    }
    return cells;
  }

  function beginPointer(event) {
    const cell = cellForPointer(event);
    if (!cell) return;
    event.preventDefault();
    state.cursor = cell;

    if (state.pendingPattern) {
      state.patternAnchor = cell;
      placePendingPattern();
      return;
    }

    state.pointerActive = true;
    state.pointerCells = new Set();
    state.lastPointerCell = cell;
    canvas.setPointerCapture(event.pointerId);
    if (state.selectionMode) {
      state.selection.clear();
      addSelectionCell(cell);
    } else {
      recordGenerationZeroEdit();
      togglePointerCell(cell);
      markDirty();
      recordCurrentPopulation();
    }
    drawAll();
  }

  function movePointer(event) {
    const cell = cellForPointer(event);
    if (!cell) return;
    if (state.pendingPattern && !state.pointerActive) {
      state.patternAnchor = cell;
      drawGrid();
      return;
    }
    if (!state.pointerActive) return;
    event.preventDefault();
    for (const dragCell of cellsBetween(state.lastPointerCell, cell)) {
      if (state.selectionMode) addSelectionCell(dragCell);
      else togglePointerCell(dragCell);
    }
    state.lastPointerCell = cell;
    state.cursor = cell;
    if (!state.selectionMode) {
      markDirty();
      recordCurrentPopulation();
    }
    drawAll();
  }

  function endPointer(event) {
    state.pointerActive = false;
    state.pointerCells.clear();
    state.lastPointerCell = null;
    if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
  }

  function togglePointerCell(cell) {
    const key = `${cell.row}:${cell.col}`;
    if (state.pointerCells.has(key)) return;
    state.pointerCells.add(key);
    state.grid[cell.row][cell.col] ^= 1;
  }

  function addSelectionCell(cell) {
    state.selection.add(`${cell.row}:${cell.col}`);
  }

  function clearSelection() {
    state.selection.clear();
    state.selectionMode = false;
  }

  function toggleSelectionMode() {
    if (state.pendingPattern) cancelModes();
    state.selectionMode = !state.selectionMode;
    if (!state.selectionMode) state.selection.clear();
    setStatus(state.selectionMode ? "Drag across cells to select a block." : "Selection cleared.");
    drawAll();
  }

  function selectionBounds() {
    const cells = [...state.selection].map(key => key.split(":").map(Number));
    return {
      minRow: Math.min(...cells.map(([row]) => row)),
      maxRow: Math.max(...cells.map(([row]) => row)),
      minCol: Math.min(...cells.map(([, col]) => col)),
      maxCol: Math.max(...cells.map(([, col]) => col))
    };
  }

  function copySelection() {
    if (!state.selection.size) {
      setStatus("Select cells before copying.");
      return;
    }
    const bounds = selectionBounds();
    state.clipboard = state.grid
      .slice(bounds.minRow, bounds.maxRow + 1)
      .map(row => row.slice(bounds.minCol, bounds.maxCol + 1));
    const rows = state.clipboard.length;
    const cols = state.clipboard[0].length;
    clearSelection();
    setStatus(`Copied ${rows} × ${cols} cells.`);
    drawAll();
  }

  function pasteSelection() {
    if (!state.clipboard) {
      setStatus("Nothing copied yet.");
      return;
    }
    recordGenerationZeroEdit();
    const blockRows = state.clipboard.length;
    const blockCols = state.clipboard[0].length;
    const startRow = state.cursor.row;
    const startCol = state.cursor.col - blockCols + 1;
    let pasted = 0;
    for (let row = 0; row < blockRows; row += 1) {
      for (let col = 0; col < blockCols; col += 1) {
        const targetRow = startRow + row;
        const targetCol = startCol + col;
        if (targetRow >= 0 && targetRow < state.rows && targetCol >= 0 && targetCol < state.cols) {
          state.grid[targetRow][targetCol] = state.clipboard[row][col];
          pasted += 1;
        }
      }
    }
    if (pasted) markDirty();
    recordCurrentPopulation();
    setStatus(`Pasted ${pasted} cells.`);
    drawAll();
  }

  function cancelModes() {
    state.pendingPattern = null;
    state.pendingPatternName = null;
    state.patternAnchor = null;
    clearSelection();
    setStatus("Selection or pattern placement cancelled.");
    drawAll();
  }

  function placePendingPattern() {
    if (!state.pendingPattern || !state.patternAnchor) return;
    recordGenerationZeroEdit();
    let placed = 0;
    state.pendingPattern.forEach((row, rowOffset) => row.forEach((cell, colOffset) => {
      const targetRow = state.patternAnchor.row + rowOffset;
      const targetCol = state.patternAnchor.col + colOffset;
      if (cell && targetRow >= 0 && targetRow < state.rows && targetCol >= 0 && targetCol < state.cols) {
        state.grid[targetRow][targetCol] = 1;
        placed += 1;
      }
    }));
    const name = state.pendingPatternName || "pattern";
    state.pendingPattern = null;
    state.pendingPatternName = null;
    state.patternAnchor = null;
    if (placed) markDirty();
    recordCurrentPopulation();
    setStatus(`Placed '${name}' with ${placed} live cells.`);
    drawAll();
  }

  function refreshSavedCanvases(selectedName = "") {
    const canvases = storageRead(STORAGE_CANVASES);
    const names = Object.keys(canvases).sort((left, right) => left.localeCompare(right, undefined, { sensitivity: "base" }));
    savedCanvasesSelect.replaceChildren();
    if (!names.length) {
      savedCanvasesSelect.add(new Option("No saved canvases", ""));
      return;
    }
    names.forEach(name => savedCanvasesSelect.add(new Option(name, name)));
    savedCanvasesSelect.value = names.includes(selectedName) ? selectedName : names[0];
  }

  function buildCanvasData(name) {
    return {
      app: "Conway's Game of Life Tool",
      version: SAVE_VERSION,
      name,
      rows: state.rows,
      cols: state.cols,
      generation: state.generation,
      population_history: state.populationHistory.slice(),
      generation_zero_grid: copyGrid(state.generationZeroGrid),
      grid: copyGrid(state.grid),
      rules: {
        survival_min: state.survivalMin,
        survival_max: state.survivalMax,
        birth_count: state.birthCount
      }
    };
  }

  function sanitizeName(name) {
    const safe = name.replace(/[^\p{L}\p{N} _-]/gu, "_").trim().replace(/\s+/g, "_");
    return safe || "canvas";
  }

  async function saveNamedCanvas() {
    const name = (await promptText("Save Canvas", "Enter a name for this canvas:"))?.trim();
    if (!name) return false;
    const canvases = storageRead(STORAGE_CANVASES);
    if (canvases[name] && !(await confirmDialog("Replace Canvas", `A saved canvas named '${name}' already exists. Replace it?`))) return false;
    canvases[name] = buildCanvasData(name);
    storageWrite(STORAGE_CANVASES, canvases);
    writeCanvasToFolder(name, canvases[name]);
    markClean();
    refreshSavedCanvases(name);
    setStatus(`Saved canvas '${name}' locally.`);
    return true;
  }

  async function confirmReplace(actionName) {
    if (!state.dirty) return true;
    const choice = await showDialog({
      title: "Unsaved Canvas",
      buildBody: body => { body.textContent = `You have unsaved changes before ${actionName}.`; },
      actions: [
        { label: "Save", value: "save", primary: true },
        { label: "Continue", value: "continue" },
        { label: "Cancel", value: "cancel" }
      ]
    });
    if (choice === "continue") return true;
    if (choice === "save") return saveNamedCanvas();
    return false;
  }

  async function loadSelectedCanvas() {
    const name = savedCanvasesSelect.value;
    if (!name) {
      setStatus("No saved canvas selected.");
      return;
    }
    if (!(await confirmReplace("opening a saved canvas"))) return;
    const data = storageRead(STORAGE_CANVASES)[name];
    try {
      applyCanvasData(data, name);
    } catch (error) {
      await alertDialog("Open Failed", error.message);
    }
  }

  async function deleteSelectedCanvas() {
    const name = savedCanvasesSelect.value;
    if (!name) {
      setStatus("No saved canvas selected to remove.");
      return;
    }
    if (!(await confirmDialog("Remove Canvas", `Remove saved canvas '${name}'?`))) return;
    const canvases = storageRead(STORAGE_CANVASES);
    const filename = folderState.filenames.get(name) || canvasFilename(name);
    delete canvases[name];
    storageWrite(STORAGE_CANVASES, canvases);
    folderState.filenames.delete(name);
    if (folderState.connected) postFolderMessage("delete", { filename });
    refreshSavedCanvases();
    setStatus(`Removed saved canvas '${name}'.`);
  }

  async function exportCanvas() {
    const name = (await promptText("Export Canvas", "Enter a name for this export:"))?.trim();
    if (!name) return;
    const filename = `${sanitizeName(name)}.life.json`;
    const text = JSON.stringify(buildCanvasData(name), null, 2);
    if (window.webkit?.messageHandlers?.exportFile) {
      window.webkit.messageHandlers.exportFile.postMessage({ filename, text });
    } else {
      const link = document.createElement("a");
      link.href = URL.createObjectURL(new Blob([text], { type: "application/json" }));
      link.download = filename;
      link.click();
      URL.revokeObjectURL(link.href);
    }
    markClean();
    setStatus(`Exported canvas '${name}'.`);
  }

  async function importCanvasFile(file) {
    if (!file || !(await confirmReplace("importing a canvas"))) return;
    try {
      const data = JSON.parse(await file.text());
      applyCanvasData(data, data.name || file.name);
      markClean();
    } catch (error) {
      await alertDialog("Open Failed", error.message || "The selected file is not valid JSON.");
    } finally {
      importInput.value = "";
    }
  }

  function validateRuleValues(survivalMin, survivalMax, birthCount) {
    for (const [label, value] of [["Survival minimum", survivalMin], ["Survival maximum", survivalMax], ["Birth count", birthCount]]) {
      if (!Number.isInteger(value)) throw new Error(`${label} must be a whole number.`);
      if (value < 0 || value > 8) throw new Error(`${label} must be between 0 and 8.`);
    }
    if (survivalMin > survivalMax) throw new Error("Survival minimum cannot be greater than survival maximum.");
  }

  function validateGrid(grid, rows, cols, label) {
    if (!Array.isArray(grid) || grid.length !== rows) throw new Error(`${label} does not match the saved row count.`);
    grid.forEach(row => {
      if (!Array.isArray(row) || row.length !== cols) throw new Error(`${label} does not match the saved column count.`);
      if (row.some(cell => cell !== 0 && cell !== 1)) throw new Error(`${label} cells must be 0 or 1.`);
    });
  }

  function validateCanvasData(data) {
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("Canvas file is not a JSON object.");
    if (!Number.isInteger(data.rows) || !Number.isInteger(data.cols)) throw new Error("Canvas file is missing row or column counts.");
    if (data.rows < MIN_ROWS || data.rows > MAX_ROWS || data.cols < MIN_COLS || data.cols > MAX_COLS) throw new Error("Canvas size is outside the supported range.");
    validateGrid(data.grid, data.rows, data.cols, "Canvas grid");
    if (data.generation_zero_grid != null) validateGrid(data.generation_zero_grid, data.rows, data.cols, "Generation 0 grid");
    if (data.rules != null) {
      if (typeof data.rules !== "object" || Array.isArray(data.rules)) throw new Error("Saved rules must be a JSON object.");
      validateRuleValues(
        Number(data.rules.survival_min ?? DEFAULT_SURVIVAL_MIN),
        Number(data.rules.survival_max ?? DEFAULT_SURVIVAL_MAX),
        Number(data.rules.birth_count ?? DEFAULT_BIRTH_COUNT)
      );
    }
  }

  function applyCanvasData(data, sourceName = "canvas") {
    validateCanvasData(data);
    stop();
    state.rows = data.rows;
    state.cols = data.cols;
    state.grid = copyGrid(data.grid);
    state.generation = Math.max(0, Number.parseInt(data.generation || 0, 10) || 0);
    state.survivalMin = Number(data.rules?.survival_min ?? DEFAULT_SURVIVAL_MIN);
    state.survivalMax = Number(data.rules?.survival_max ?? DEFAULT_SURVIVAL_MAX);
    state.birthCount = Number(data.rules?.birth_count ?? DEFAULT_BIRTH_COUNT);
    state.history = [];
    state.editHistory = [];
    state.selection.clear();
    state.selectionMode = false;
    state.pendingPattern = null;
    state.pendingPatternName = null;
    state.patternAnchor = null;
    const savedPopulation = Array.isArray(data.population_history) && data.population_history.length
      ? data.population_history.map(value => Math.max(0, Number.parseInt(value, 10) || 0))
      : [countLiveCells()];
    state.populationHistory = savedPopulation;
    state.populationHistory[state.populationHistory.length - 1] = countLiveCells();
    state.generationZeroGrid = data.generation_zero_grid ? copyGrid(data.generation_zero_grid) : copyGrid(state.grid);
    state.cursor.row = Math.min(state.cursor.row, state.rows - 1);
    state.cursor.col = Math.min(state.cursor.col, state.cols - 1);
    markClean();
    setStatus(`Opened '${sourceName}'.`);
    resizeCanvas();
  }

  function buildPatternData(name, block) {
    return {
      app: "Conway's Game of Life Tool",
      type: "pattern",
      version: SAVE_VERSION,
      name,
      rows: block.length,
      cols: block[0].length,
      grid: copyGrid(block)
    };
  }

  async function savePattern() {
    if (!state.selection.size) {
      setStatus("Select a block before saving it to the Pattern Library.");
      return;
    }
    const name = (await promptText("Save Pattern", "Enter a name for this pattern:"))?.trim();
    if (!name) return;
    const bounds = selectionBounds();
    const block = state.grid.slice(bounds.minRow, bounds.maxRow + 1).map(row => row.slice(bounds.minCol, bounds.maxCol + 1));
    const patterns = storageRead(STORAGE_PATTERNS);
    if (patterns[name] && !(await confirmDialog("Replace Pattern", `A saved pattern named '${name}' already exists. Replace it?`))) return;
    patterns[name] = buildPatternData(name, block);
    storageWrite(STORAGE_PATTERNS, patterns);
    setStatus(`Saved pattern '${name}' locally.`);
  }

  async function showPatternLibrary() {
    const saved = storageRead(STORAGE_PATTERNS);
    const entries = [
      ...DEFAULT_PATTERNS.map(([name, grid]) => ({ source: "Built-in", name, grid })),
      ...Object.keys(saved).sort().map(name => ({ source: "Saved", name, grid: saved[name].grid }))
    ];
    await showDialog({
      title: "Pattern Library",
      buildBody: body => {
        const intro = document.createElement("p");
        intro.textContent = "Choose a pattern to place on the canvas.";
        const list = document.createElement("div");
        list.className = "pattern-list";
        entries.forEach(entry => {
          const row = document.createElement("div");
          row.className = "pattern-row";
          const text = document.createElement("div");
          const strong = document.createElement("strong");
          strong.textContent = entry.name;
          const small = document.createElement("small");
          small.textContent = `${entry.source} · ${entry.grid.length} × ${entry.grid[0].length}`;
          text.append(strong, small);
          const actions = document.createElement("div");
          const place = document.createElement("button");
          place.type = "button";
          place.textContent = "Place";
          place.addEventListener("click", () => {
            state.pendingPattern = copyGrid(entry.grid);
            state.pendingPatternName = entry.name;
            state.patternAnchor = { ...state.cursor };
            state.selectionMode = false;
            state.selection.clear();
            dialog.close("place");
            setStatus(`Tap the canvas to place '${entry.name}'.`);
            drawAll();
          });
          actions.append(place);
          if (entry.source === "Saved") {
            const remove = document.createElement("button");
            remove.type = "button";
            remove.className = "danger";
            remove.textContent = "×";
            remove.setAttribute("aria-label", `Delete ${entry.name}`);
            remove.addEventListener("click", async () => {
              dialog.close("remove-request");
              if (!(await confirmDialog("Remove Pattern", `Remove saved pattern '${entry.name}'?`))) return;
              const patterns = storageRead(STORAGE_PATTERNS);
              delete patterns[entry.name];
              storageWrite(STORAGE_PATTERNS, patterns);
              setStatus(`Removed saved pattern '${entry.name}'.`);
            });
            actions.append(remove);
          }
          row.append(text, actions);
          list.append(row);
        });
        body.append(intro, list);
      },
      actions: [{ label: "Close", value: "cancel" }]
    });
  }

  async function showRules() {
    const result = await showDialog({
      title: "Rules",
      buildBody: body => {
        const intro = document.createElement("p");
        intro.textContent = "Classic Conway uses survival from 2 to 3 neighbors and birth at exactly 3. Change these numbers to experiment with nearby rule sets.";
        const fields = [
          ["Survival minimum", "rule-survival-min", state.survivalMin],
          ["Survival maximum", "rule-survival-max", state.survivalMax],
          ["Birth count", "rule-birth", state.birthCount]
        ];
        body.append(intro);
        fields.forEach(([labelText, id, value]) => {
          const label = document.createElement("label");
          label.textContent = labelText;
          const input = document.createElement("input");
          input.id = id;
          input.type = "number";
          input.min = "0";
          input.max = "8";
          input.value = String(value);
          label.append(input);
          body.append(label);
        });
        const life = document.createElement("div");
        life.className = "rule-card";
        life.textContent = `Living cells stay alive with ${state.survivalMin} through ${state.survivalMax} living neighbors. Dead cells are born with exactly ${state.birthCount}.`;
        body.append(life);
      },
      actions: [
        { label: "Classic Conway", value: "classic" },
        { label: "Apply", value: "apply", primary: true },
        { label: "Close", value: "cancel" }
      ]
    });
    if (result === "cancel") return;
    let survivalMin = DEFAULT_SURVIVAL_MIN;
    let survivalMax = DEFAULT_SURVIVAL_MAX;
    let birthCount = DEFAULT_BIRTH_COUNT;
    if (result === "apply") {
      survivalMin = Number($("#rule-survival-min")?.value);
      survivalMax = Number($("#rule-survival-max")?.value);
      birthCount = Number($("#rule-birth")?.value);
    }
    try {
      validateRuleValues(survivalMin, survivalMax, birthCount);
      const changed = survivalMin !== state.survivalMin || survivalMax !== state.survivalMax || birthCount !== state.birthCount;
      state.survivalMin = survivalMin;
      state.survivalMax = survivalMax;
      state.birthCount = birthCount;
      if (changed) markDirty();
      setStatus(result === "classic" ? "Rules reverted to classic Conway." : `Rules updated: survival ${survivalMin}–${survivalMax}, birth ${birthCount}.`);
      drawAll();
    } catch (error) {
      await alertDialog("Invalid Rules", error.message);
    }
  }

  const TOUR_STEPS = [
    ["Welcome", "This is Conway's Game Of Life Lab. Cells are either alive or dead. Press Start and simple local rules create surprising patterns."],
    ["Draw", "Tap, hold and drag, or use Apple Pencil to toggle cells on the grid. Use Generate to make a random starting world and Random % to control how full it is."],
    ["Run", "Start runs or pauses the simulation. Step advances exactly one generation. Undo is for Generation 0 edits; Back returns to previous generations."],
    ["Select And Paste", "Tap Select Cells, then drag across cells. Copy stores the smallest rectangle around the selection. Paste uses the blue cursor as the block's top-right corner."],
    ["Patterns", "Save selected cells to your Pattern Library, or place built-in and saved shapes. Tap the canvas to place a chosen pattern."],
    ["Rules And Looks", "Rules experiments beyond classic Conway. Mode switches Light, Dark, and Sepia. Save Canvas keeps work on this device; Export creates a desktop-compatible file."],
    ["Demo", "Load the Cross demo pattern, tap to place it, then press Start or Step."]
  ];

  async function showTour(markSeen = false) {
    if (markSeen) {
      const preferences = storageRead(STORAGE_PREFERENCES);
      preferences.tour_seen = true;
      storageWrite(STORAGE_PREFERENCES, preferences);
    }
    let index = 0;
    while (index >= 0 && index < TOUR_STEPS.length) {
      const [title, text] = TOUR_STEPS[index];
      const actions = [];
      if (index > 0) actions.push({ label: "Back", value: "back" });
      if (title === "Demo") actions.push({ label: "Load Demo Pattern", value: "demo", primary: true });
      actions.push({ label: index === TOUR_STEPS.length - 1 ? "Done" : "Next", value: "next", primary: title !== "Demo" });
      actions.push({ label: "Close", value: "cancel" });
      const result = await showDialog({
        title: `Tour / Demo — ${title}`,
        buildBody: body => {
          const card = document.createElement("div");
          card.className = "tour-card";
          const paragraph = document.createElement("p");
          paragraph.textContent = text;
          const counter = document.createElement("small");
          counter.textContent = `${index + 1} of ${TOUR_STEPS.length}`;
          card.append(paragraph, counter);
          body.append(card);
        },
        actions
      });
      if (result === "back") index -= 1;
      else if (result === "next") index += 1;
      else if (result === "demo") {
        const cross = DEFAULT_PATTERNS.find(([name]) => name === "Cross")[1];
        state.pendingPattern = copyGrid(cross);
        state.pendingPatternName = "Demo Cross";
        state.patternAnchor = { ...state.cursor };
        setStatus("Tap the canvas to place 'Demo Cross'.");
        drawAll();
        return;
      } else return;
    }
  }

  async function showHelp() {
    await showDialog({
      title: "Help",
      buildBody: body => {
        const sections = [
          ["Grid editing", "Tap or hold and drag to toggle cells. Apple Pencil drawing works directly on the grid. The blue outline is the paste cursor."],
          ["Selection and clipboard", "Tap Select Cells and drag to select. Copy stores the selected rectangle. Paste places it using the cursor as its top-right corner. Cancel clears selection or pattern placement."],
          ["Simulation", "Step advances one generation. Back returns to the previous generation. Reset Gen 0 restores the starting canvas. Undo reverses Generation 0 edits."],
          ["Files and patterns", "Save/Load keeps named canvases locally on this device. Export/Import uses portable desktop-compatible JSON. Save selected blocks to the Pattern Library."],
          ["Rules and appearance", "Rules changes survival and birth numbers. Mode switches between Light, Dark, and Sepia."]
        ];
        sections.forEach(([heading, text]) => {
          const h3 = document.createElement("h3");
          h3.textContent = heading;
          const paragraph = document.createElement("p");
          paragraph.textContent = text;
          body.append(h3, paragraph);
        });
      },
      actions: [{ label: "Close", value: "cancel", primary: true }]
    });
  }

  function showDialog({ title, buildBody, actions }) {
    if (dialog.open) dialog.close("cancel");
    dialogTitle.textContent = title;
    dialogBody.replaceChildren();
    dialogActions.replaceChildren();
    buildBody(dialogBody);
    actions.forEach(action => {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = action.label;
      if (action.primary) button.classList.add("primary");
      button.addEventListener("click", () => dialog.close(action.value));
      dialogActions.append(button);
    });
    return new Promise(resolve => {
      dialog.addEventListener("close", () => resolve(dialog.returnValue || "cancel"), { once: true });
      dialog.showModal();
    });
  }

  async function promptText(title, message) {
    const result = await showDialog({
      title,
      buildBody: body => {
        const label = document.createElement("label");
        label.textContent = message;
        const input = document.createElement("input");
        input.id = "modal-text-input";
        input.type = "text";
        input.autocomplete = "off";
        label.append(input);
        body.append(label);
        setTimeout(() => input.focus(), 50);
      },
      actions: [{ label: "Cancel", value: "cancel" }, { label: "OK", value: "ok", primary: true }]
    });
    return result === "ok" ? $("#modal-text-input")?.value || "" : null;
  }

  async function confirmDialog(title, message) {
    const result = await showDialog({
      title,
      buildBody: body => { body.textContent = message; },
      actions: [{ label: "Cancel", value: "cancel" }, { label: "Confirm", value: "confirm", primary: true }]
    });
    return result === "confirm";
  }

  function alertDialog(title, message) {
    return showDialog({
      title,
      buildBody: body => { body.textContent = message; },
      actions: [{ label: "OK", value: "cancel", primary: true }]
    });
  }

  function applyTheme(mode) {
    state.theme = ["Light", "Dark", "Sepia"].includes(mode) ? mode : "Dark";
    document.body.dataset.theme = state.theme.toLowerCase();
    themeSelect.value = state.theme;
    drawAll();
  }

  canvas.addEventListener("pointerdown", beginPointer);
  canvas.addEventListener("pointermove", movePointer);
  canvas.addEventListener("pointerup", endPointer);
  canvas.addEventListener("pointercancel", endPointer);
  $('[data-action="toggle"]').addEventListener("click", toggleRunning);
  $('[data-action="step"]').addEventListener("click", stepOnce);
  $('[data-action="clear"]').addEventListener("click", clearGrid);
  $('[data-action="generate"]').addEventListener("click", randomize);
  $('[data-action="undo"]').addEventListener("click", undoEdit);
  $('[data-action="back"]').addEventListener("click", backGeneration);
  $('[data-action="reset"]').addEventListener("click", resetGenerationZero);
  $('[data-action="apply-size"]').addEventListener("click", applyDimensions);
  $('[data-action="selection-mode"]').addEventListener("click", toggleSelectionMode);
  $('[data-action="copy"]').addEventListener("click", copySelection);
  $('[data-action="paste"]').addEventListener("click", pasteSelection);
  $('[data-action="cancel-mode"]').addEventListener("click", cancelModes);
  $('[data-action="save-canvas"]').addEventListener("click", saveNamedCanvas);
  $('[data-action="load-canvas"]').addEventListener("click", loadSelectedCanvas);
  $('[data-action="delete-canvas"]').addEventListener("click", deleteSelectedCanvas);
  $('[data-action="export-canvas"]').addEventListener("click", exportCanvas);
  $('[data-action="import-canvas"]').addEventListener("click", () => importInput.click());
  $('[data-action="choose-data-folder"]').addEventListener("click", () => {
    if (!postFolderMessage("choose")) setStatus("Folder storage is available in the iOS app.");
  });
  importInput.addEventListener("change", () => importCanvasFile(importInput.files?.[0]));
  $('[data-action="save-pattern"]').addEventListener("click", savePattern);
  $('[data-action="pattern-library"]').addEventListener("click", showPatternLibrary);
  $('[data-action="rules"]').addEventListener("click", showRules);
  $('[data-action="tour"]').addEventListener("click", () => showTour(false));
  $('[data-action="help"]').addEventListener("click", showHelp);
  delayInput.addEventListener("change", () => {
    state.delaySeconds = clampDelay(delayInput.value);
    delayInput.value = state.delaySeconds.toFixed(2);
  });
  themeSelect.addEventListener("change", () => applyTheme(themeSelect.value));
  document.addEventListener("visibilitychange", () => { if (document.hidden) stop(); });
  new ResizeObserver(resizeCanvas).observe(canvasShell);
  new ResizeObserver(drawGraph).observe(graphCanvas.parentElement);

  window.lifeLab = {
    advance: advanceGeneration,
    applyCanvasData,
    buildCanvasData,
    clear: clearGrid,
    loadPattern(name) {
      const entry = DEFAULT_PATTERNS.find(([patternName]) => patternName.toLowerCase() === String(name).toLowerCase());
      if (!entry) throw new Error("Unknown pattern");
      state.grid = makeGrid();
      const grid = entry[1];
      const startRow = Math.max(0, Math.floor((state.rows - grid.length) / 2));
      const startCol = Math.max(0, Math.floor((state.cols - grid[0].length) / 2));
      grid.forEach((row, rowOffset) => row.forEach((cell, colOffset) => {
        if (cell) state.grid[startRow + rowOffset][startCol + colOffset] = 1;
      }));
      state.generation = 0;
      state.history = [];
      state.populationHistory = [countLiveCells()];
      state.generationZeroGrid = copyGrid(state.grid);
      drawAll();
    },
    snapshot: () => ({
      rows: state.rows,
      cols: state.cols,
      generation: state.generation,
      liveCells: countLiveCells(),
      running: state.running,
      rules: [state.survivalMin, state.survivalMax, state.birthCount],
      dirty: state.dirty
    })
  };

  refreshSavedCanvases();
  applyTheme("Dark");
  resizeCanvas();
  setStatus("Ready. Draw cells or choose a pattern.");
  postFolderMessage("status");
  const preferences = storageRead(STORAGE_PREFERENCES);
  if (!preferences.tour_seen) window.setTimeout(() => showTour(true), 500);
})();
