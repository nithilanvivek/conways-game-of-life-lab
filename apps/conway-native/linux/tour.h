#ifndef LIFE_TOUR_H
#define LIFE_TOUR_H
typedef struct {const char *title,*area,*text;} TourStep;
static const TourStep tour_steps[]={
{"Welcome to Conway\u2019s Game of Life Lab","Canvas","This tour covers the canvas, simulation, patterns, editing, files, rules and themes. Help restarts it anytime. Your canvas is preserved during the tour."},
{"An infinite canvas","Specify Chart Size","The canvas is infinite by default. Pan and zoom to explore in any direction. Specify Chart Size opens width and height fields: Apply sets a finite canvas, and Infinite returns to an infinite canvas. Wrap edges is available only on a finite canvas and connects opposite sides."},
{"Paint, erase and pan","Tools","Drag to paint or erase. B chooses Paint; E chooses Erase. Pan is outlined when off and filled when on; H toggles it. Hold Alt (Option on Mac) while dragging for temporary panning."},
{"Zoom and find your cells","Fit","Scroll or pinch to zoom around the pointer. + and \u2212 zoom in and out. F or Fit centers the living cells. Grid toggles the grid lines."},
{"Navigate and select","Unselect","The cell cursor starts at the canvas centre and stays separate from the mouse pointer. Arrow keys move the cell cursor. Shift+arrow keys and Shift+drag add squares to a selection. The selection stays while you move the cursor. Click Unselect or press Esc once to clear it."},
{"Edit selected cells","","Enter makes selected squares alive. Delete or Backspace makes them dead. Space inverts alive and dead. Without a selection, these keys act on the cursor square. Each edit is one undoable action."},
{"Copy and paste","Canvas","Ctrl+C copies the selected squares. Ctrl+V pastes the copied block centered on the current cursor square. The rest of the canvas stays intact."},
{"Place a pattern","Pattern Library","Choosing a pattern starts a translucent placement preview under your pointer. Move it to the desired square and click to place it. Placement adds the pattern\u2019s live cells and preserves existing cells, including those under blank pattern squares. Esc cancels the preview."},
{"Save your own patterns","Save to Pattern Library","Select squares, click Save to Pattern Library and give the pattern a name. It is stored locally and remains in the library after restarting the app. The button is disabled when nothing is selected."},
{"Run the simulation","Start","Start and Stop control playback. Step or . advances one generation. Duration is seconds between generations, from 0.1 to 10. Generation and Live cells show progress. Equilibrium reached appears when the grid stops changing; counting continues."},
{"Live-cell history","Population Graph","The line shows how the live-cell count changes over the latest 2,048 generations, without axes or scale labels. Step and playback extend it; edits update the current point. Back, Undo and Redo restore the matching graph. Clear, Generate and Reset Gen 0 start a fresh line. Saved canvases keep this history."},
{"Undo, redo and time travel","Undo","Ctrl+Z undoes; Ctrl+Y redoes. Back returns to an earlier generation. Reset Gen 0 or Ctrl+R restores the generation-zero canvas. Clear empties the canvas. These changes can be undone."},
{"Generate a random canvas","Generate","Random % gives each cell that chance of being alive; the resulting count is approximate. Generate fills the visible region on an infinite canvas, or the whole finite grid. Generate replaces the current cells and can be undone."},
{"Edit the rules","Edit Rules","Edit Rules changes survival minimum, survival maximum and birth neighbor counts. Counts are 0\u20138; minimum must not exceed maximum. Birth at zero requires a finite canvas. Reset to Classic Conway restores survival 2\u20133 and birth 3."},
{"Save and load locally","Save Canvas","Ctrl+S or Save Canvas opens a name popup. Load Canvas or Ctrl+O lists locally saved canvases. Editing a loaded canvas lets you overwrite it or save a new copy. Closing unsaved work offers Save, Discard and Cancel. Recovery autosaving does not count as an explicit save."},
{"Import and export","Export","Import opens a canvas file. Export saves a copy to share or use on another device. Save Canvas keeps your work in the app\u2019s library."},
{"Choose a theme","Theme","You can switch between Dark, Light and Sepia themes here."}
};
#define TOUR_COUNT (sizeof(tour_steps)/sizeof(tour_steps[0]))
#endif
