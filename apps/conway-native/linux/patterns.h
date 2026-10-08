/* Generated from shared/patterns.json. */
typedef struct { const char *name, *category, *detail; int height; const char *rows[13]; } Pattern;
static const Pattern patterns[] = {
{"Glider", "Built-in", "Choose a pattern to place on the canvas.", 3, {".O.", "..O", "OOO"}},
{"Pulsar", "Built-in", "Choose a pattern to place on the canvas.", 13, {"..OOO...OOO..", ".............", "O....O.O....O", "O....O.O....O", "O....O.O....O", "..OOO...OOO..", ".............", "..OOO...OOO..", "O....O.O....O", "O....O.O....O", "O....O.O....O", ".............", "..OOO...OOO.."}},
{"Gosper gun", "Built-in", "Choose a pattern to place on the canvas.", 9, {"........................O...........", "......................O.O...........", "............OO......OO............OO", "...........O...O....OO............OO", "OO........O.....O...OO..............", "OO........O...O.OO....O.O...........", "..........O.....O.......O...........", "...........O...O....................", "............OO......................"}},
{"Lightweight spaceship", "Built-in", "Choose a pattern to place on the canvas.", 4, {".O..O", "O....", "O...O", "OOOO."}},
{"R-pentomino", "Built-in", "Choose a pattern to place on the canvas.", 3, {".OO", "OO.", ".O."}},
{"Acorn", "Built-in", "Choose a pattern to place on the canvas.", 3, {".O.....", "...O...", "OO..OOO"}},
{"Pentadecathlon", "Built-in", "Choose a pattern to place on the canvas.", 3, {"..O....O..", "OO.OOOO.OO", "..O....O.."}},
{"Blinker", "Built-in", "Choose a pattern to place on the canvas.", 1, {"OOO"}},
{"Block", "Built-in", "Choose a pattern to place on the canvas.", 2, {"OO", "OO"}},
{"Beehive", "Built-in", "Choose a pattern to place on the canvas.", 3, {".OO.", "O..O", ".OO."}},
{"Tub", "Built-in", "Choose a pattern to place on the canvas.", 3, {".O.", "O.O", ".O."}},
{"Seed", "Built-in", "Choose a pattern to place on the canvas.", 3, {"O.O", "OO.", ".O."}},
{"Cross", "Built-in", "Choose a pattern to place on the canvas.", 3, {".O.", "OOO", ".O."}},
{"Single Cell", "Built-in", "Choose a pattern to place on the canvas.", 1, {"O"}},
{"Spaceship Seed", "Built-in", "Choose a pattern to place on the canvas.", 4, {".O..", "O.O.", "O..O", ".OO."}},
{"Hollow Ring", "Built-in", "Choose a pattern to place on the canvas.", 4, {".OO.", "O..O", "O..O", ".OO."}}
};
#define PATTERN_COUNT (sizeof(patterns)/sizeof(patterns[0]))
