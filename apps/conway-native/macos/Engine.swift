import Foundation

struct LifeDocument: Codable {
    var version = 3
    var app = "Conway’s Game of Life Lab"
    var rows: Int
    var cols: Int
    var grid: [[Int]]
    var generation_zero_grid: [[Int]]?
    var generation: Int
    var wrap: Bool
    var speed: Double
    var name: String
    var native_cols:Int?
    var native_rows:Int?
    var rules:[String:Int]?
    var v2_compatible:Bool?
    var borders: Bool?
    var live_cells: [[Int]]?
    var generation_zero_cells: [[Int]]?
    var survival_min: Int?
    var survival_max: Int?
    var birth_count: Int?
    var population_history: [Int]?
    enum CodingKeys: String, CodingKey { case population_history,native_cols,native_rows,rules,v2_compatible,version, app, rows, cols, grid, generation, wrap, speed, name, generation_zero_grid, borders, live_cells, generation_zero_cells, survival_min, survival_max, birth_count }
    init(rows: Int, cols: Int, grid: [[Int]], generation: Int, wrap: Bool, speed: Double, name: String) { self.rows=rows; self.cols=cols; self.grid=grid; self.generation=generation; self.wrap=wrap; self.speed=speed; self.name=name }
    init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        native_cols=try c.decodeIfPresent(Int.self,forKey:.native_cols);native_rows=try c.decodeIfPresent(Int.self,forKey:.native_rows);rules=try c.decodeIfPresent([String:Int].self,forKey:.rules);v2_compatible=try c.decodeIfPresent(Bool.self,forKey:.v2_compatible)
        borders=try c.decodeIfPresent(Bool.self,forKey:.borders)
        live_cells=try c.decodeIfPresent([[Int]].self,forKey:.live_cells)
        generation_zero_cells=try c.decodeIfPresent([[Int]].self,forKey:.generation_zero_cells)
        survival_min=try c.decodeIfPresent(Int.self,forKey:.survival_min)
        survival_max=try c.decodeIfPresent(Int.self,forKey:.survival_max)
        birth_count=try c.decodeIfPresent(Int.self,forKey:.birth_count)
        population_history=try c.decodeIfPresent([Int].self,forKey:.population_history)
        generation_zero_grid=try c.decodeIfPresent([[Int]].self,forKey:.generation_zero_grid)
        rows=try c.decode(Int.self,forKey:.rows); cols=try c.decode(Int.self,forKey:.cols); grid=try c.decode([[Int]].self,forKey:.grid)
        generation=try c.decodeIfPresent(Int.self,forKey:.generation) ?? 0; wrap=try c.decodeIfPresent(Bool.self,forKey:.wrap) ?? true
        speed=try c.decodeIfPresent(Double.self,forKey:.speed) ?? 2; name=try c.decodeIfPresent(String.self,forKey:.name) ?? "Imported canvas"
    }
}
struct Cell: Hashable { var x:Int; var y:Int }
struct LifeSnapshot { var cells: [UInt8]; var generation: Int; var name: String; var initial: [UInt8]? = nil; var outside:Set<Cell> = []; var initialOutside:Set<Cell> = []; var cols=160; var rows=100; var borders=false; var survivalMin=2; var survivalMax=3; var birthCount=3; var populationHistory:[Int]=[] }
struct LifeEngine {
    var cols = 160, rows = 100
    var cells = [UInt8](repeating: 0, count: 16000)
    var generation = 0
    var wrap = true
    var borders = false
    var outside:Set<Cell> = []
    var selectedOutside:Set<Cell> = []
    var survivalMin=2, survivalMax=3, birthCount=3
    var equilibrium=false
    var speed = 2.0
    var name = "Default"
    var history: [LifeSnapshot] = []
    var redos: [LifeSnapshot] = []
    var cursorX = 80, cursorY = 50
    var selected: Set<Int> = []
    var seed: LifeSnapshot?
    static let populationLimit=2048
    var populationHistory=[0]
    var populationSeries:[Int] {var values=populationHistory;if values.isEmpty{values=[population]}else{values[values.count-1]=population};return values}
    mutating func resetPopulation(){populationHistory=[population]}
    mutating func appendPopulation(){populationHistory.append(population);if populationHistory.count>Self.populationLimit{populationHistory.removeFirst()}}
    var population: Int { cells.reduce(0) { $0 + Int($1) } + outside.count }
    func snapshot() -> LifeSnapshot { LifeSnapshot(cells: cells,generation:generation,name:name,initial:generation == 0 ? cells : seed?.cells,outside:outside,initialOutside:generation == 0 ? outside : (seed?.outside ?? []),cols:cols,rows:rows,borders:borders,survivalMin:survivalMin,survivalMax:survivalMax,birthCount:birthCount,populationHistory:populationSeries) }
    mutating func restore(_ s:LifeSnapshot) { cols=s.cols;rows=s.rows;borders=s.borders;survivalMin=s.survivalMin;survivalMax=s.survivalMax;birthCount=s.birthCount;cells=s.cells;outside=s.outside;generation=s.generation;populationHistory=s.populationHistory.isEmpty ? [population]:s.populationHistory;selected=[];selectedOutside=[];equilibrium=false;seed=LifeSnapshot(cells:s.initial ?? s.cells,generation:0,name:s.name,outside:s.initialOutside) }
    mutating func checkpoint() {
        redos.removeAll(); history.append(snapshot())
        if history.count > 96 { history.removeFirst() }
    }
    mutating func undo() { if let s=history.popLast() { redos.append(snapshot());restore(s) } }
    mutating func redo() { if let s=redos.popLast() { history.append(snapshot());restore(s) } }
    var selection:Set<Cell> { Set(selected.map {Cell(x:$0%cols,y:$0/cols)}).union(selectedOutside) }
    var live:Set<Cell> { var result=outside;for i in cells.indices where cells[i]==1 {result.insert(Cell(x:i%cols,y:i/cols))};return result }
    func alive(_ x:Int,_ y:Int)->Bool { if x>=0 && x<cols && y>=0 && y<rows {return cells[y*cols+x]==1};return !borders && outside.contains(Cell(x:x,y:y)) }
    func valid(_ x:Int,_ y:Int)->Bool { !borders || (x>=0 && x<cols && y>=0 && y<rows) }
    mutating func unselect() { selected=[];selectedOutside=[] }
    mutating func select(_ x:Int,_ y:Int) { guard valid(x,y) else{return};if x>=0 && x<cols && y>=0 && y<rows {selected.insert(y*cols+x)}else{selectedOutside.insert(Cell(x:x,y:y))} }
    mutating func editSelection(_ mode:Int) { checkpoint();let targets=selection.isEmpty ? Set([Cell(x:cursorX,y:cursorY)]) : selection;for p in targets {set(p.x,p.y,mode==2 ? !alive(p.x,p.y) : mode==1)};if generation==0 {rememberSeed()} }
    mutating func moveCursor(_ dx:Int,_ dy:Int,select selecting:Bool) { if selecting {select(cursorX,cursorY)};cursorX += dx;cursorY += dy;if borders {cursorX=max(0,min(cols-1,cursorX));cursorY=max(0,min(rows-1,cursorY))};if selecting {select(cursorX,cursorY)} }
    func copiedRows()->[String]? {let points=selection;guard !points.isEmpty else{return nil};let x0=points.map(\.x).min()!,x1=points.map(\.x).max()!,y0=points.map(\.y).min()!,y1=points.map(\.y).max()!;guard (x1-x0+1)*(y1-y0+1)<=262144 else{return nil};return (y0...y1).map {y in String((x0...x1).map{x in points.contains(Cell(x:x,y:y)) && alive(x,y) ? Character("O") : Character(".")})} }
    mutating func place(_ pattern:[String],atX x:Int,atY y:Int,overwrite:Bool=false) { guard !pattern.isEmpty else{return};checkpoint();let w=pattern.map(\.count).max() ?? 0;for (ry,row) in pattern.enumerated(){for (rx,c) in row.enumerated() where c=="O" || overwrite{set(x-w/2+rx,y-pattern.count/2+ry,c=="O")}};if generation==0{rememberSeed()} }
    mutating func configureBorders(_ on:Bool,_ width:Int,_ height:Int) {checkpoint();let old=live;cols=width;rows=height;borders=on;cells=[UInt8](repeating:0,count:cols*rows);outside=[];unselect();for p in old{set(p.x,p.y,true)};if borders{cursorX=max(0,min(cols-1,cursorX));cursorY=max(0,min(rows-1,cursorY))};rememberSeed() }
    mutating func configureRules(_ low:Int,_ high:Int,_ birth:Int) { checkpoint();survivalMin=low;survivalMax=high;birthCount=birth;equilibrium=false }
    mutating func back() { guard let index = history.lastIndex(where: { $0.generation < generation }) else { return }; history.removeSubrange((index+1)..<history.count); undo() }
    mutating func set(_ x:Int,_ y:Int,_ value:Bool) {guard valid(x,y) else{return};if x>=0 && x<cols && y>=0 && y<rows {cells[y*cols+x]=value ? 1:0}else{let p=Cell(x:x,y:y);if value{outside.insert(p)}else{outside.remove(p)}};equilibrium=false}
    mutating func step(record:Bool = true) {
        if generation==0{rememberSeed()};populationHistory=populationSeries;if record{checkpoint()};let old=live;var counts:[Cell:Int]=[:]
        for p in old {if counts[p]==nil{counts[p]=0};for dy in -1...1{for dx in -1...1 where dx != 0 || dy != 0 {var x=p.x+dx,y=p.y+dy;if borders && wrap{x=(x+cols)%cols;y=(y+rows)%rows};if valid(x,y){counts[Cell(x:x,y:y),default:0]+=1}}}}
        if borders && birthCount==0 {for y in 0..<rows{for x in 0..<cols{if counts[Cell(x:x,y:y)]==nil{counts[Cell(x:x,y:y)]=0}}}}
        var next:Set<Cell>=[];for (p,n) in counts{if old.contains(p) ? (survivalMin...survivalMax).contains(n) : n==birthCount{next.insert(p)}}
        cells=[UInt8](repeating:0,count:cols*rows);outside=[];for p in next{set(p.x,p.y,true)};equilibrium=old==next;generation+=1;appendPopulation()
    }
    mutating func clear() { checkpoint(); cells = cells.map { _ in 0 }; outside=[];equilibrium=false; generation = 0; seed = nil; unselect();resetPopulation() }
    mutating func loadPattern(_ p: LifePattern) {
        checkpoint(); cells = cells.map { _ in 0 }; outside=[];equilibrium=false; generation = 0; name = p.name; selected=[]
        let width = p.rows.map(\.count).max() ?? 0
        for (y,row) in p.rows.enumerated() { for (x,c) in row.enumerated() where c == "O" { set(x+(cols-width)/2, y+(rows-p.rows.count)/2, true) } }
        seed = LifeSnapshot(cells: cells, generation: 0, name: name,outside:outside);resetPopulation()
    }
    mutating func randomize(density:Double = 0.25) {
        checkpoint(); cells = cells.map { _ in 0 }; outside=[];equilibrium=false; generation = 0; unselect()
        for y in 0..<rows { for x in 0..<cols { set(x,y, Double.random(in: 0..<1) < density) } }
        seed = LifeSnapshot(cells: cells, generation: 0, name: name,outside:outside);resetPopulation()
    }
    mutating func randomizeRegion(_ density:Double,_ x0:Int,_ y0:Int,_ width:Int,_ height:Int) {checkpoint();cells=cells.map{_ in 0};outside=[];unselect();generation=0;for y in y0..<(y0+height){for x in x0..<(x0+width){set(x,y,Double.random(in:0..<1)<density)}};rememberSeed()}
    mutating func rememberSeed() { if generation==0{resetPopulation()};seed = LifeSnapshot(cells: cells, generation: 0, name: name,outside:outside) }
    mutating func restart() { if let s = seed { checkpoint(); cells = s.cells; outside=s.outside;equilibrium=false; generation = s.generation; if generation == 0 { rememberSeed() } } }
    func initialLive()->Set<Cell> {var r=generation==0 ? outside : (seed?.outside ?? outside);let c=generation==0 ? cells : (seed?.cells ?? cells);for i in c.indices where c[i]==1{r.insert(Cell(x:i%cols,y:i/cols))};return r}
    func document()->LifeDocument {let living=live,initial=initialLive(),all=living.union(initial);var x0=0,y0=0,w=cols,h=rows;if !borders{x0=all.map(\.x).min() ?? 0;y0=all.map(\.y).min() ?? 0;w=max(5,(all.map(\.x).max() ?? x0)-x0+1);h=max(5,(all.map(\.y).max() ?? y0)-y0+1)};let compatible=w<=100 && h<=100;w=min(512,w);h=min(512,h)
        func grid(_ points:Set<Cell>)->[[Int]] {(y0..<(y0+h)).map{y in (x0..<(x0+w)).map{x in points.contains(Cell(x:x,y:y)) ? 1:0}}}
        var d=LifeDocument(rows:h,cols:w,grid:grid(living),generation:generation,wrap:wrap,speed:speed,name:name);d.generation_zero_grid=grid(initial);d.native_cols=cols;d.native_rows=rows;d.borders=borders;d.live_cells=living.sorted{$0.y == $1.y ? $0.x<$1.x:$0.y<$1.y}.map{[$0.x,$0.y]};d.generation_zero_cells=initial.sorted{$0.y == $1.y ? $0.x<$1.x:$0.y<$1.y}.map{[$0.x,$0.y]};d.rules=["survival_min":survivalMin,"survival_max":survivalMax,"birth_count":birthCount];d.v2_compatible=compatible;d.population_history=populationSeries;return d
    }
    mutating func load(_ data: Data) throws {
        let d = try JSONDecoder().decode(LifeDocument.self, from: data)
        guard (4...512).contains(d.rows), (4...512).contains(d.cols), d.grid.count == d.rows,
              d.grid.allSatisfy({ $0.count == d.cols && $0.allSatisfy { $0 == 0 || $0 == 1 } }),
              (d.generation_zero_grid == nil || (d.generation_zero_grid!.count == d.rows && d.generation_zero_grid!.allSatisfy { $0.count == d.cols && $0.allSatisfy { $0 == 0 || $0 == 1 } })),
              d.generation >= 0, d.generation < Int.max, d.speed.isFinite, (0.1...60).contains(d.speed) else { throw NSError(domain: "Life", code: 1, userInfo: [NSLocalizedDescriptionKey:"This file has invalid board dimensions or cell data."]) }
        let low=d.rules?["survival_min"] ?? d.survival_min ?? 2, high=d.rules?["survival_max"] ?? d.survival_max ?? 3, birth=d.rules?["birth_count"] ?? d.birth_count ?? 3
        guard (0...8).contains(low),(low...8).contains(high),(0...8).contains(birth), (d.borders ?? true) || birth != 0, (d.live_cells ?? []).count<=1000000, (d.live_cells ?? []).allSatisfy({$0.count==2 && $0.allSatisfy{$0 >= -1000000000 && $0<=1000000000}}), (d.generation_zero_cells ?? []).allSatisfy({$0.count==2 && $0.allSatisfy{$0 >= -1000000000 && $0<=1000000000}}) else{throw NSError(domain:"Life",code:3,userInfo:[NSLocalizedDescriptionKey:"Invalid rules or infinite cell coordinates."])}
        guard (4...512).contains(d.native_cols ?? d.cols),(4...512).contains(d.native_rows ?? d.rows) else {throw NSError(domain:"Life",code:4)}
        borders=d.borders ?? true;survivalMin=low;survivalMax=high;birthCount=birth;outside=[];selectedOutside=[];equilibrium=false
        rows = d.native_rows ?? d.rows; cols = d.native_cols ?? d.cols; cells = [UInt8](repeating:0,count:cols*rows);for y in 0..<d.rows{for x in 0..<d.cols{set(x,y,d.grid[y][x]==1)}}; generation = d.generation; wrap = d.wrap; speed = d.speed; name = d.name
        if let points=d.live_cells {cells=[UInt8](repeating:0,count:cols*rows);for p in points{set(p[0],p[1],true)}}
        var initial=LifeEngine();initial.cols=cols;initial.rows=rows;initial.borders=borders;initial.cells=[UInt8](repeating:0,count:cols*rows)
        if let points=d.generation_zero_cells{for p in points{initial.set(p[0],p[1],true)}}else{for y in 0..<d.rows{for x in 0..<d.cols{initial.set(x,y,(d.generation_zero_grid ?? d.grid)[y][x]==1)}}}
        populationHistory=Array((d.population_history ?? []).suffix(Self.populationLimit));populationHistory=populationHistory.allSatisfy{$0>=0 && $0<=Int(Int32.max)} ? populationHistory:[];populationHistory=populationSeries;history=[];redos=[];unselect();cursorX=cols/2;cursorY=rows/2;seed=LifeSnapshot(cells:initial.cells,generation:0,name:name,outside:initial.outside)
    }
}

// Adding a graph to an older saved session must not create a false unsaved-edit prompt.
func lifeDocumentsMatch(_ current:Data,_ saved:Data)->Bool {
    guard var a=(try? JSONSerialization.jsonObject(with:current)) as? [String:Any],let b=(try? JSONSerialization.jsonObject(with:saved)) as? [String:Any] else{return false}
    if b["population_history"] == nil || b["population_history"] is NSNull {a.removeValue(forKey:"population_history")}
    return NSDictionary(dictionary:a).isEqual(to:b)
}
