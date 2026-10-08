namespace Nithi.Life;
public record Pattern(string Name, string Category, string Detail, string[] Rows);
public static class Catalog { public static readonly Pattern[] All = [
new("Glider", "Built-in", "Choose a pattern to place on the canvas.", [".O.", "..O", "OOO"]),
new("Pulsar", "Built-in", "Choose a pattern to place on the canvas.", ["..OOO...OOO..", ".............", "O....O.O....O", "O....O.O....O", "O....O.O....O", "..OOO...OOO..", ".............", "..OOO...OOO..", "O....O.O....O", "O....O.O....O", "O....O.O....O", ".............", "..OOO...OOO.."]),
new("Gosper gun", "Built-in", "Choose a pattern to place on the canvas.", ["........................O...........", "......................O.O...........", "............OO......OO............OO", "...........O...O....OO............OO", "OO........O.....O...OO..............", "OO........O...O.OO....O.O...........", "..........O.....O.......O...........", "...........O...O....................", "............OO......................"]),
new("Lightweight spaceship", "Built-in", "Choose a pattern to place on the canvas.", [".O..O", "O....", "O...O", "OOOO."]),
new("R-pentomino", "Built-in", "Choose a pattern to place on the canvas.", [".OO", "OO.", ".O."]),
new("Acorn", "Built-in", "Choose a pattern to place on the canvas.", [".O.....", "...O...", "OO..OOO"]),
new("Pentadecathlon", "Built-in", "Choose a pattern to place on the canvas.", ["..O....O..", "OO.OOOO.OO", "..O....O.."]),
new("Blinker", "Built-in", "Choose a pattern to place on the canvas.", ["OOO"]),
new("Block", "Built-in", "Choose a pattern to place on the canvas.", ["OO", "OO"]),
new("Beehive", "Built-in", "Choose a pattern to place on the canvas.", [".OO.", "O..O", ".OO."]),
new("Tub", "Built-in", "Choose a pattern to place on the canvas.", [".O.", "O.O", ".O."]),
new("Seed", "Built-in", "Choose a pattern to place on the canvas.", ["O.O", "OO.", ".O."]),
new("Cross", "Built-in", "Choose a pattern to place on the canvas.", [".O.", "OOO", ".O."]),
new("Single Cell", "Built-in", "Choose a pattern to place on the canvas.", ["O"]),
new("Spaceship Seed", "Built-in", "Choose a pattern to place on the canvas.", [".O..", "O.O.", "O..O", ".OO."]),
new("Hollow Ring", "Built-in", "Choose a pattern to place on the canvas.", [".OO.", "O..O", "O..O", ".OO."])
]; }
