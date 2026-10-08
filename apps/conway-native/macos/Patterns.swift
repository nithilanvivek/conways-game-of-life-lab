import Foundation
struct LifePattern: Identifiable { let name: String; let category: String; let detail: String; let rows: [String]; var id: String { name } }
let patterns: [LifePattern] = [
LifePattern(name: "Glider", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: [".O.", "..O", "OOO"]),
LifePattern(name: "Pulsar", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: ["..OOO...OOO..", ".............", "O....O.O....O", "O....O.O....O", "O....O.O....O", "..OOO...OOO..", ".............", "..OOO...OOO..", "O....O.O....O", "O....O.O....O", "O....O.O....O", ".............", "..OOO...OOO.."]),
LifePattern(name: "Gosper gun", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: ["........................O...........", "......................O.O...........", "............OO......OO............OO", "...........O...O....OO............OO", "OO........O.....O...OO..............", "OO........O...O.OO....O.O...........", "..........O.....O.......O...........", "...........O...O....................", "............OO......................"]),
LifePattern(name: "Lightweight spaceship", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: [".O..O", "O....", "O...O", "OOOO."]),
LifePattern(name: "R-pentomino", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: [".OO", "OO.", ".O."]),
LifePattern(name: "Acorn", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: [".O.....", "...O...", "OO..OOO"]),
LifePattern(name: "Pentadecathlon", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: ["..O....O..", "OO.OOOO.OO", "..O....O.."]),
LifePattern(name: "Blinker", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: ["OOO"]),
LifePattern(name: "Block", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: ["OO", "OO"]),
LifePattern(name: "Beehive", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: [".OO.", "O..O", ".OO."]),
LifePattern(name: "Tub", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: [".O.", "O.O", ".O."]),
LifePattern(name: "Seed", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: ["O.O", "OO.", ".O."]),
LifePattern(name: "Cross", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: [".O.", "OOO", ".O."]),
LifePattern(name: "Single Cell", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: ["O"]),
LifePattern(name: "Spaceship Seed", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: [".O..", "O.O.", "O..O", ".OO."]),
LifePattern(name: "Hollow Ring", category: "Built-in", detail: "Choose a pattern to place on the canvas.", rows: [".OO.", "O..O", "O..O", ".OO."])
]
