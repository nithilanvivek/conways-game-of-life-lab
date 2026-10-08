import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog
import copy
import json
import os
import random


class GameOfLifeApp(tk.Tk):
    MIN_ROWS = 5
    MAX_ROWS = 100
    MIN_COLS = 5
    MAX_COLS = 100
    MIN_DELAY_SECONDS = 0.1
    MAX_DELAY_SECONDS = 10.0
    DEFAULT_CELL_SIZE = 24
    MIN_CELL_SIZE = 4
    GRAPH_HEIGHT = 150
    GRAPH_PADDING = 28
    SCREEN_MARGIN_X = 80
    SCREEN_MARGIN_Y = 360
    SAVE_FILE_VERSION = 1
    SAVE_FILE_EXTENSION = ".life.json"
    PATTERN_FILE_EXTENSION = ".pattern.json"
    PREFERENCES_FILE_NAME = "preferences.json"
    DEFAULT_SURVIVAL_MIN = 2
    DEFAULT_SURVIVAL_MAX = 3
    DEFAULT_BIRTH_COUNT = 3
    LIGHT_THEME = {
        "grid": "#f0f0f0",
        "dead": "white",
        "alive": "black",
        "cursor": "blue",
        "selection": "#ff9f1c",
        "preview_fill": "#68d391",
        "preview_outline": "#1f7a3a",
        "graph_bg": "white",
        "graph_text": "#333",
        "graph_axis": "#bbb",
        "graph_label": "#555",
        "graph_line": "#1f6feb",
        "button_bg": "#f0f0f0",
        "button_fg": "black",
        "button_active": "#e2e2e2",
    }
    DARK_THEME = {
        "grid": "#171b22",
        "dead": "#0b0e13",
        "alive": "#5bd9a6",
        "cursor": "#8ab4ff",
        "selection": "#f5a623",
        "preview_fill": "#5bd9a6",
        "preview_outline": "#a2f2cf",
        "graph_bg": "#0b0e13",
        "graph_text": "#d7dde7",
        "graph_axis": "#343a46",
        "graph_label": "#9ca6b6",
        "graph_line": "#5bd9a6",
        "button_bg": "#20242c",
        "button_fg": "#5bd9a6",
        "button_active": "#2e3642",
    }
    SEPIA_THEME = {
        "grid": "#d9c39a",
        "dead": "#f5ead3",
        "alive": "#5a351d",
        "cursor": "#8a5a2b",
        "selection": "#b66a2a",
        "preview_fill": "#9d6b36",
        "preview_outline": "#4b2d18",
        "graph_bg": "#f5ead3",
        "graph_text": "#4b2d18",
        "graph_axis": "#bda27a",
        "graph_label": "#6d4a28",
        "graph_line": "#8a5a2b",
        "button_bg": "#ead8b8",
        "button_fg": "#4b2d18",
        "button_active": "#dcc49b",
    }
    DEFAULT_PATTERNS = [
        ("Block", [[1, 1], [1, 1]]),
        ("Beehive", [[0, 1, 1, 0], [1, 0, 0, 1], [0, 1, 1, 0]]),
        ("Tub", [[0, 1, 0], [1, 0, 1], [0, 1, 0]]),
        ("Seed", [[1, 0, 1], [1, 1, 0], [0, 1, 0]]),
        ("Blinker", [[1, 1, 1]]),
        ("Cross", [[0, 1, 0], [1, 1, 1], [0, 1, 0]]),
        ("Single Cell", [[1]]),
        ("Glider", [[0, 1, 0], [1, 0, 1], [0, 1, 1]]),
        ("Spaceship Seed", [[0, 1, 0, 0], [1, 0, 1, 0], [1, 0, 0, 1], [0, 1, 1, 0]]),
        ("Hollow Ring", [[0, 1, 1, 0], [1, 0, 0, 1], [1, 0, 0, 1], [0, 1, 1, 0]]),
    ]

    def __init__(self):
        super().__init__()
        self.title("Conway's Game of Life Lab v2.0")

        self.rows, self.cols = 20, 30
        self.delay_seconds = 0.5
        self.theme_mode = "Dark"
        self.survival_min = self.DEFAULT_SURVIVAL_MIN
        self.survival_max = self.DEFAULT_SURVIVAL_MAX
        self.birth_count = self.DEFAULT_BIRTH_COUNT
        self.cell_size = self.get_cell_size_for_board(self.rows, self.cols)
        self.canvas_w = self.cols * self.cell_size
        self.canvas_h = self.rows * self.cell_size

        self.grid = [[0 for _ in range(self.cols)] for _ in range(self.rows)]
        self.generation_zero_grid = copy.deepcopy(self.grid)
        self.history = []
        self.edit_history = []
        self.population_history = [self.count_live_cells()]
        self.generation = 0
        self.running = False
        self.after_id = None
        self.dirty = False

        self.cur_r, self.cur_c = 0, 0
        self.cursor_rect = None
        self.selection = None
        self.selection_anchor = None
        self.selection_drag_anchor = None
        self.selection_items = []
        self.clipboard = None
        self.drag_toggled_cells = set()
        self.last_drag_cell = None
        self.saved_canvas_names = []
        self.saved_pattern_names = []
        self.pending_pattern = None
        self.pending_pattern_name = None
        self.pattern_preview_anchor = None
        self.pattern_preview_items = []
        self.themed_buttons = []

        self.build_ui()
        self.maximize_window()
        self.draw_grid()
        self.update_canvas()
        self.bind_keys()
        self.protocol("WM_DELETE_WINDOW", self.on_close)
        self.after(300, self.show_first_run_tour_if_needed)

    def maximize_window(self):
        try:
            self.state("zoomed")
            return
        except tk.TclError:
            pass

        try:
            self.attributes("-zoomed", True)
            return
        except tk.TclError:
            pass

        self.geometry(f"{self.winfo_screenwidth()}x{self.winfo_screenheight()}+0+0")

    def build_ui(self):
        top = tk.Frame(self)
        top.pack(pady=6)

        self.make_button(top, "Save Canvas", self.save_named_canvas).pack(side=tk.LEFT, padx=4)
        self.saved_canvas_var = tk.StringVar(value="No saved canvases")
        self.saved_canvas_menu = self.make_dropdown(top, "No saved canvases", width=18)
        self.saved_canvas_menu.config(width=18)
        self.saved_canvas_menu.pack(side=tk.LEFT, padx=4)
        self.make_button(top, "X", self.delete_selected_canvas).pack(side=tk.LEFT, padx=(0, 4))
        self.make_button(top, "Load Canvas", self.load_selected_canvas).pack(side=tk.LEFT, padx=4)
        self.make_button(top, "Export", self.export_canvas).pack(side=tk.LEFT, padx=4)
        self.make_button(top, "Import", self.import_canvas).pack(side=tk.LEFT, padx=4)
        self.make_button(top, "Rules", self.show_rules).pack(side=tk.LEFT, padx=4)
        self.make_button(top, "Tour / Demo", lambda: self.show_tour(mark_seen=False)).pack(side=tk.LEFT, padx=4)
        self.make_button(top, "Help", self.show_help).pack(side=tk.LEFT, padx=4)
        self.refresh_saved_canvas_menu()

        self.gen_var = tk.StringVar(value="Generation: 0")
        tk.Label(self, textvariable=self.gen_var, font=("TkDefaultFont", 10, "bold")).pack(pady=(0, 2))

        self.status_var = tk.StringVar(value="")
        tk.Label(self, textvariable=self.status_var, fg="#555").pack()

        main_area = tk.Frame(self)
        main_area.pack(padx=8, pady=8)

        work_area = tk.Frame(main_area)
        work_area.pack()
        self.work_area = work_area

        left_controls = tk.Frame(work_area, width=180)
        left_controls.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 16))

        self.run_button = self.make_button(left_controls, "Start", self.toggle_running, primary=True)
        self.run_button.pack(fill=tk.X, pady=5)
        self.make_button(left_controls, "Step", self.step_once, primary=True).pack(fill=tk.X, pady=5)
        self.make_button(left_controls, "Clear", self.clear, primary=True).pack(fill=tk.X, pady=5)

        tk.Label(left_controls, text="Random %").pack(anchor="w", pady=(22, 2))
        self.random_density_var = tk.IntVar(value=25)
        tk.Spinbox(
            left_controls,
            from_=1,
            to=100,
            width=8,
            font=("TkDefaultFont", 10),
            textvariable=self.random_density_var,
        ).pack(fill=tk.X, pady=(0, 8))
        self.make_button(left_controls, "Generate", self.randomize_canvas, primary=True).pack(fill=tk.X, pady=5)

        self.save_pattern_button = self.make_button(
            left_controls,
            "Save to Pattern Library",
            self.save_pattern_to_library,
            state=tk.DISABLED,
        )
        self.save_pattern_button.pack(fill=tk.X, pady=(22, 5))
        self.make_button(left_controls, "Pattern Library", self.show_pattern_library, primary=True).pack(fill=tk.X, pady=5)

        center = tk.Frame(work_area)
        center.pack(side=tk.LEFT)

        right_controls = tk.Frame(work_area, width=190)
        right_controls.pack(side=tk.LEFT, fill=tk.Y, padx=(16, 0))

        tk.Label(right_controls, text="Rows").pack(anchor="w", pady=(4, 2))
        self.rows_var = tk.IntVar(value=self.rows)
        tk.Spinbox(
            right_controls,
            from_=self.MIN_ROWS,
            to=self.MAX_ROWS,
            width=8,
            font=("TkDefaultFont", 10),
            textvariable=self.rows_var,
            command=self.apply_dimensions,
        ).pack(fill=tk.X, pady=(0, 8))

        tk.Label(right_controls, text="Columns").pack(anchor="w", pady=(4, 2))
        self.cols_var = tk.IntVar(value=self.cols)
        tk.Spinbox(
            right_controls,
            from_=self.MIN_COLS,
            to=self.MAX_COLS,
            width=8,
            font=("TkDefaultFont", 10),
            textvariable=self.cols_var,
            command=self.apply_dimensions,
        ).pack(fill=tk.X, pady=(0, 8))

        self.make_button(right_controls, "Apply Size", self.apply_dimensions, primary=True).pack(fill=tk.X, pady=5)
        self.make_button(right_controls, "Undo", self.undo_edit, primary=True).pack(fill=tk.X, pady=(14, 5))
        self.make_button(right_controls, "Back", self.back_generation, primary=True).pack(fill=tk.X, pady=5)
        self.make_button(right_controls, "Reset Gen 0", self.reset_to_generation_zero, primary=True).pack(fill=tk.X, pady=5)

        tk.Label(right_controls, text="Duration").pack(anchor="w", pady=(14, 2))
        self.delay_var = tk.DoubleVar(value=self.delay_seconds)
        tk.Spinbox(
            right_controls,
            from_=self.MIN_DELAY_SECONDS,
            to=self.MAX_DELAY_SECONDS,
            increment=0.01,
            width=8,
            format="%.2f",
            font=("TkDefaultFont", 10),
            textvariable=self.delay_var,
            command=self.apply_delay,
        ).pack(fill=tk.X, pady=(0, 8))

        tk.Label(right_controls, text="Mode").pack(anchor="w", pady=(6, 2))
        self.theme_var = tk.StringVar(value=self.theme_mode)
        self.theme_menu = self.make_dropdown(right_controls, self.theme_mode, width=8)
        theme_choices = self.theme_menu.dropdown_menu
        for mode in ("Light", "Dark", "Sepia"):
            theme_choices.add_command(label=mode, command=lambda value=mode: self.apply_theme(value))
        self.theme_menu.config(width=8)
        self.theme_menu.pack(fill=tk.X)

        self.canvas = tk.Canvas(
            center,
            width=self.canvas_w,
            height=self.canvas_h,
            bg=self.get_theme_color("grid"),
            highlightthickness=0,
        )
        self.canvas.pack(padx=8, pady=8)
        self.canvas.bind("<ButtonPress-1>", self.on_drag_start)
        self.canvas.bind("<B1-Motion>", self.on_drag_motion)
        self.canvas.bind("<ButtonRelease-1>", self.on_drag_end)
        self.canvas.bind("<Motion>", self.on_canvas_motion)
        self.canvas.bind("<Leave>", self.on_canvas_leave)

        self.graph_canvas = tk.Canvas(
            main_area,
            width=self.get_graph_width(),
            height=self.GRAPH_HEIGHT,
            bg=self.get_theme_color("graph_bg"),
            highlightthickness=0,
        )
        self.graph_canvas.pack(fill=tk.X, pady=(0, 8))

    def get_graph_width(self):
        if not hasattr(self, "work_area"):
            return max(self.canvas_w, 360)

        self.update_idletasks()
        return max(
            self.work_area.winfo_width(),
            self.work_area.winfo_reqwidth(),
            self.canvas_w,
            360,
        )

    def make_button(self, parent, text, command, primary=False, **options):
        button = tk.Button(
            parent,
            text=text,
            command=command,
            font=("TkDefaultFont", 10, "bold") if primary else ("TkDefaultFont", 9),
            padx=6 if primary else 2,
            pady=2 if primary else 0,
            **options,
        )
        self.themed_buttons.append(button)
        self.apply_button_theme(button)
        return button

    def make_dropdown(self, parent, text, width=None):
        button = tk.Menubutton(
            parent,
            text=self.dropdown_label(text),
            relief=tk.RAISED,
            font=("TkDefaultFont", 9),
            padx=2,
            pady=0,
            width=width,
            indicatoron=False,
        )
        menu = tk.Menu(button, tearoff=False)
        button.dropdown_menu = menu
        button.config(menu=menu)
        self.themed_buttons.append(button)
        self.apply_button_theme(button)
        return button

    def dropdown_label(self, text):
        return f"{text} \u25be"

    def set_dropdown_label(self, button, text):
        button.config(text=self.dropdown_label(text))

    def apply_button_theme(self, button):
        button.config(
            bg=self.get_theme_color("button_bg"),
            fg=self.get_theme_color("button_fg"),
            activebackground=self.get_theme_color("button_active"),
            activeforeground=self.get_theme_color("button_fg"),
            disabledforeground="#8a8a8a",
        )

    def apply_all_button_themes(self):
        for button in getattr(self, "themed_buttons", []):
            self.apply_button_theme(button)
        for menu_name in ("theme_menu", "saved_canvas_menu"):
            if hasattr(self, menu_name):
                self.apply_button_theme(getattr(self, menu_name))

    def bind_keys(self):
        self.bind_all("<Up>", lambda e: self.move_cursor(-1, 0, e))
        self.bind_all("<Down>", lambda e: self.move_cursor(1, 0, e))
        self.bind_all("<Left>", lambda e: self.move_cursor(0, -1, e))
        self.bind_all("<Right>", lambda e: self.move_cursor(0, 1, e))
        self.bind_all("<space>", lambda e: self.toggle_cell())
        self.bind_all("<Return>", lambda e: self.toggle_cell())
        self.bind_all("<Control-c>", lambda e: self.copy_selection())
        self.bind_all("<Control-v>", lambda e: self.paste_selection())
        self.safe_bind_all("<Command-c>", lambda e: self.copy_selection())
        self.safe_bind_all("<Command-v>", lambda e: self.paste_selection())
        self.bind_all("<Shift-Up>", lambda e: self.extend_selection(-1, 0))
        self.bind_all("<Shift-Down>", lambda e: self.extend_selection(1, 0))
        self.bind_all("<Shift-Left>", lambda e: self.extend_selection(0, -1))
        self.bind_all("<Shift-Right>", lambda e: self.extend_selection(0, 1))
        self.bind_all("<Escape>", lambda e: self.cancel_pattern_or_clear_selection())
        self.bind_all("<ButtonPress-1>", self.clear_selection_from_outside_click, add="+")

    def safe_bind_all(self, sequence, callback):
        try:
            self.bind_all(sequence, callback)
        except tk.TclError:
            pass

    def get_theme(self):
        if self.theme_mode == "Dark":
            return self.DARK_THEME
        if self.theme_mode == "Sepia":
            return self.SEPIA_THEME
        return self.LIGHT_THEME

    def get_theme_color(self, name):
        return self.get_theme()[name]

    def apply_theme(self, mode=None):
        if mode in ("Light", "Dark", "Sepia"):
            self.theme_mode = mode
        elif hasattr(self, "theme_var"):
            self.theme_mode = self.theme_var.get()
        if hasattr(self, "theme_var"):
            self.theme_var.set(self.theme_mode)
        if hasattr(self, "theme_menu"):
            self.set_dropdown_label(self.theme_menu, self.theme_mode)

        if hasattr(self, "canvas"):
            self.canvas.config(bg=self.get_theme_color("grid"))
        if hasattr(self, "graph_canvas"):
            self.graph_canvas.config(bg=self.get_theme_color("graph_bg"))
        self.apply_all_button_themes()
        if hasattr(self, "rects"):
            self.update_canvas()

    def draw_grid(self):
        self.canvas.delete("all")
        self.canvas.config(bg=self.get_theme_color("grid"))
        self.rects = []
        for r in range(self.rows):
            row_rects = []
            for c in range(self.cols):
                x0, y0 = c * self.cell_size + 1, r * self.cell_size + 1
                x1, y1 = x0 + self.cell_size - 2, y0 + self.cell_size - 2
                rect = self.canvas.create_rectangle(
                    x0,
                    y0,
                    x1,
                    y1,
                    fill=self.get_theme_color("dead"),
                    outline="",
                )
                row_rects.append(rect)
            self.rects.append(row_rects)
        self.cursor_rect = self.canvas.create_rectangle(
            1,
            1,
            self.cell_size - 1,
            self.cell_size - 1,
            outline=self.get_theme_color("cursor"),
            width=2,
        )

    def update_canvas(self):
        for r in range(self.rows):
            for c in range(self.cols):
                color = self.get_theme_color("alive") if self.grid[r][c] else self.get_theme_color("dead")
                self.canvas.itemconfig(self.rects[r][c], fill=color)
        self.draw_selection_overlay()
        self.update_cursor()
        self.draw_pattern_preview()
        self.update_graph()

    def update_cursor(self):
        x0 = self.cur_c * self.cell_size + 1
        y0 = self.cur_r * self.cell_size + 1
        x1 = x0 + self.cell_size - 2
        y1 = y0 + self.cell_size - 2
        self.canvas.coords(self.cursor_rect, x0, y0, x1, y1)
        self.canvas.itemconfig(self.cursor_rect, outline=self.get_theme_color("cursor"))

    def move_cursor(self, dr, dc, event):
        self.cur_r = max(0, min(self.rows - 1, self.cur_r + dr))
        self.cur_c = max(0, min(self.cols - 1, self.cur_c + dc))
        self.update_cursor()

    def extend_selection(self, dr, dc):
        if not self.selection:
            self.selection = [(self.cur_r, self.cur_c)]
        self.cur_r = max(0, min(self.rows - 1, self.cur_r + dr))
        self.cur_c = max(0, min(self.cols - 1, self.cur_c + dc))
        self.add_cell_to_selection((self.cur_r, self.cur_c))
        self.update_canvas()

    def add_cell_to_selection(self, cell):
        if self.selection is None:
            self.selection = []
        if cell not in self.selection:
            self.selection.append(cell)
        self.update_selection_controls()

    def highlight_selection(self):
        self.draw_selection_overlay()

    def draw_selection_overlay(self):
        for item in self.selection_items:
            self.canvas.delete(item)
        self.selection_items = []

        if not self.selection:
            return

        for (r, c) in self.selection:
            if 0 <= r < self.rows and 0 <= c < self.cols:
                x0 = c * self.cell_size + 2
                y0 = r * self.cell_size + 2
                x1 = x0 + self.cell_size - 4
                y1 = y0 + self.cell_size - 4
                item = self.canvas.create_rectangle(
                    x0,
                    y0,
                    x1,
                    y1,
                    outline=self.get_theme_color("selection"),
                    width=2,
                )
                self.selection_items.append(item)

    def clear_selection(self):
        self.selection = None
        self.selection_anchor = None
        self.selection_drag_anchor = None
        self.update_selection_controls()
        self.update_canvas()

    def update_selection_controls(self):
        if hasattr(self, "save_pattern_button"):
            state = tk.NORMAL if self.selection else tk.DISABLED
            self.save_pattern_button.config(state=state)

    def cancel_pattern_or_clear_selection(self):
        if self.pending_pattern:
            self.cancel_pattern_preview()
            return "break"
        self.clear_selection()
        return "break"

    def clear_selection_from_outside_click(self, event):
        if not self.selection or self.pending_pattern:
            return
        if event.widget == self.canvas:
            return
        if event.widget == getattr(self, "save_pattern_button", None):
            return
        try:
            if event.widget.winfo_toplevel() is not self:
                return
        except tk.TclError:
            return
        self.clear_selection()

    def copy_selection(self):
        if not self.selection:
            return "break"
        rmin, rmax, cmin, cmax = self.get_selection_bounds()
        block = [row[cmin:cmax + 1] for row in self.grid[rmin:rmax + 1]]
        self.clipboard = copy.deepcopy(block)
        self.clear_selection()
        self.status_var.set(f"Copied {len(block)} x {len(block[0])} cells.")
        return "break"

    def paste_selection(self):
        if not self.clipboard:
            self.status_var.set("Nothing copied yet.")
            return "break"

        block_rows = len(self.clipboard)
        block_cols = len(self.clipboard[0])
        start_r, start_c = self.get_paste_start_cell(block_rows, block_cols)
        self.record_generation_zero_edit()
        pasted_cells = 0
        for r in range(block_rows):
            for c in range(block_cols):
                rr, cc = start_r + r, start_c + c
                if 0 <= rr < self.rows and 0 <= cc < self.cols:
                    self.grid[rr][cc] = self.clipboard[r][c]
                    pasted_cells += 1
        if pasted_cells:
            self.mark_dirty()
        self.record_current_population()
        self.update_canvas()
        self.status_var.set(f"Pasted {pasted_cells} cells.")
        return "break"

    def get_selection_bounds(self):
        rmin = min(r for r, _ in self.selection)
        rmax = max(r for r, _ in self.selection)
        cmin = min(c for _, c in self.selection)
        cmax = max(c for _, c in self.selection)
        return rmin, rmax, cmin, cmax

    def get_paste_start_cell(self, block_rows, block_cols):
        return self.cur_r, self.cur_c - block_cols + 1

    def toggle_cell(self):
        if self.pending_pattern:
            self.place_pending_pattern()
            return "break"

        self.record_generation_zero_edit()
        self.grid[self.cur_r][self.cur_c] ^= 1
        self.mark_dirty()
        self.record_current_population()
        self.update_canvas()
        return "break"

    def get_cell_from_event(self, event):
        c, r = event.x // self.cell_size, event.y // self.cell_size
        if 0 <= r < self.rows and 0 <= c < self.cols:
            return r, c
        return None

    def is_shift_event(self, event):
        return bool(event.state & 0x0001)

    def toggle_cell_at(self, r, c):
        self.cur_r, self.cur_c = r, c
        self.grid[r][c] ^= 1

    def cells_between(self, start, end):
        r1, c1 = start
        r2, c2 = end
        dr = r2 - r1
        dc = c2 - c1
        steps = max(abs(dr), abs(dc))
        if steps == 0:
            return [start]

        cells = []
        for step in range(steps + 1):
            r = round(r1 + (dr * step / steps))
            c = round(c1 + (dc * step / steps))
            cell = (r, c)
            if not cells or cells[-1] != cell:
                cells.append(cell)
        return cells

    def on_drag_start(self, event):
        if self.pending_pattern:
            cell = self.get_cell_from_event(event)
            if cell:
                self.cur_r, self.cur_c = cell
                self.pattern_preview_anchor = cell
            self.place_pending_pattern()
            return "break"

        cell = self.get_cell_from_event(event)
        if not cell:
            self.clear_selection()
            return

        if self.is_shift_event(event):
            self.selection_drag_anchor = cell
            self.cur_r, self.cur_c = cell
            self.selection = []
            self.add_cell_to_selection(cell)
            self.update_canvas()
            return

        self.drag_toggled_cells = set()
        self.last_drag_cell = cell
        self.record_generation_zero_edit()
        self.toggle_drag_cell(cell)
        self.mark_dirty()
        self.record_current_population()
        self.update_canvas()

    def on_drag_motion(self, event):
        if self.pending_pattern:
            self.on_canvas_motion(event)
            return

        cell = self.get_cell_from_event(event)
        if not cell:
            return

        if self.selection_drag_anchor:
            self.cur_r, self.cur_c = cell
            for drag_cell in self.cells_between(self.selection_drag_anchor, cell):
                self.add_cell_to_selection(drag_cell)
            self.selection_drag_anchor = cell
            self.update_canvas()
            return

        if self.last_drag_cell is None:
            self.last_drag_cell = cell

        changed = False
        for drag_cell in self.cells_between(self.last_drag_cell, cell):
            if self.toggle_drag_cell(drag_cell):
                changed = True

        self.last_drag_cell = cell
        if changed:
            self.mark_dirty()
            self.record_current_population()
            self.update_canvas()

    def on_drag_end(self, event):
        if self.pending_pattern:
            cell = self.get_cell_from_event(event)
            if cell:
                self.cur_r, self.cur_c = cell
                self.pattern_preview_anchor = cell
                self.place_pending_pattern()
            return "break"

        self.drag_toggled_cells = set()
        self.last_drag_cell = None
        self.selection_drag_anchor = None

    def on_canvas_motion(self, event):
        if not self.pending_pattern:
            return

        cell = self.get_cell_from_event(event)
        if not cell:
            self.pattern_preview_anchor = None
            self.clear_pattern_preview()
            return

        self.cur_r, self.cur_c = cell
        self.pattern_preview_anchor = cell
        self.update_cursor()
        self.draw_pattern_preview()

    def on_canvas_leave(self, event):
        if self.pending_pattern:
            self.pattern_preview_anchor = None
            self.clear_pattern_preview()

    def toggle_drag_cell(self, cell):
        if cell in self.drag_toggled_cells:
            return False

        r, c = cell
        self.drag_toggled_cells.add(cell)
        self.toggle_cell_at(r, c)
        return True

    def start(self):
        if self.running:
            return
        if self.count_live_cells() == 0:
            self.status_var.set("Add live cells before starting.")
            self.update_run_button()
            return

        self.running = True
        self.update_run_button()
        self.tick()

    def toggle_running(self):
        if self.running:
            self.stop()
        else:
            self.start()

    def step_once(self):
        self.stop()
        stable = self.advance_generation()
        self.show_generation_state_message(stable)

    def stop(self):
        self.running = False
        if self.after_id:
            self.after_cancel(self.after_id)
            self.after_id = None
        self.update_run_button()

    def update_run_button(self):
        if hasattr(self, "run_button"):
            self.run_button.config(text="Stop" if self.running else "Start")

    def tick(self):
        if not self.running:
            return
        self.after_id = None
        stable = self.advance_generation()
        if self.count_live_cells() == 0:
            self.stop()
            self.status_var.set(f"Stopped at Generation {self.generation}: all cells died.")
            return
        self.show_generation_state_message(stable)
        self.after_id = self.after(self.get_delay_ms(), self.tick)

    def advance_generation(self):
        old_grid = copy.deepcopy(self.grid)
        self.history.append(
            (
                old_grid,
                self.generation,
                self.population_history.copy(),
            )
        )
        new_grid = [[0] * self.cols for _ in range(self.rows)]
        for r in range(self.rows):
            for c in range(self.cols):
                n = sum(
                    self.grid[rr][cc]
                    for rr in range(r - 1, r + 2)
                    for cc in range(c - 1, c + 2)
                    if 0 <= rr < self.rows and 0 <= cc < self.cols and not (rr == r and cc == c)
                )
                if self.grid[r][c]:
                    new_grid[r][c] = 1 if self.survival_min <= n <= self.survival_max else 0
                else:
                    new_grid[r][c] = 1 if n == self.birth_count else 0
        self.grid = new_grid
        self.generation += 1
        self.population_history.append(self.count_live_cells())
        self.mark_dirty()
        self.update_generation_label()
        self.update_canvas()
        return self.grid == old_grid

    def show_generation_state_message(self, stable):
        if stable and self.count_live_cells() > 0:
            self.status_var.set(f"Stable at Generation {self.generation}: live cells are unchanged.")

    def clear(self):
        self.stop()
        was_generation_zero = self.generation == 0
        if was_generation_zero and self.count_live_cells() > 0:
            self.record_generation_zero_edit()
        elif not was_generation_zero:
            self.edit_history = []
        self.grid = [[0] * self.cols for _ in range(self.rows)]
        self.history = []
        self.population_history = [0]
        self.generation = 0
        self.selection = None
        self.selection_anchor = None
        self.selection_drag_anchor = None
        self.update_selection_controls()
        self.generation_zero_grid = copy.deepcopy(self.grid)
        self.mark_dirty()
        self.update_generation_label()
        self.update_canvas()

    def undo_edit(self):
        if self.generation != 0:
            self.status_var.set("Use Back to return to earlier generations.")
            return
        if not self.edit_history:
            self.status_var.set("Nothing to undo in Generation 0.")
            return

        self.grid = self.edit_history.pop()
        self.population_history = [self.count_live_cells()]
        self.generation_zero_grid = copy.deepcopy(self.grid)
        self.mark_dirty()
        self.update_generation_label()
        self.update_canvas()
        self.status_var.set("Undid the last Generation 0 edit.")

    def back_generation(self):
        if self.history:
            self.stop()
            self.grid, self.generation, self.population_history = self.history.pop()
            if self.generation == 0:
                self.generation_zero_grid = copy.deepcopy(self.grid)
            self.mark_dirty()
            self.update_generation_label()
            self.update_canvas()
            self.status_var.set(f"Back to Generation {self.generation}.")
        else:
            self.status_var.set("No previous generation to go back to.")

    def reset_to_generation_zero(self):
        self.stop()
        self.grid = copy.deepcopy(self.generation_zero_grid)
        self.history = []
        self.generation = 0
        self.population_history = [self.count_live_cells()]
        self.selection = None
        self.selection_anchor = None
        self.selection_drag_anchor = None
        self.update_selection_controls()
        self.mark_dirty()
        self.update_generation_label()
        self.update_canvas()
        self.status_var.set("Reset to Generation 0.")

    def randomize_canvas(self):
        self.stop()
        if self.generation == 0:
            self.record_generation_zero_edit()
        else:
            self.edit_history = []

        density = self.clamp_dimension(self.random_density_var.get(), 1, 100)
        self.random_density_var.set(density)
        self.grid = [
            [1 if random.randint(1, 100) <= density else 0 for _ in range(self.cols)]
            for _ in range(self.rows)
        ]
        self.history = []
        self.generation = 0
        self.population_history = [self.count_live_cells()]
        self.selection = None
        self.selection_anchor = None
        self.selection_drag_anchor = None
        self.update_selection_controls()
        self.generation_zero_grid = copy.deepcopy(self.grid)
        self.mark_dirty()
        self.update_generation_label()
        self.update_canvas()
        self.status_var.set(f"Generated Generation 0 at {density}% density.")

    def apply_dimensions(self):
        rows = self.clamp_dimension(self.rows_var.get(), self.MIN_ROWS, self.MAX_ROWS)
        cols = self.clamp_dimension(self.cols_var.get(), self.MIN_COLS, self.MAX_COLS)

        self.rows_var.set(rows)
        self.cols_var.set(cols)
        if rows == self.rows and cols == self.cols:
            self.status_var.set("")
            return

        self.stop()
        old_grid = self.grid
        old_rows, old_cols = self.rows, self.cols
        self.rows, self.cols = rows, cols
        self.cell_size = self.get_cell_size_for_board(self.rows, self.cols)
        self.canvas_w = self.cols * self.cell_size
        self.canvas_h = self.rows * self.cell_size
        self.grid = [[0 for _ in range(self.cols)] for _ in range(self.rows)]

        for r in range(min(old_rows, self.rows)):
            for c in range(min(old_cols, self.cols)):
                self.grid[r][c] = old_grid[r][c]

        self.cur_r = max(0, min(self.rows - 1, self.cur_r))
        self.cur_c = max(0, min(self.cols - 1, self.cur_c))
        self.history = []
        self.edit_history = []
        self.generation = 0
        self.population_history = [self.count_live_cells()]
        self.generation_zero_grid = copy.deepcopy(self.grid)
        self.selection = None
        self.selection_anchor = None
        self.selection_drag_anchor = None
        self.update_selection_controls()
        self.mark_dirty()
        self.update_generation_label()
        self.canvas.config(width=self.canvas_w, height=self.canvas_h)
        self.graph_canvas.config(width=self.get_graph_width(), height=self.GRAPH_HEIGHT)
        self.draw_grid()
        self.update_canvas()
        self.status_var.set(
            f"Board resized to {self.rows} rows x {self.cols} columns. Cell size: {self.cell_size}px."
        )

    def save_named_canvas(self):
        name = simpledialog.askstring("Save Canvas", "Enter a name for this canvas:", parent=self)
        if not name:
            return

        name = name.strip()
        if not name:
            return

        path = self.get_local_canvas_path(name)
        if os.path.exists(path):
            replace = messagebox.askyesno(
                "Replace Canvas",
                f"A saved canvas named '{name}' already exists. Replace it?",
                parent=self,
            )
            if not replace:
                return

        self.write_canvas_file(path, name)
        self.mark_clean()
        self.refresh_saved_canvas_menu(name)
        self.status_var.set(f"Saved canvas '{name}'.")
        return True

    def load_selected_canvas(self):
        name = self.saved_canvas_var.get()
        if not name or name == "No saved canvases":
            self.status_var.set("No saved canvas selected.")
            return
        if not self.confirm_replace_current_canvas("opening a saved canvas"):
            return

        path = self.get_local_canvas_path(name)
        if not os.path.exists(path):
            self.status_var.set(f"Could not find saved canvas '{name}'.")
            self.refresh_saved_canvas_menu()
            return

        data = self.read_canvas_file_or_show_error(path)
        if not data:
            return
        self.apply_canvas_data(data, source_name=name)

    def delete_selected_canvas(self):
        name = self.saved_canvas_var.get()
        if not name or name == "No saved canvases":
            self.status_var.set("No saved canvas selected to remove.")
            return

        path = self.get_local_canvas_path(name)
        if not os.path.exists(path):
            self.status_var.set(f"Could not find saved canvas '{name}'.")
            self.refresh_saved_canvas_menu()
            return

        remove = messagebox.askyesno(
            "Remove Canvas",
            f"Remove saved canvas '{name}'?",
            parent=self,
        )
        if not remove:
            return

        try:
            os.remove(path)
        except OSError as error:
            messagebox.showerror("Remove Failed", str(error), parent=self)
            return

        self.refresh_saved_canvas_menu()
        self.status_var.set(f"Removed saved canvas '{name}'.")

    def export_canvas(self):
        name = simpledialog.askstring("Export Canvas", "Enter a name for this export:", parent=self)
        if not name:
            return

        name = name.strip()
        if not name:
            return

        path = filedialog.asksaveasfilename(
            parent=self,
            title="Export Canvas",
            defaultextension=self.SAVE_FILE_EXTENSION,
            initialfile=f"{self.sanitize_canvas_name(name)}{self.SAVE_FILE_EXTENSION}",
            filetypes=[
                ("Game of Life Canvas", f"*{self.SAVE_FILE_EXTENSION}"),
                ("JSON files", "*.json"),
                ("All files", "*.*"),
            ],
        )
        if not path:
            return

        self.write_canvas_file(path, name)
        self.mark_clean()
        self.status_var.set(f"Exported canvas '{name}'.")

    def import_canvas(self):
        if not self.confirm_replace_current_canvas("importing a canvas"):
            return

        path = filedialog.askopenfilename(
            parent=self,
            title="Import Canvas",
            filetypes=[
                ("Game of Life Canvas", f"*{self.SAVE_FILE_EXTENSION}"),
                ("JSON files", "*.json"),
                ("All files", "*.*"),
            ],
        )
        if not path:
            return

        data = self.read_canvas_file_or_show_error(path)
        if not data:
            return
        self.apply_canvas_data(data, source_name=data.get("name") or os.path.basename(path))
        self.mark_clean()

    def save_pattern_to_library(self):
        if not self.selection:
            self.status_var.set("Select a block before saving it to the Pattern Library.")
            return

        name = simpledialog.askstring("Save Pattern", "Enter a name for this pattern:", parent=self)
        if not name:
            return

        name = name.strip()
        if not name:
            return

        rmin, rmax, cmin, cmax = self.get_selection_bounds()
        block = [row[cmin:cmax + 1] for row in self.grid[rmin:rmax + 1]]
        path = self.get_local_pattern_path(name)
        if os.path.exists(path):
            replace = messagebox.askyesno(
                "Replace Pattern",
                f"A saved pattern named '{name}' already exists. Replace it?",
                parent=self,
            )
            if not replace:
                return

        self.write_pattern_file(path, name, block)
        self.refresh_saved_pattern_menu(name)
        self.status_var.set(f"Saved pattern '{name}' to the Pattern Library.")

    def start_pattern_placement(self, name, grid):
        self.pending_pattern = copy.deepcopy(grid)
        self.pending_pattern_name = name
        self.pattern_preview_anchor = (self.cur_r, self.cur_c)
        self.status_var.set(f"Move over the canvas, then click to place '{self.pending_pattern_name}'. Esc cancels.")
        self.draw_pattern_preview()

    def show_pattern_library(self):
        self.refresh_saved_pattern_menu()
        entries = []
        for name, grid in self.DEFAULT_PATTERNS:
            entries.append(("Built-in", name, copy.deepcopy(grid)))

        for name in self.saved_pattern_names:
            path = self.get_local_pattern_path(name)
            try:
                data = self.read_pattern_file(path)
            except (OSError, ValueError, json.JSONDecodeError):
                continue
            entries.append(("Saved", data.get("name") or name, data["grid"]))

        dialog = tk.Toplevel(self)
        dialog.title("Pattern Library")
        dialog.transient(self)
        dialog.grab_set()
        dialog.resizable(False, False)

        tk.Label(dialog, text="Choose a pattern to place on the canvas.").pack(anchor="w", padx=14, pady=(12, 6))

        listbox = tk.Listbox(dialog, width=34, height=min(14, max(6, len(entries))))
        listbox.pack(fill=tk.BOTH, expand=True, padx=14, pady=(0, 10))
        for source, name, grid in entries:
            rows = len(grid)
            cols = len(grid[0]) if grid else 0
            listbox.insert(tk.END, f"{source}: {name} ({rows} x {cols})")
        if entries:
            listbox.selection_set(0)
            listbox.activate(0)

        buttons = tk.Frame(dialog)
        buttons.pack(anchor="e", padx=14, pady=(0, 14))

        def choose_pattern():
            selection = listbox.curselection()
            if not selection:
                self.status_var.set("No pattern selected.")
                return
            _, name, grid = entries[selection[0]]
            self.start_pattern_placement(name, grid)
            dialog.destroy()

        def remove_pattern():
            selection = listbox.curselection()
            if not selection:
                self.status_var.set("No pattern selected to remove.")
                return

            source, name, _ = entries[selection[0]]
            if source != "Saved":
                self.status_var.set("Built-in patterns stay in the library.")
                return

            path = self.get_local_pattern_path(name)
            if not os.path.exists(path):
                self.status_var.set(f"Could not find saved pattern '{name}'.")
                dialog.destroy()
                return

            remove = messagebox.askyesno(
                "Remove Pattern",
                f"Remove saved pattern '{name}'?",
                parent=dialog,
            )
            if not remove:
                return

            try:
                os.remove(path)
            except OSError as error:
                messagebox.showerror("Remove Failed", str(error), parent=dialog)
                return

            self.refresh_saved_pattern_menu()
            self.status_var.set(f"Removed saved pattern '{name}'.")
            dialog.destroy()
            self.show_pattern_library()

        listbox.bind("<Double-Button-1>", lambda event: choose_pattern())
        tk.Button(buttons, text="Place", width=10, command=choose_pattern).pack(side=tk.LEFT, padx=4)
        tk.Button(buttons, text="X", width=4, command=remove_pattern).pack(side=tk.LEFT, padx=4)
        tk.Button(buttons, text="Close", width=10, command=dialog.destroy).pack(side=tk.LEFT, padx=4)

        dialog.protocol("WM_DELETE_WINDOW", dialog.destroy)
        dialog.update_idletasks()
        x = self.winfo_rootx() + (self.winfo_width() - dialog.winfo_width()) // 2
        y = self.winfo_rooty() + (self.winfo_height() - dialog.winfo_height()) // 2
        dialog.geometry(f"+{max(0, x)}+{max(0, y)}")
        listbox.focus_set()

    def get_save_directory(self):
        save_dir = os.path.join(os.path.expanduser("~"), "Conway Game of Life Canvases")
        os.makedirs(save_dir, exist_ok=True)
        return save_dir

    def get_preferences_path(self):
        return os.path.join(self.get_save_directory(), self.PREFERENCES_FILE_NAME)

    def read_preferences(self):
        path = self.get_preferences_path()
        if not os.path.exists(path):
            return {}
        try:
            with open(path, "r", encoding="utf-8") as file:
                data = json.load(file)
        except (OSError, json.JSONDecodeError):
            return {}
        return data if isinstance(data, dict) else {}

    def write_preferences(self, preferences):
        try:
            with open(self.get_preferences_path(), "w", encoding="utf-8") as file:
                json.dump(preferences, file, indent=2)
        except OSError:
            pass

    def has_seen_tour(self):
        return bool(self.read_preferences().get("tour_seen"))

    def mark_tour_seen(self):
        preferences = self.read_preferences()
        preferences["tour_seen"] = True
        self.write_preferences(preferences)

    def get_local_canvas_path(self, name):
        return os.path.join(self.get_save_directory(), f"{self.sanitize_canvas_name(name)}{self.SAVE_FILE_EXTENSION}")

    def get_local_pattern_path(self, name):
        return os.path.join(self.get_save_directory(), f"{self.sanitize_canvas_name(name)}{self.PATTERN_FILE_EXTENSION}")

    def sanitize_canvas_name(self, name):
        safe = "".join(ch if ch.isalnum() or ch in (" ", "-", "_") else "_" for ch in name)
        safe = "_".join(safe.strip().split())
        return safe or "canvas"

    def refresh_saved_canvas_menu(self, selected_name=None):
        self.saved_canvas_names = self.get_saved_canvas_names()
        menu = self.saved_canvas_menu.dropdown_menu
        menu.delete(0, "end")

        if not self.saved_canvas_names:
            self.saved_canvas_var.set("No saved canvases")
            self.set_dropdown_label(self.saved_canvas_menu, "No saved canvases")
            menu.add_command(
                label="No saved canvases",
                command=lambda: self.select_saved_canvas("No saved canvases"),
            )
            return

        if selected_name not in self.saved_canvas_names:
            selected_name = self.saved_canvas_names[0]
        self.select_saved_canvas(selected_name)

        for name in self.saved_canvas_names:
            menu.add_command(label=name, command=lambda value=name: self.select_saved_canvas(value))

    def select_saved_canvas(self, name):
        self.saved_canvas_var.set(name)
        if hasattr(self, "saved_canvas_menu"):
            self.set_dropdown_label(self.saved_canvas_menu, name)

    def refresh_saved_pattern_menu(self, selected_name=None):
        self.saved_pattern_names = self.get_saved_pattern_names()

    def get_saved_canvas_names(self):
        names = []
        save_dir = self.get_save_directory()
        for filename in os.listdir(save_dir):
            if not filename.endswith(self.SAVE_FILE_EXTENSION):
                continue
            path = os.path.join(save_dir, filename)
            try:
                data = self.read_canvas_file(path)
            except (OSError, ValueError, json.JSONDecodeError):
                continue
            names.append(data.get("name") or filename[:-len(self.SAVE_FILE_EXTENSION)])
        return sorted(names, key=str.casefold)

    def get_saved_pattern_names(self):
        names = []
        save_dir = self.get_save_directory()
        for filename in os.listdir(save_dir):
            if not filename.endswith(self.PATTERN_FILE_EXTENSION):
                continue
            path = os.path.join(save_dir, filename)
            try:
                data = self.read_pattern_file(path)
            except (OSError, ValueError, json.JSONDecodeError):
                continue
            names.append(data.get("name") or filename[:-len(self.PATTERN_FILE_EXTENSION)])
        return sorted(names, key=str.casefold)

    def build_canvas_data(self, name):
        return {
            "app": "Conway's Game of Life Tool",
            "version": self.SAVE_FILE_VERSION,
            "name": name,
            "rows": self.rows,
            "cols": self.cols,
            "generation": self.generation,
            "population_history": self.population_history,
            "generation_zero_grid": self.generation_zero_grid,
            "grid": self.grid,
            "rules": {
                "survival_min": self.survival_min,
                "survival_max": self.survival_max,
                "birth_count": self.birth_count,
            },
        }

    def write_canvas_file(self, path, name):
        data = self.build_canvas_data(name)
        with open(path, "w", encoding="utf-8") as file:
            json.dump(data, file, indent=2)

    def build_pattern_data(self, name, block):
        return {
            "app": "Conway's Game of Life Tool",
            "type": "pattern",
            "version": self.SAVE_FILE_VERSION,
            "name": name,
            "rows": len(block),
            "cols": len(block[0]),
            "grid": block,
        }

    def write_pattern_file(self, path, name, block):
        data = self.build_pattern_data(name, block)
        with open(path, "w", encoding="utf-8") as file:
            json.dump(data, file, indent=2)

    def read_canvas_file(self, path):
        with open(path, "r", encoding="utf-8") as file:
            data = json.load(file)
        self.validate_canvas_data(data)
        return data

    def read_pattern_file(self, path):
        with open(path, "r", encoding="utf-8") as file:
            data = json.load(file)
        self.validate_pattern_data(data)
        return data

    def read_canvas_file_or_show_error(self, path):
        try:
            return self.read_canvas_file(path)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            messagebox.showerror("Open Failed", str(error), parent=self)
            return None

    def read_pattern_file_or_show_error(self, path):
        try:
            return self.read_pattern_file(path)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            messagebox.showerror("Open Pattern Failed", str(error), parent=self)
            return None

    def validate_pattern_data(self, data):
        if not isinstance(data, dict):
            raise ValueError("Pattern file is not a JSON object.")

        rows = data.get("rows")
        cols = data.get("cols")
        grid = data.get("grid")
        if not isinstance(rows, int) or not isinstance(cols, int):
            raise ValueError("Pattern file is missing row or column counts.")
        if rows < 1 or cols < 1:
            raise ValueError("Pattern must be at least 1 x 1.")
        if not isinstance(grid, list) or len(grid) != rows:
            raise ValueError("Pattern grid does not match the saved row count.")

        for row in grid:
            if not isinstance(row, list) or len(row) != cols:
                raise ValueError("Pattern grid does not match the saved column count.")
            if any(cell not in (0, 1) for cell in row):
                raise ValueError("Pattern grid cells must be 0 or 1.")

    def validate_rule_values(self, survival_min, survival_max, birth_count):
        for label, value in (
            ("Survival minimum", survival_min),
            ("Survival maximum", survival_max),
            ("Birth count", birth_count),
        ):
            if not isinstance(value, int):
                raise ValueError(f"{label} must be a whole number.")
            if not 0 <= value <= 8:
                raise ValueError(f"{label} must be between 0 and 8.")
        if survival_min > survival_max:
            raise ValueError("Survival minimum cannot be greater than survival maximum.")

    def validate_canvas_data(self, data):
        if not isinstance(data, dict):
            raise ValueError("Canvas file is not a JSON object.")

        rows = data.get("rows")
        cols = data.get("cols")
        grid = data.get("grid")
        generation_zero_grid = data.get("generation_zero_grid")
        if not isinstance(rows, int) or not isinstance(cols, int):
            raise ValueError("Canvas file is missing row or column counts.")
        if not (self.MIN_ROWS <= rows <= self.MAX_ROWS and self.MIN_COLS <= cols <= self.MAX_COLS):
            raise ValueError("Canvas size is outside the supported range.")
        if not isinstance(grid, list) or len(grid) != rows:
            raise ValueError("Canvas grid does not match the saved row count.")

        for row in grid:
            if not isinstance(row, list) or len(row) != cols:
                raise ValueError("Canvas grid does not match the saved column count.")
            if any(cell not in (0, 1) for cell in row):
                raise ValueError("Canvas grid cells must be 0 or 1.")

        if generation_zero_grid is not None:
            if not isinstance(generation_zero_grid, list) or len(generation_zero_grid) != rows:
                raise ValueError("Generation 0 grid does not match the saved row count.")
            for row in generation_zero_grid:
                if not isinstance(row, list) or len(row) != cols:
                    raise ValueError("Generation 0 grid does not match the saved column count.")
                if any(cell not in (0, 1) for cell in row):
                    raise ValueError("Generation 0 grid cells must be 0 or 1.")

        rules = data.get("rules")
        if rules is not None:
            if not isinstance(rules, dict):
                raise ValueError("Saved rules must be a JSON object.")
            try:
                survival_min = int(rules.get("survival_min", self.DEFAULT_SURVIVAL_MIN))
                survival_max = int(rules.get("survival_max", self.DEFAULT_SURVIVAL_MAX))
                birth_count = int(rules.get("birth_count", self.DEFAULT_BIRTH_COUNT))
            except (TypeError, ValueError):
                raise ValueError("Saved rule values must be whole numbers.")
            self.validate_rule_values(survival_min, survival_max, birth_count)

    def apply_canvas_data(self, data, source_name="canvas"):
        try:
            self.validate_canvas_data(data)
        except ValueError as error:
            messagebox.showerror("Import Failed", str(error), parent=self)
            return

        self.stop()
        self.rows = data["rows"]
        self.cols = data["cols"]
        self.rows_var.set(self.rows)
        self.cols_var.set(self.cols)
        self.cell_size = self.get_cell_size_for_board(self.rows, self.cols)
        self.canvas_w = self.cols * self.cell_size
        self.canvas_h = self.rows * self.cell_size
        self.grid = copy.deepcopy(data["grid"])
        try:
            self.generation = max(0, int(data.get("generation", 0)))
        except (TypeError, ValueError):
            self.generation = 0
        rules = data.get("rules") or {}
        self.survival_min = int(rules.get("survival_min", self.DEFAULT_SURVIVAL_MIN))
        self.survival_max = int(rules.get("survival_max", self.DEFAULT_SURVIVAL_MAX))
        self.birth_count = int(rules.get("birth_count", self.DEFAULT_BIRTH_COUNT))
        self.history = []
        self.edit_history = []
        self.selection = None
        self.selection_anchor = None
        self.selection_drag_anchor = None
        self.update_selection_controls()
        self.drag_toggled_cells = set()
        self.last_drag_cell = None
        self.pending_pattern = None
        self.pending_pattern_name = None
        self.pattern_preview_anchor = None
        self.clear_pattern_preview()

        population_history = data.get("population_history")
        if isinstance(population_history, list) and population_history:
            try:
                self.population_history = [max(0, int(value)) for value in population_history]
            except (TypeError, ValueError):
                self.population_history = [self.count_live_cells()]
        else:
            self.population_history = [self.count_live_cells()]
        self.record_current_population()
        if data.get("generation_zero_grid") is not None:
            self.generation_zero_grid = copy.deepcopy(data["generation_zero_grid"])
        else:
            self.generation_zero_grid = copy.deepcopy(self.grid)

        self.cur_r = max(0, min(self.rows - 1, self.cur_r))
        self.cur_c = max(0, min(self.cols - 1, self.cur_c))
        self.update_generation_label()
        self.canvas.config(width=self.canvas_w, height=self.canvas_h)
        self.graph_canvas.config(width=self.get_graph_width(), height=self.GRAPH_HEIGHT)
        self.draw_grid()
        self.update_canvas()
        self.mark_clean()
        self.status_var.set(f"Opened '{source_name}'.")

    def confirm_replace_current_canvas(self, action_name):
        if not self.dirty:
            return True

        choice = self.ask_save_continue_cancel(
            "Unsaved Canvas",
            f"You have unsaved changes before {action_name}.",
        )
        if choice == "cancel":
            return False
        if choice == "save":
            return bool(self.save_named_canvas())
        return True

    def ask_save_continue_cancel(self, title, message):
        dialog = tk.Toplevel(self)
        dialog.title(title)
        dialog.transient(self)
        dialog.grab_set()
        dialog.resizable(False, False)

        result = {"choice": "cancel"}
        tk.Label(dialog, text=message, justify=tk.LEFT).pack(anchor="w", padx=18, pady=(16, 4))
        tk.Label(
            dialog,
            text="Save the current canvas before continuing?",
            justify=tk.LEFT,
        ).pack(anchor="w", padx=18, pady=(0, 12))

        buttons = tk.Frame(dialog)
        buttons.pack(padx=14, pady=(0, 14), anchor="e")

        def choose(value):
            result["choice"] = value
            dialog.destroy()

        tk.Button(buttons, text="Save", width=14, command=lambda: choose("save")).pack(side=tk.LEFT, padx=4)
        tk.Button(buttons, text="Continue Without Saving", width=22, command=lambda: choose("continue")).pack(
            side=tk.LEFT,
            padx=4,
        )
        tk.Button(buttons, text="Cancel", width=10, command=lambda: choose("cancel")).pack(side=tk.LEFT, padx=4)

        dialog.protocol("WM_DELETE_WINDOW", lambda: choose("cancel"))
        dialog.update_idletasks()
        x = self.winfo_rootx() + (self.winfo_width() - dialog.winfo_width()) // 2
        y = self.winfo_rooty() + (self.winfo_height() - dialog.winfo_height()) // 2
        dialog.geometry(f"+{max(0, x)}+{max(0, y)}")
        self.wait_window(dialog)
        return result["choice"]

    def on_close(self):
        if self.confirm_replace_current_canvas("closing the app"):
            self.stop()
            self.destroy()

    def mark_dirty(self):
        self.dirty = True

    def mark_clean(self):
        self.dirty = False

    def set_rule_values(self, survival_min, survival_max, birth_count):
        self.validate_rule_values(survival_min, survival_max, birth_count)
        changed = (
            self.survival_min != survival_min
            or self.survival_max != survival_max
            or self.birth_count != birth_count
        )
        self.survival_min = survival_min
        self.survival_max = survival_max
        self.birth_count = birth_count
        if changed:
            self.mark_dirty()
        return changed

    def show_rules(self):
        dialog = tk.Toplevel(self)
        dialog.title("Rules")
        dialog.transient(self)
        dialog.grab_set()
        dialog.resizable(False, False)

        survival_min_var = tk.IntVar(value=self.survival_min)
        survival_max_var = tk.IntVar(value=self.survival_max)
        birth_count_var = tk.IntVar(value=self.birth_count)
        life_text_var = tk.StringVar()

        intro = (
            "Classic Conway uses survival from 2 to 3 neighbors and birth at exactly 3. "
            "Change these numbers to experiment with nearby rule sets."
        )
        tk.Label(dialog, text=intro, wraplength=420, justify=tk.LEFT).pack(
            anchor="w",
            padx=14,
            pady=(12, 6),
        )

        def read_rule_inputs():
            try:
                return (
                    int(survival_min_var.get()),
                    int(survival_max_var.get()),
                    int(birth_count_var.get()),
                )
            except (tk.TclError, ValueError):
                raise ValueError("Rule values must be whole numbers from 0 to 8.")

        def sync_life_text(*args):
            try:
                survival_min, survival_max, birth_count = read_rule_inputs()
                self.validate_rule_values(survival_min, survival_max, birth_count)
                life_text_var.set(
                    f"Living cells stay alive with {survival_min} through {survival_max} living neighbors. "
                    f"Dead cells are born with exactly {birth_count}."
                )
            except ValueError:
                life_text_var.set("Enter whole numbers from 0 to 8. Survival minimum must not exceed maximum.")

        def editable_rule_row(title, before_text, variable, after_text):
            frame = tk.LabelFrame(dialog, text=title, padx=10, pady=8)
            frame.pack(fill=tk.X, padx=14, pady=4)
            tk.Label(frame, text=before_text).pack(side=tk.LEFT)
            tk.Spinbox(
                frame,
                from_=0,
                to=8,
                width=3,
                textvariable=variable,
                command=sync_life_text,
            ).pack(side=tk.LEFT, padx=6)
            tk.Label(frame, text=after_text).pack(side=tk.LEFT)

        editable_rule_row("Underpopulation", "A living cell dies with fewer than", survival_min_var, "living neighbors.")

        life_frame = tk.LabelFrame(dialog, text="Life", padx=10, pady=8)
        life_frame.pack(fill=tk.X, padx=14, pady=4)
        tk.Label(life_frame, textvariable=life_text_var, wraplength=390, justify=tk.LEFT).pack(anchor="w")

        editable_rule_row("Overpopulation", "A living cell dies with more than", survival_max_var, "living neighbors.")
        editable_rule_row("Birth", "A dead cell becomes alive with exactly", birth_count_var, "living neighbors.")

        for variable in (survival_min_var, survival_max_var, birth_count_var):
            variable.trace_add("write", sync_life_text)

        buttons = tk.Frame(dialog)
        buttons.pack(anchor="e", padx=14, pady=(8, 14))

        def apply_rules():
            try:
                survival_min, survival_max, birth_count = read_rule_inputs()
                changed = self.set_rule_values(survival_min, survival_max, birth_count)
            except ValueError as error:
                messagebox.showerror("Invalid Rules", str(error), parent=dialog)
                return

            sync_life_text()
            if changed:
                self.status_var.set(
                    f"Rules updated: survival {self.survival_min}-{self.survival_max}, birth {self.birth_count}."
                )
            else:
                self.status_var.set("Rules unchanged.")

        def revert_rules():
            survival_min_var.set(self.DEFAULT_SURVIVAL_MIN)
            survival_max_var.set(self.DEFAULT_SURVIVAL_MAX)
            birth_count_var.set(self.DEFAULT_BIRTH_COUNT)
            self.set_rule_values(
                self.DEFAULT_SURVIVAL_MIN,
                self.DEFAULT_SURVIVAL_MAX,
                self.DEFAULT_BIRTH_COUNT,
            )
            sync_life_text()
            self.status_var.set("Rules reverted to classic Conway.")

        tk.Button(buttons, text="Apply", width=10, command=apply_rules).pack(side=tk.LEFT, padx=4)
        tk.Button(buttons, text="Revert", width=10, command=revert_rules).pack(side=tk.LEFT, padx=4)
        tk.Button(buttons, text="Close", width=10, command=dialog.destroy).pack(side=tk.LEFT, padx=4)

        sync_life_text()
        dialog.protocol("WM_DELETE_WINDOW", dialog.destroy)
        dialog.update_idletasks()
        x = self.winfo_rootx() + (self.winfo_width() - dialog.winfo_width()) // 2
        y = self.winfo_rooty() + (self.winfo_height() - dialog.winfo_height()) // 2
        dialog.geometry(f"+{max(0, x)}+{max(0, y)}")
        dialog.focus_set()

    def show_help(self):
        messagebox.showinfo(
            "Shortcuts",
            "Grid editing\n"
            "- Click or hold and drag: toggle cells\n"
            "- Touchscreen or stylus drawing: draw directly on the grid\n"
            "- Arrow keys: move cursor\n"
            "- Space: toggle cursor cell\n\n"
            "Selection and clipboard\n"
            "- Shift + Arrow: add cells to the selection one step at a time\n"
            "- Shift + drag: select the cells you drag across\n"
            "- Ctrl/Cmd + C: copy selected block and unselect it\n"
            "- Ctrl/Cmd + V: paste copied block using cursor as top-right corner\n"
            "- Click outside the grid: clear the current selection\n"
            "- Escape: clear selection or cancel pattern placement\n\n"
            "Simulation\n"
            "- Step: advance one generation\n"
            "- Back: go to the previous generation\n"
            "- Reset Gen 0: return to the starting canvas\n\n"
            "Rules\n"
            "- Rules: view or change survival and birth numbers\n"
            "- Tour / Demo: replay the guided tour and demo\n\n"
            "Files and patterns\n"
            "- Save Canvas / Load Canvas: local named canvases\n"
            "- Export / Import: portable full canvas files\n"
            "- Save to Pattern Library: save selected cells locally\n"
            "- Pattern Library: choose a built-in or saved pattern and place it with preview",
            parent=self,
        )

    def show_first_run_tour_if_needed(self):
        if not self.has_seen_tour():
            self.show_tour(mark_seen=True)

    def show_tour(self, mark_seen=False):
        if mark_seen:
            self.mark_tour_seen()

        steps = [
            (
                "Welcome",
                "This is Conway's Game of Life Lab.\n\n"
                "Cells are either alive or dead. Press Start/Stop and simple local rules create surprising patterns.",
            ),
            (
                "Draw",
                "Click, hold and drag, or use a touchscreen/stylus to toggle cells on the grid.\n\n"
                "Use Generate to make a random starting world, and adjust Random % to control how full it is.",
            ),
            (
                "Run",
                "Start/Stop runs or pauses the simulation. Step advances exactly one generation.\n\n"
                "Undo is for edits in Generation 0. Back returns to previous generations.",
            ),
            (
                "Select And Paste",
                "Hold Shift and drag to add cells to the selection along your path. Shift + Arrow adds cells one step at a time from the cursor.\n\n"
                "Ctrl/Cmd+C copies the smallest rectangle around those cells and unselects. Ctrl/Cmd+V pastes with the cursor as the top-right corner.",
            ),
            (
                "Patterns",
                "Save selected cells to your Pattern Library, or open the Pattern Library to place built-in and saved shapes.\n\n"
                "When you choose a pattern, move over the grid to preview it, then click to place it.",
            ),
            (
                "Rules And Looks",
                "Rules lets you experiment beyond classic Conway.\n\n"
                "Mode switches between Light, Dark, and Sepia. Save Canvas keeps your current canvas locally, and Export creates a portable file.",
            ),
            (
                "Demo",
                "Try this mini demo: click Load Demo Pattern to preview the Cross pattern on the board.\n\n"
                "Move it around, click to place it, then press Start/Stop or Step.",
            ),
        ]

        dialog = tk.Toplevel(self)
        dialog.title("Tour / Demo")
        dialog.transient(self)
        dialog.grab_set()
        dialog.resizable(False, False)

        step_index = tk.IntVar(value=0)
        title_var = tk.StringVar()
        body_var = tk.StringVar()
        counter_var = tk.StringVar()

        outer = tk.Frame(dialog, padx=18, pady=14)
        outer.pack(fill=tk.BOTH, expand=True)

        tk.Label(outer, textvariable=title_var, font=("TkDefaultFont", 13, "bold")).pack(anchor="w")
        tk.Label(outer, textvariable=body_var, wraplength=440, justify=tk.LEFT).pack(anchor="w", pady=(8, 12))
        tk.Label(outer, textvariable=counter_var, fg="#666").pack(anchor="w")

        buttons = tk.Frame(outer)
        buttons.pack(anchor="e", pady=(14, 0))

        back_button = tk.Button(buttons, text="Back", width=10)
        next_button = tk.Button(buttons, text="Next", width=10)
        demo_button = tk.Button(buttons, text="Load Demo Pattern", width=18)

        def refresh_step():
            index = step_index.get()
            title, body = steps[index]
            title_var.set(title)
            body_var.set(body)
            counter_var.set(f"{index + 1} of {len(steps)}")
            back_button.config(state=tk.NORMAL if index > 0 else tk.DISABLED)
            next_button.config(text="Done" if index == len(steps) - 1 else "Next")
            demo_button.config(state=tk.NORMAL if title == "Demo" else tk.DISABLED)

        def go_back():
            if step_index.get() > 0:
                step_index.set(step_index.get() - 1)
                refresh_step()

        def go_next():
            if step_index.get() >= len(steps) - 1:
                dialog.destroy()
                return
            step_index.set(step_index.get() + 1)
            refresh_step()

        def load_demo_pattern():
            demo_grid = [[0, 1, 0], [1, 1, 1], [0, 1, 0]]
            for name, grid in self.DEFAULT_PATTERNS:
                if name == "Cross":
                    demo_grid = copy.deepcopy(grid)
                    break
            self.start_pattern_placement("Demo Cross", demo_grid)
            dialog.destroy()

        back_button.config(command=go_back)
        next_button.config(command=go_next)
        demo_button.config(command=load_demo_pattern)
        back_button.pack(side=tk.LEFT, padx=4)
        demo_button.pack(side=tk.LEFT, padx=4)
        next_button.pack(side=tk.LEFT, padx=4)
        tk.Button(buttons, text="Close", width=10, command=dialog.destroy).pack(side=tk.LEFT, padx=4)

        refresh_step()
        dialog.protocol("WM_DELETE_WINDOW", dialog.destroy)
        dialog.update_idletasks()
        x = self.winfo_rootx() + (self.winfo_width() - dialog.winfo_width()) // 2
        y = self.winfo_rooty() + (self.winfo_height() - dialog.winfo_height()) // 2
        dialog.geometry(f"+{max(0, x)}+{max(0, y)}")
        dialog.focus_set()

    def place_pending_pattern(self):
        if not self.pending_pattern or self.pattern_preview_anchor is None:
            return

        anchor_r, anchor_c = self.pattern_preview_anchor
        self.record_generation_zero_edit()
        placed_cells = 0
        for r, row in enumerate(self.pending_pattern):
            for c, cell in enumerate(row):
                rr, cc = anchor_r + r, anchor_c + c
                if cell and 0 <= rr < self.rows and 0 <= cc < self.cols:
                    self.grid[rr][cc] = 1
                    placed_cells += 1

        pattern_name = self.pending_pattern_name or "pattern"
        self.cancel_pattern_preview()
        if placed_cells:
            self.mark_dirty()
        self.record_current_population()
        self.update_canvas()
        self.status_var.set(f"Placed '{pattern_name}' with {placed_cells} live cells.")

    def draw_pattern_preview(self):
        self.clear_pattern_preview()
        if not self.pending_pattern or self.pattern_preview_anchor is None:
            return

        anchor_r, anchor_c = self.pattern_preview_anchor
        for r, row in enumerate(self.pending_pattern):
            for c, cell in enumerate(row):
                if not cell:
                    continue
                rr, cc = anchor_r + r, anchor_c + c
                if 0 <= rr < self.rows and 0 <= cc < self.cols:
                    x0 = cc * self.cell_size + 2
                    y0 = rr * self.cell_size + 2
                    x1 = x0 + self.cell_size - 4
                    y1 = y0 + self.cell_size - 4
                    item = self.canvas.create_rectangle(
                        x0,
                        y0,
                        x1,
                        y1,
                        fill=self.get_theme_color("preview_fill"),
                        outline=self.get_theme_color("preview_outline"),
                        stipple="gray50",
                    )
                    self.pattern_preview_items.append(item)

    def clear_pattern_preview(self):
        for item in self.pattern_preview_items:
            self.canvas.delete(item)
        self.pattern_preview_items = []

    def cancel_pattern_preview(self):
        self.pending_pattern = None
        self.pending_pattern_name = None
        self.pattern_preview_anchor = None
        self.clear_pattern_preview()
        self.status_var.set("Pattern placement cancelled.")

    def clamp_dimension(self, value, minimum, maximum):
        try:
            value = int(value)
        except (TypeError, tk.TclError, ValueError):
            value = minimum
        return max(minimum, min(maximum, value))

    def apply_delay(self):
        self.delay_seconds = self.clamp_delay(self.delay_var.get())
        self.delay_var.set(self.delay_seconds)

    def clamp_delay(self, value):
        try:
            value = float(value)
        except (TypeError, tk.TclError, ValueError):
            value = self.delay_seconds
        return round(max(self.MIN_DELAY_SECONDS, min(self.MAX_DELAY_SECONDS, value)), 2)

    def get_delay_ms(self):
        self.apply_delay()
        return int(self.delay_seconds * 1000)

    def get_cell_size_for_board(self, rows, cols):
        available_w = max(1, self.winfo_screenwidth() - self.SCREEN_MARGIN_X)
        available_h = max(1, self.winfo_screenheight() - self.SCREEN_MARGIN_Y)
        fit_size = min(self.DEFAULT_CELL_SIZE, available_w // cols, available_h // rows)
        return max(self.MIN_CELL_SIZE, int(fit_size))

    def count_live_cells(self):
        return sum(sum(row) for row in self.grid)

    def record_generation_zero_edit(self):
        if self.generation == 0:
            self.edit_history.append(copy.deepcopy(self.grid))

    def record_current_population(self):
        live_cells = self.count_live_cells()
        if self.population_history:
            self.population_history[-1] = live_cells
        else:
            self.population_history = [live_cells]
        if self.generation == 0:
            self.generation_zero_grid = copy.deepcopy(self.grid)

    def update_graph(self):
        self.graph_canvas.config(bg=self.get_theme_color("graph_bg"))
        self.graph_canvas.delete("all")
        width = int(self.graph_canvas.cget("width"))
        height = int(self.graph_canvas.cget("height"))
        pad = self.GRAPH_PADDING
        left = pad + 6
        top = pad // 2
        right = width - pad // 2
        bottom = height - pad
        graph_w = max(1, right - left)
        graph_h = max(1, bottom - top)

        live_cells = self.population_history[-1] if self.population_history else 0
        max_live_cells = max(max(self.population_history or [0]), 1)

        self.graph_canvas.create_text(
            left,
            10,
            text=f"Live cells over generations: {live_cells}",
            anchor="w",
            fill=self.get_theme_color("graph_text"),
            font=("TkDefaultFont", 9, "bold"),
        )
        self.graph_canvas.create_line(left, bottom, right, bottom, fill=self.get_theme_color("graph_axis"))
        self.graph_canvas.create_line(left, top, left, bottom, fill=self.get_theme_color("graph_axis"))
        self.graph_canvas.create_text(
            left,
            bottom + 16,
            text="0",
            fill=self.get_theme_color("graph_label"),
            font=("TkDefaultFont", 8),
        )
        self.graph_canvas.create_text(
            right,
            bottom + 16,
            text=str(self.generation),
            fill=self.get_theme_color("graph_label"),
            font=("TkDefaultFont", 8),
        )
        self.graph_canvas.create_text(
            left - 8,
            top,
            text=str(max_live_cells),
            anchor="e",
            fill=self.get_theme_color("graph_label"),
            font=("TkDefaultFont", 8),
        )

        if len(self.population_history) == 1:
            x = left
            y = bottom - (self.population_history[0] / max_live_cells) * graph_h
            self.graph_canvas.create_oval(
                x - 2,
                y - 2,
                x + 2,
                y + 2,
                fill=self.get_theme_color("graph_line"),
                outline="",
            )
            return

        points = []
        last_index = max(1, len(self.population_history) - 1)
        for index, value in enumerate(self.population_history):
            x = left + (index / last_index) * graph_w
            y = bottom - (value / max_live_cells) * graph_h
            points.extend([x, y])

        self.graph_canvas.create_line(*points, fill=self.get_theme_color("graph_line"), width=2, smooth=True)
        final_x, final_y = points[-2], points[-1]
        self.graph_canvas.create_oval(
            final_x - 3,
            final_y - 3,
            final_x + 3,
            final_y + 3,
            fill=self.get_theme_color("graph_line"),
            outline="",
        )

    def update_generation_label(self):
        self.gen_var.set(f"Generation: {self.generation}")


if __name__ == "__main__":
    app = GameOfLifeApp()
    app.mainloop()
