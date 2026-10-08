import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct Palette {var background,panel,alive,text,muted,grid,cursor,selection,preview:String
    static func forName(_ name:String)->Palette {switch name{case "Light":return Palette(background:"#FFFFFF",panel:"#F0F0F0",alive:"#000000",text:"#000000",muted:"#555555",grid:"#000000",cursor:"#0000FF",selection:"#FF9F1C",preview:"#68D391");case "Sepia":return Palette(background:"#F5EAD3",panel:"#EAD8B8",alive:"#5A351D",text:"#4B2D18",muted:"#6D4A28",grid:"#5A351D",cursor:"#8A5A2B",selection:"#B66A2A",preview:"#9D6B36");default:return Palette(background:"#091111",panel:"#121A1A",alive:"#73E8B0",text:"#E3EDE8",muted:"#8C9F98",grid:"#73E8B0",cursor:"#8AB4FF",selection:"#F5A623",preview:"#A2F2CF")}}
}
func nsColor(_ hex:String)->NSColor {let v=Int(hex.dropFirst(),radix:16) ?? 0;return NSColor(srgbRed:Double(v>>16&255)/255,green:Double(v>>8&255)/255,blue:Double(v&255)/255,alpha:1)}
struct TourStep:Codable {var title,area,text:String}
struct Preferences:Codable {var theme="Dark";var tour_seen=false;enum CodingKeys:String,CodingKey{case theme,tour_seen};init(){};init(from decoder:Decoder)throws{let c=try decoder.container(keyedBy:CodingKeys.self);theme=try c.decodeIfPresent(String.self,forKey:.theme) ?? "Dark";tour_seen=try c.decodeIfPresent(Bool.self,forKey:.tour_seen) ?? false}}
struct UserPattern:Codable,Identifiable {var name:String;var rows:[String];var id:String{name}}
@MainActor final class LifeStore: ObservableObject {
    @Published var engine = LifeEngine()
    @Published var running = false
    @Published var tool = "Paint"
    @Published var pan = false
    @Published var grid = true
    @Published var message = "Ready. Draw cells or choose a pattern."
    @Published var density = 25
    @Published var zoomLabel = "100%"
    weak var canvas: LifeCanvas?
    var timer: Timer?
    let autosave = ((ProcessInfo.processInfo.environment["LIFE_SESSION_DIR"] ?? (Bundle.main.object(forInfoDictionaryKey:"LifeQASessionDirectory") as? String)).map{URL(fileURLWithPath:$0)} ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("land.nithi.life")).appendingPathComponent("canvas.life.json")
    @Published var palette=Palette.forName("Dark")
    @Published var theme="Dark" { didSet { applyTheme() } }
    @Published var sheet:String? = nil
    @Published var entry=""
    @Published var width="100"
    @Published var height="100"
    @Published var low="2"
    @Published var high="3"
    @Published var birth="3"
    @Published var userPatterns:[UserPattern]=[]
    @Published var pending:[String]? = nil
    @Published var pendingName=""
    @Published var tourIndex=0
    @Published var error=""
    var tour:[TourStep]=[]
    var tourArea:String?{sheet=="tour" && !tour.isEmpty ? tour[tourIndex].area:nil}
    var preferences=Preferences()
    var savedFingerprint="",currentFile:URL?
    var afterSave:(()->Void)?
    var quitPending=false
    var closeCompletion:(()->Void)?
    lazy var windowDelegate=CloseDelegate(store:self)
    var base:URL{autosave.deletingLastPathComponent()}
    var library:URL{if let path=ProcessInfo.processInfo.environment["LIFE_DATA_DIR"] ?? (Bundle.main.object(forInfoDictionaryKey:"LifeQADataDirectory") as? String){return URL(fileURLWithPath:path)};return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Conway Game of Life Canvases")}
    var savedFiles:[URL] {((try? FileManager.default.contentsOfDirectory(at:library,includingPropertiesForKeys:nil)) ?? []).filter{$0.lastPathComponent.hasSuffix(".life.json")}.sorted{$0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending}}
    var dirty:Bool { !lifeDocumentsMatch(Data(fingerprint().utf8),Data(savedFingerprint.utf8)) }
    func fingerprint()->String {let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys];return String(data:(try? encoder.encode(engine.document())) ?? Data(),encoding:.utf8) ?? ""}
    init() {
        ensureLibrary();engine.loadPattern(patterns[1]);engine.name="Default";engine.history=[]
        if let data=try? Data(contentsOf:autosave){try? engine.load(data)}
        if let data=try? Data(contentsOf:library.appendingPathComponent("preferences.json")),let p=try? JSONDecoder().decode(Preferences.self,from:data){preferences=p;theme=p.theme}
        palette=Palette.forName(theme)
        if let data=try? Data(contentsOf:base.appendingPathComponent("patterns.json")){userPatterns=(try? JSONDecoder().decode([UserPattern].self,from:data)) ?? []}
        if let files=try? FileManager.default.contentsOfDirectory(at:library,includingPropertiesForKeys:nil){for file in files where file.lastPathComponent.hasSuffix(".pattern.json"){if let data=try? Data(contentsOf:file),let obj=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let name=obj["name"] as? String,let grid=obj["grid"] as? [[Int]],!grid.isEmpty,grid.count<=512,grid.allSatisfy({$0.count<=512 && $0.allSatisfy{$0==0 || $0==1}}),!userPatterns.contains(where:{$0.name==name}){userPatterns.append(UserPattern(name:name,rows:grid.map{String($0.map{$0==1 ? Character("O"):Character(".")})}))}}}
        if let url=Bundle.main.url(forResource:"tour",withExtension:"json"),let data=try? Data(contentsOf:url){tour=(try? JSONDecoder().decode([TourStep].self,from:data)) ?? []}
        if let data=try? Data(contentsOf:base.appendingPathComponent("session.json")),let session=try? JSONSerialization.jsonObject(with:data) as? [String:String]{savedFingerprint=session["saved"] ?? "";if let path=session["file"],!path.isEmpty{currentFile=URL(fileURLWithPath:path)}}else{savedFingerprint=fingerprint()}
    }
    func ensureLibrary(){if !FileManager.default.fileExists(atPath:library.path){try? FileManager.default.createDirectory(at:library,withIntermediateDirectories:true)}}
    func persist() {do{try FileManager.default.createDirectory(at:base,withIntermediateDirectories:true);try JSONEncoder().encode(engine.document()).write(to:autosave,options:.atomic);let session=["saved":savedFingerprint,"file":currentFile?.path ?? ""];try JSONSerialization.data(withJSONObject:session).write(to:base.appendingPathComponent("session.json"),options:.atomic)}catch{message="Could not autosave: \(error.localizedDescription)"}}
    func savePreferences(){preferences.theme=theme;ensureLibrary();try? JSONEncoder().encode(preferences).write(to:library.appendingPathComponent("preferences.json"),options:.atomic)}
    func applyTheme(){palette=Palette.forName(theme);savePreferences();canvas?.window?.backgroundColor=nsColor(palette.background);canvas?.window?.appearance=NSAppearance(named:theme=="Dark" ? .darkAqua:.aqua);canvas?.needsDisplay=true}
    func firstTour(){if !preferences.tour_seen && !tour.isEmpty{startTour()}}
    func startTour(){pause();tourIndex=0;sheet="tour"}
    func finishTour(){preferences.tour_seen=true;savePreferences();sheet=nil;if let canvas{canvas.window?.makeFirstResponder(canvas)}}
    func pause(){let wasRunning=running;running=false;timer?.invalidate();timer=nil;if wasRunning{message=engine.equilibrium ? "Paused · Equilibrium reached":"Paused."};persist()}
    func toggle(){if running{pause();return};running=true;message="Running.";startTimer()}
    func startTimer(){timer?.invalidate();timer=Timer.scheduledTimer(withTimeInterval:1/engine.speed,repeats:true){[weak self] _ in MainActor.assumeIsolated{guard let self,self.running else{return};self.engine.step();self.message=self.engine.equilibrium ? "Equilibrium reached":"Running.";self.persist()}}}
    func pattern(_ p:LifePattern){pause();pending=p.rows;pendingName=p.name;message="Move the preview and click to place \(p.name). Esc cancels.";canvas?.needsDisplay=true}
    func place(){guard let rows=pending else{return};pause();engine.place(rows,atX:canvas?.pointerX ?? engine.cursorX,atY:canvas?.pointerY ?? engine.cursorY);pending=nil;message="Placed \(pendingName).";persist()}
    func step(){pause();engine.step();message=engine.equilibrium ? "Equilibrium reached":"Advanced one generation.";persist()}
    func textEditor()->NSTextView?{guard let editor=NSApplication.shared.keyWindow?.firstResponder as? NSTextView,editor.isFieldEditor else{return nil};return editor}
    func undo(){if let editor=textEditor(){editor.undoManager?.undo();return};pause();engine.undo();message="Undid the latest change.";persist()}
    func redo(){if let editor=textEditor(){editor.undoManager?.redo();return};pause();engine.redo();message="Redid the latest change.";persist()}
    func back(){pause();engine.back();persist()}
    func reset(){pause();engine.restart();persist()}
    func random(){pause();if engine.borders{engine.randomize(density:Double(density)/100)}else if let c=canvas{let r=c.visibleRegion();engine.randomizeRegion(Double(density)/100,r.0,r.1,r.2,r.3)};message="Generated Generation 0 at \(density)% density.";persist()}
    func clear(){pause();engine.clear();message="Canvas cleared.";persist()}
    func unselect(){engine.unselect();pending=nil;message="Selection cleared.";canvas?.needsDisplay=true}
    func copySelection(){if let editor=textEditor(){editor.copy(nil);return};guard let rows=engine.copiedRows() else{message="Select cells before copying.";return};let text="life-pattern:"+((try? String(data:JSONEncoder().encode(rows),encoding:.utf8)) ?? "[]");NSPasteboard.general.clearContents();NSPasteboard.general.setString(text,forType:.string);message="Copied selection."}
    func pasteSelection(){if let editor=textEditor(){editor.paste(nil);return};guard let text=NSPasteboard.general.string(forType:.string),text.hasPrefix("life-pattern:"),let data=String(text.dropFirst(13)).data(using:.utf8),let rows=try? JSONDecoder().decode([String].self,from:data),!rows.isEmpty,rows.count<=512,rows.allSatisfy({$0.count<=512 && $0.allSatisfy{$0=="O" || $0=="."}}) else{message="Copy a Life selection first.";return};pause();engine.place(rows,atX:engine.cursorX,atY:engine.cursorY,overwrite:true);message="Pasted at the cursor.";persist()}
    func savePattern(){guard !engine.selection.isEmpty else{return};entry="My pattern";sheet="pattern"}
    func saveCanvas(){pause();error="";entry=engine.name;sheet=currentFile == nil ? "save":"overwrite"}
    func writeCanvas(_ overwrite:Bool=false){let name=overwrite ? engine.name : entry.trimmingCharacters(in:.whitespacesAndNewlines);guard !name.isEmpty else{error="Enter a name.";return};do{ensureLibrary();let safe=name.unicodeScalars.map{CharacterSet.alphanumerics.contains($0) || " _-".unicodeScalars.contains($0) ? String($0):"_"}.joined();let url=overwrite ? currentFile! : library.appendingPathComponent(safe+".life.json");if !overwrite && FileManager.default.fileExists(atPath:url.path){error="That name exists. Choose another name or load it to overwrite.";return};engine.name=name;try JSONEncoder().encode(engine.document()).write(to:url,options:.atomic);currentFile=url;savedFingerprint=fingerprint();sheet=nil;message="Saved \(name).";persist();let completion=afterSave;afterSave=nil;completion?()}catch{self.error=error.localizedDescription}}
    func storePattern(){let name=entry.trimmingCharacters(in:.whitespacesAndNewlines);guard !name.isEmpty,let rows=engine.copiedRows() else{error="Select cells and enter a name.";return};if userPatterns.contains(where:{$0.name==name}){error="That pattern name exists.";return};userPatterns.append(UserPattern(name:name,rows:rows));do{ensureLibrary();let safe=name.unicodeScalars.map{CharacterSet.alphanumerics.contains($0) || " _-".unicodeScalars.contains($0) ? String($0):"_"}.joined();let obj:[String:Any]=["name":name,"type":"pattern","version":1,"rows":rows.count,"cols":rows.map(\.count).max() ?? 0,"grid":rows.map{$0.map{$0=="O" ? 1:0}}];try JSONSerialization.data(withJSONObject:obj).write(to:library.appendingPathComponent(safe+".pattern.json"),options:.atomic);try JSONEncoder().encode(userPatterns).write(to:base.appendingPathComponent("patterns.json"),options:.atomic);sheet=nil;message="Saved pattern \(name)."}catch{self.error=error.localizedDescription}}
    func loadCanvas(){pause();ensureLibrary();sheet="load"}
    func loadFile(_ url:URL){do{let data=try Data(contentsOf:url);guard data.count<=16000000 else{throw NSError(domain:"Life",code:2)};try engine.load(data);currentFile=url;savedFingerprint=fingerprint();sheet=nil;pending=nil;width=String(engine.cols);height=String(engine.rows);canvas?.fit(living:true);persist()}catch{self.error=error.localizedDescription}}
    func requestClose(_ completion:@escaping ()->Void){pause();if !dirty{completion();return};closeCompletion=completion;sheet="close"}
    func open(){pause();let p=NSOpenPanel();p.title="Import";p.allowedContentTypes=[.json];if p.runModal() == .OK,let url=p.url{do{let data=try Data(contentsOf:url);let object=try JSONSerialization.jsonObject(with:data) as? [String:Any];guard (object?["cols"] as? Int ?? 0)<=100,(object?["rows"] as? Int ?? 0)<=100 else{message="This canvas exceeds 100 × 100. Please import a smaller canvas.";error=message;sheet="error";return};var imported=LifeEngine();try imported.load(data);engine=imported;currentFile=nil;savedFingerprint=fingerprint();pending=nil;canvas?.fit(living:true);persist();message="Imported canvas."}catch{self.error=error.localizedDescription;sheet="error"}}}
    func save(){pause();if engine.document().v2_compatible == false{sheet="export";return};exportDocument(engine.document())}
    func exportDocument(_ d:LifeDocument){let p=NSSavePanel();p.title="Export";p.allowedContentTypes=[.json];p.nameFieldStringValue=engine.name+".life.json";if p.runModal() == .OK,let url=p.url{do{try JSONEncoder().encode(d).write(to:url,options:.atomic);message="Exported canvas."}catch{message=error.localizedDescription}};sheet=nil}
    func exportRegion(){guard let rows=engine.copiedRows(),rows.count<=100,(rows.map(\.count).max() ?? 0)<=100 else{error="Select a region no larger than 100 × 100.";return};var e=LifeEngine();e.cols=max(5,rows.map(\.count).max() ?? 5);e.rows=max(5,rows.count);e.cells=[UInt8](repeating:0,count:e.cols*e.rows);e.borders=true;e.name=engine.name;e.survivalMin=engine.survivalMin;e.survivalMax=engine.survivalMax;e.birthCount=engine.birthCount;for (y,row) in rows.enumerated(){for (x,c) in row.enumerated(){e.set(x,y,c=="O")}};e.rememberSeed();exportDocument(e.document())}

}

final class LifeCanvas: NSView {
    var store: LifeStore!
    var scale: CGFloat = 12
    var origin = CGPoint.zero
    var lastPoint: CGPoint?
    var lastCell: (Int,Int)?
    var panning = false
    var selecting = false, keyboardCursor = true
    var pointerX=80,pointerY=50,cursorCentered=false,placed=false
    var initialized = false
    override func viewDidMoveToWindow(){super.viewDidMoveToWindow();window?.delegate=store.windowDelegate;window?.collectionBehavior.remove(.fullScreenNone);window?.collectionBehavior.insert(.fullScreenPrimary);window?.styleMask.formUnion([.titled,.closable,.miniaturizable,.resizable]);for kind in [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton]{if let button=window?.standardWindowButton(kind){button.isHidden=false;button.alphaValue=1;button.isEnabled=true}};window?.acceptsMouseMovedEvents=true;window?.makeFirstResponder(self)}
    override func updateTrackingAreas(){super.updateTrackingAreas();for area in trackingAreas{removeTrackingArea(area)};addTrackingArea(NSTrackingArea(rect:bounds,options:[.mouseMoved,.activeInKeyWindow,.inVisibleRect],owner:self,userInfo:nil))}
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func setFrameSize(_ newSize: NSSize) {
        let old = frame.size; super.setFrameSize(newSize)
        if !initialized && newSize.width > 10 && newSize.height > 10 { initialized = true; fit(living: true, defaultZoom: true) }
        else { origin.x += (newSize.width-old.width)/2; origin.y += (newSize.height-old.height)/2 }
    }
    func fit(living: Bool, defaultZoom: Bool = false) {
        guard store != nil else { return }
        let e = store.engine
        var minX = 0, maxX = e.cols-1, minY = 0, maxY = e.rows-1
        if living && e.population > 0 {
            minX = Int.max; minY = Int.max; maxX = Int.min; maxY = Int.min
            for p in e.live{minX=min(minX,p.x);maxX=max(maxX,p.x);minY=min(minY,p.y);maxY=max(maxY,p.y)}
            minX -= 8; minY -= 8; maxX += 8; maxY += 8
        }
        scale = defaultZoom ? 12 : min(28, max(2, min(bounds.width/CGFloat(maxX-minX+1),bounds.height/CGFloat(maxY-minY+1))))
        origin = CGPoint(x: bounds.midX-CGFloat(minX+maxX+1)/2*scale, y: bounds.midY-CGFloat(minY+maxY+1)/2*scale)
        if !cursorCentered{store.engine.cursorX=Int(floor((bounds.midX-origin.x)/scale));store.engine.cursorY=Int(floor((bounds.midY-origin.y)/scale));pointerX=store.engine.cursorX;pointerY=store.engine.cursorY;cursorCentered=true}
        updateZoom(); needsDisplay = true
    }
    func updateZoom() { store.zoomLabel = "\(Int(scale/12*100))%" }
    func zoom(_ factor: CGFloat, at p: CGPoint? = nil) {
        let anchor = p ?? CGPoint(x:bounds.midX,y:bounds.midY); let newScale = min(48,max(2,scale*factor)); let f = newScale/scale
        origin = CGPoint(x:anchor.x-(anchor.x-origin.x)*f,y:anchor.y-(anchor.y-origin.y)*f); scale = newScale; updateZoom(); needsDisplay = true
    }
    func visibleRegion()->(Int,Int,Int,Int){let x=Int(floor(-origin.x/scale)),y=Int(floor(-origin.y/scale));return(x,y,max(1,Int(ceil(bounds.width/scale))),max(1,Int(ceil(bounds.height/scale))))}
    func updatePointer(_ p:CGPoint){let x=Int(floor((p.x-origin.x)/scale)),y=Int(floor((p.y-origin.y)/scale));if store.engine.valid(x,y){pointerX=x;pointerY=y};needsDisplay=true}
    override func mouseMoved(with e:NSEvent){updatePointer(convert(e.locationInWindow,from:nil))}
    override func draw(_ rect:NSRect){guard let c=NSGraphicsContext.current?.cgContext,store != nil else{return};let e=store.engine,p=store.palette;let board=CGRect(x:origin.x,y:origin.y,width:CGFloat(e.cols)*scale,height:CGFloat(e.rows)*scale);c.setFillColor(nsColor(p.background).cgColor);c.fill(bounds)
        let r=visibleRegion(),x0=e.borders ? max(0,r.0):r.0,y0=e.borders ? max(0,r.1):r.1,x1=e.borders ? min(e.cols,r.0+r.2+1):r.0+r.2+1,y1=e.borders ? min(e.rows,r.1+r.3+1):r.1+r.3+1
        if store.grid && scale>=5 && x0<=x1 && y0<=y1{c.setStrokeColor(nsColor(p.grid).cgColor);c.setLineWidth(0.5);for x in x0...x1{let px=origin.x+CGFloat(x)*scale;c.move(to:CGPoint(x:px,y:e.borders ? max(0,board.minY):0));c.addLine(to:CGPoint(x:px,y:e.borders ? min(bounds.height,board.maxY):bounds.height))};for y in y0...y1{let py=origin.y+CGFloat(y)*scale;c.move(to:CGPoint(x:e.borders ? max(0,board.minX):0,y:py));c.addLine(to:CGPoint(x:e.borders ? min(bounds.width,board.maxX):bounds.width,y:py))};c.strokePath()}
        let inset:CGFloat=scale>=6 ? 1:0;func square(_ x:Int,_ y:Int)->CGRect{CGRect(x:origin.x+CGFloat(x)*scale+inset,y:origin.y+CGFloat(y)*scale+inset,width:scale-inset*2,height:scale-inset*2)}
        c.setFillColor(nsColor(p.alive).cgColor);for pt in e.live{let r=square(pt.x,pt.y);if bounds.intersects(r){c.fill(r)}}
        c.setFillColor(nsColor(p.selection).withAlphaComponent(0.3).cgColor);for pt in e.selection{c.fill(square(pt.x,pt.y))}
        if let rows=store.pending{let w=rows.map(\.count).max() ?? 0;c.setFillColor(nsColor(p.preview).withAlphaComponent(0.65).cgColor);for (y,row) in rows.enumerated(){for (x,ch) in row.enumerated() where ch=="O"{let cx=pointerX-w/2+x,cy=pointerY-rows.count/2+y;if e.valid(cx,cy){c.fill(square(cx,cy))}}};c.setStrokeColor(nsColor(p.preview).cgColor);c.setLineWidth(1);c.stroke(CGRect(x:origin.x+CGFloat(pointerX-w/2)*scale,y:origin.y+CGFloat(pointerY-rows.count/2)*scale,width:CGFloat(w)*scale,height:CGFloat(rows.count)*scale))}
        if e.borders{c.setStrokeColor(nsColor(p.muted).cgColor);c.setLineWidth(1);c.stroke(board)}
        if keyboardCursor{c.setStrokeColor(nsColor(p.cursor).cgColor);c.setLineWidth(2);c.stroke(square(e.cursorX,e.cursorY))}
    }
    override func scrollWheel(with event: NSEvent) { zoom(pow(1.04,-event.scrollingDeltaY), at:convert(event.locationInWindow,from:nil)) }
    override func magnify(with event: NSEvent) { zoom(1+event.magnification, at:convert(event.locationInWindow,from:nil)) }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self); let p = convert(event.locationInWindow,from:nil)
        placed=false;panning = store.pan || event.modifierFlags.contains(.option); lastPoint = p; lastCell = nil
        if store.pending != nil && !panning{updatePointer(p);store.place();placed=true;return}
        selecting=event.modifierFlags.contains(.shift);if selecting { select(p);return };if !panning { store.engine.unselect();store.pause(); store.engine.checkpoint(); paint(p) }
    }
    func paint(_ p: CGPoint) {
        let x = Int(floor((p.x-origin.x)/scale)), y = Int(floor((p.y-origin.y)/scale))
        let previous = lastCell ?? (x,y), steps = max(abs(x-previous.0),abs(y-previous.1))
        for i in 0...max(1,steps) { let t = Double(i)/Double(max(1,steps)); store.engine.set(Int(round(Double(previous.0)+Double(x-previous.0)*t)),Int(round(Double(previous.1)+Double(y-previous.1)*t)),store.tool != "Erase") }
        lastCell = (x,y);  needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        if placed{return};let p = convert(event.locationInWindow,from:nil)
        if selecting { select(p);return };if panning, let last = lastPoint { origin.x += p.x-last.x; origin.y += p.y-last.y; needsDisplay = true } else { paint(p) }; lastPoint = p
    }
    override func mouseUp(with event: NSEvent) { lastPoint = nil; lastCell = nil; if !panning && !selecting { if store.engine.generation == 0 { store.engine.rememberSeed() }; store.persist() }; panning = false;selecting=false }
    func select(_ p:CGPoint) {let x=Int(floor((p.x-origin.x)/scale)),y=Int(floor((p.y-origin.y)/scale));guard store.engine.valid(x,y) else{return};let previous=lastCell ?? (x,y);let steps=max(1,max(abs(x-previous.0),abs(y-previous.1)));for i in 0...steps {let cx=Int(round(Double(previous.0)+Double(x-previous.0)*Double(i)/Double(steps))),cy=Int(round(Double(previous.1)+Double(y-previous.1)*Double(i)/Double(steps)));store.engine.select(cx,cy)};lastCell=(x,y);keyboardCursor=true;needsDisplay=true;store.message="Selected \(store.engine.selection.count) cells." }
    func navigate(_ dx:Int,_ dy:Int,select:Bool) {store.engine.moveCursor(dx,dy,select:select);keyboardCursor=true;let x=origin.x+(CGFloat(store.engine.cursorX)+0.5)*scale,y=origin.y+(CGFloat(store.engine.cursorY)+0.5)*scale;if x<scale || x>bounds.width-scale {origin.x+=bounds.midX-x};if y<scale || y>bounds.height-scale {origin.y+=bounds.midY-y};store.message=select ? "Selected \(store.engine.selection.count) cells." : "Cell \(store.engine.cursorX+1), \(store.engine.cursorY+1).";needsDisplay=true}
    func editSelected(_ mode:Int) {store.pause();store.engine.editSelection(mode);store.message=mode==0 ? "Made selected cells dead." : mode==1 ? "Made selected cells alive." : "Inverted selected cells.";keyboardCursor=true;store.persist();needsDisplay=true}
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains([.command,.control]),event.charactersIgnoringModifiers?.lowercased()=="f"{window?.toggleFullScreen(nil);return}
        let control=event.modifierFlags.contains(.command)||event.modifierFlags.contains(.control)
        if control,let key=event.charactersIgnoringModifiers?.lowercased() {if key=="z" {store.undo();return};if key=="y" {store.redo();return};if key=="c"{store.copySelection();return};if key=="v"{store.pasteSelection();return}}
        let shift=event.modifierFlags.contains(.shift)
        switch event.keyCode {case 123:navigate(-1,0,select:shift);return;case 124:navigate(1,0,select:shift);return;case 125:navigate(0,1,select:shift);return;case 126:navigate(0,-1,select:shift);return;case 53:if !event.isARepeat{store.unselect();keyboardCursor=true;needsDisplay=true};return;case 36,76:editSelected(1);return;case 51,117:editSelected(0);return;default:break}
        switch event.charactersIgnoringModifiers?.lowercased() {
        case " ": editSelected(2)
        case ".": store.step()
        case "b": store.tool = "Paint"
        case "e": store.tool = "Erase"
        case "h": store.pan.toggle()
        case "f": fit(living:true)
        case "+", "=": zoom(1.2)
        case "-": zoom(1/1.2)
        default: super.keyDown(with:event)
        }
    }
}
struct CanvasView: NSViewRepresentable {
    @ObservedObject var store: LifeStore
    func makeNSView(context: Context) -> LifeCanvas { let v = LifeCanvas(); v.store = store; store.canvas = v; return v }
    func updateNSView(_ v: LifeCanvas, context: Context) { v.needsDisplay = true }
}

struct TourAnchors:PreferenceKey {
    static var defaultValue:[String:[Anchor<CGRect>]]{[:]}
    static func reduce(value:inout [String:[Anchor<CGRect>]],nextValue:()->[String:[Anchor<CGRect>]]){for (key,anchors) in nextValue(){value[key,default:[]].append(contentsOf:anchors)}}
}
extension View { @MainActor func tourFocus(_ area:String,_ store:LifeStore)->some View{anchorPreference(key:TourAnchors.self,value:.bounds){[area:[$0]]}.overlay(RoundedRectangle(cornerRadius:9).stroke(store.tourArea==area ? Color(nsColor(store.palette.alive)):Color.clear,lineWidth:3).padding(-3).allowsHitTesting(false))} }
struct RootView: View {
    @ObservedObject var store: LifeStore
    var ink:Color{Color(nsColor(store.palette.background))}
    var panel:Color{Color(nsColor(store.palette.panel))}
    var mint:Color{Color(nsColor(store.palette.alive))}
    var body: some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:12) {
                HStack(spacing:10) { Image(nsImage:NSApplication.shared.applicationIconImage).resizable().frame(width:40,height:40); VStack(alignment:.leading,spacing:2) { Text("Conway’s Game of Life Lab").font(.system(size:14,weight:.bold,design:.rounded)); Text("v3.1 · Pre-testing").font(.system(size:10)).foregroundStyle(.secondary) } }
                    .padding(.top,12)
                Text("PATTERN LIBRARY").font(.system(size:10,weight:.semibold)).tracking(2).foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing:6) {
                        ForEach(patterns) { p in
                            Button { store.pattern(p) } label: {
                                HStack(spacing:12) {
                                    PatternPreview(pattern:p,color:mint).frame(width:42,height:38)
                                    VStack(alignment:.leading,spacing:4) { Text(p.name).font(.system(size:12,weight:.semibold)); Text(p.category).font(.system(size:10)).foregroundStyle(.secondary) }; Spacer(minLength:0)
                                }.padding(10).background(store.engine.name == p.name ? mint.opacity(0.12) : Color(nsColor(store.palette.text)).opacity(0.035),in:RoundedRectangle(cornerRadius:10))
                            }.buttonStyle(.plain).help(p.detail)
                        }
                        ForEach(store.userPatterns){p in Button{store.pattern(LifePattern(name:p.name,category:"Saved",detail:"Place your saved pattern.",rows:p.rows))}label:{HStack(spacing:12){PatternPreview(pattern:LifePattern(name:p.name,category:"Saved",detail:"",rows:p.rows),color:mint).frame(width:42,height:38);VStack(alignment:.leading,spacing:4){Text(p.name).font(.system(size:12,weight:.semibold));Text("Saved").font(.system(size:10)).foregroundStyle(.secondary)};Spacer(minLength:0)}.padding(10).background(Color(nsColor(store.palette.text)).opacity(0.035),in:RoundedRectangle(cornerRadius:10))}.buttonStyle(.plain)}
                    }
                }.tourFocus("Pattern Library",store)

                Button("Save to Pattern Library",action:store.savePattern).disabled(store.engine.selection.isEmpty).tourFocus("Save to Pattern Library",store)
                HStack{Picker("Theme",selection:$store.theme){ForEach(["Dark","Light","Sepia"],id:\.self){Text($0)}}.tourFocus("Theme",store);Button("Help",action:store.startTour).tourFocus("Help",store)}
                Stepper("Random %: \(store.density)",value:$store.density,in:0...100).font(.system(size:11)).tourFocus("Generate",store)
                Text("Fills the specified amount of the grid randomly").font(.system(size:10)).foregroundStyle(.secondary)
                Button { store.random() } label: { Label("Generate",systemImage:"shuffle").frame(maxWidth:.infinity) }.controlSize(.large).tourFocus("Generate",store)
                VStack(alignment:.leading,spacing:8) {
                    Text("Rules").font(.system(size:9,weight:.bold)).tracking(1.5).foregroundStyle(mint)
                    Text("Dead cells are born with \(store.engine.birthCount) neighbors. Live cells survive with \(store.engine.survivalMin)–\(store.engine.survivalMax). Everything else fades.").font(.system(size:11)).foregroundStyle(.secondary).lineSpacing(4)
                    Button("Edit Rules"){store.low=String(store.engine.survivalMin);store.high=String(store.engine.survivalMax);store.birth=String(store.engine.birthCount);store.error="";store.sheet="rules"}.tourFocus("Edit Rules",store)
                }.padding(14).background(Color(nsColor(store.palette.text)).opacity(0.05),in:RoundedRectangle(cornerRadius:12))
                VStack(spacing:8) { HStack { Button("Save Canvas",action:store.saveCanvas).tourFocus("Save Canvas",store); Button("Load Canvas",action:store.loadCanvas).tourFocus("Save Canvas",store) }; HStack { Button("Import") {store.open()}.tourFocus("Export",store); Button("Export") {store.save()}.tourFocus("Export",store) } }.buttonStyle(.bordered).frame(maxWidth:.infinity)
                HStack{Text("v3.1 · Nithilan Vivek");Link("nithi.land",destination:URL(string:"https://nithi.land")!)}.font(.system(size:9)).foregroundStyle(.tertiary).frame(maxWidth:.infinity)
            }.padding(18).frame(width:252).background(panel)
            VStack(spacing:0) {
                HStack {
                    VStack(alignment:.leading,spacing:4) { Text(store.engine.name).font(.system(size:22,weight:.semibold,design:.rounded)); Text("CONWAY’S GAME OF LIFE").font(.system(size:9,weight:.medium)).tracking(2).foregroundStyle(.secondary) }
                    Spacer()
                    Button("Back",action:store.back).disabled(store.engine.generation==0).tourFocus("Undo",store)
                    Button("Redo",action:store.redo).disabled(store.engine.redos.isEmpty).tourFocus("Undo",store)
                    Button("Undo",action:store.undo).help("Undo (⌘Z)").disabled(store.engine.history.isEmpty).tourFocus("Undo",store)
                    Button("Reset Gen 0",action:store.reset).help("Reset Gen 0").disabled(store.engine.seed == nil).tourFocus("Undo",store)
                    Button("Clear",action:store.clear).tourFocus("Undo",store)
                    Button("Help",action:store.startTour).tourFocus("Help",store)
                }.padding(22)
                HStack(spacing:22) {
                    stat("GENERATION",store.engine.generation.formatted())
                    stat("Live cells",store.engine.population.formatted())
                    stat("Canvas",store.engine.borders ? "\(store.engine.cols) × \(store.engine.rows)":"Infinite")
                    Button("Specify Chart Size"){store.width=String(store.engine.cols);store.height=String(store.engine.rows);store.error="";store.sheet="borders"}.font(.system(size:11)).tourFocus("Specify Chart Size",store)
                    Spacer()
                    HStack(spacing:6) { Circle().fill(store.running ? mint : Color.gray).frame(width:6,height:6); Text(store.running ? "Running" : "Paused").font(.system(size:11)).foregroundStyle(.secondary) }
                }.padding(.horizontal,22).padding(.bottom,18)
                PopulationGraph(values:store.engine.populationSeries,palette:store.palette).tourFocus("Population Graph",store).padding(.horizontal,16).padding(.bottom,12)
                CanvasView(store:store).tourFocus("Canvas",store).clipShape(RoundedRectangle(cornerRadius:16)).overlay(alignment:.topLeading) {
                    Text(store.pan ? "Drag to explore" : "Drag to \(store.tool.lowercased()) · Scroll to zoom").font(.system(size:10)).foregroundStyle(.secondary).padding(10).background(.ultraThinMaterial,in:Capsule()).padding(14).allowsHitTesting(false)
                }.padding(.horizontal,16)
                HStack(spacing:10) {
                    Picker("Tool",selection:$store.tool) { Text("Paint").tag("Paint"); Text("Erase").tag("Erase") }.labelsHidden().pickerStyle(.segmented).frame(width:136).help("B: Paint · E: Erase").tourFocus("Tools",store)
                    Button("Pan") {store.pan.toggle()}.buttonStyle(.plain).padding(.horizontal,14).padding(.vertical,7).background(store.pan ? mint : Color.clear,in:RoundedRectangle(cornerRadius:8)).foregroundStyle(store.pan ? ink : mint).overlay(RoundedRectangle(cornerRadius:8).stroke(mint,lineWidth:1)).help("Toggle Pan (H)").tourFocus("Tools",store)
                    Toggle("Grid",isOn:$store.grid).toggleStyle(.checkbox).font(.system(size:11))
                    Button("Unselect",action:store.unselect).disabled(store.engine.selection.isEmpty).tourFocus("Unselect",store)
                    Spacer()
                    Button { store.canvas?.zoom(1/1.2) } label: { Image(systemName:"minus") }
                    Text(store.zoomLabel).font(.system(size:10,design:.monospaced)).frame(width:40)
                    Button { store.canvas?.zoom(1.2) } label: { Image(systemName:"plus") }
                    Button("Fit") { store.canvas?.fit(living:true) }.help("Fit live cells (F)").tourFocus("Fit",store)

                }.padding(16)
                HStack(spacing:14) {
                    Button(action:store.toggle) { Label(store.running ? "Stop" : "Start",systemImage:store.running ? "pause.fill" : "play.fill").frame(width:84).padding(.vertical,10).padding(.horizontal,10).background(mint,in:RoundedRectangle(cornerRadius:12)).foregroundStyle(ink) }.buttonStyle(.plain).tourFocus("Start",store)
                    Button("Step",action:store.step).controlSize(.large).help("Step (.)").tourFocus("Start",store)
                    VStack(alignment:.leading,spacing:4) {
                        HStack { Text("Duration (seconds)"); Spacer(); Text(String(format:"%.2f",1/store.engine.speed)).monospacedDigit() }.font(.system(size:10)).foregroundStyle(.secondary)
                        Slider(value:Binding(get:{ 1/store.engine.speed },set:{ store.engine.speed=1/$0 }),in:0.1...10,step:0.01).tint(mint).onChange(of:store.engine.speed) { if store.running { store.startTimer() } }
                    }.frame(width:170)
                    Spacer()
                    Toggle("Wrap edges",isOn:$store.engine.wrap).toggleStyle(.switch).controlSize(.small).font(.system(size:11)).help("Connect opposite edges of the canvas").disabled(!store.engine.borders)
                }.padding(.horizontal,22).padding(.vertical,16).background(panel)
                Text(store.message).font(.system(size:11)).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,22).padding(.vertical,12).lineLimit(2)
            }
        }.background(ink).foregroundStyle(Color(nsColor(store.palette.text))).preferredColorScheme(store.theme=="Dark" ? .dark:.light).tint(mint).accentColor(mint).frame(minWidth:1040,minHeight:800)
        .overlayPreferenceValue(TourAnchors.self){anchors in
            GeometryReader{proxy in
                if let area=store.tourArea {
                    Path{path in
                        path.addRect(CGRect(origin:.zero,size:proxy.size))
                        for anchor in anchors[area] ?? [] {path.addRoundedRect(in:proxy[anchor].insetBy(dx:-4,dy:-4),cornerSize:CGSize(width:9,height:9))}
                    }.fill(Color.black.opacity(0.6),style:FillStyle(eoFill:true)).allowsHitTesting(false)
                }
            }.allowsHitTesting(false)
        }
        .sheet(isPresented:Binding(get:{store.sheet != nil},set:{if !$0{store.sheet=nil}})){PopupView(store:store).interactiveDismissDisabled()}
        .onAppear{AppDelegate.store=store;DispatchQueue.main.asyncAfter(deadline:.now()+0.5){store.firstTour()}}
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)) { _ in store.persist() }
    }
    func stat(_ label:String,_ value:String) -> some View { VStack(alignment:.leading,spacing:5) { Text(label).font(.system(size:9,weight:.medium)).tracking(1.3).foregroundStyle(.secondary); Text(value).font(.system(size:18,weight:.medium,design:.monospaced)) } }
}
struct PopulationGraph:View {
    var values:[Int];var palette:Palette
    var body:some View {
        VStack(alignment:.leading,spacing:8){
            Text("Live cells over time").font(.system(size:10,weight:.medium)).foregroundStyle(Color(nsColor(palette.muted)))
            Canvas { context,size in
                let samples=values.isEmpty ? [0]:values
                let ceiling=max(1,Double(samples.max() ?? 0)*1.12)
                func point(_ index:Int)->CGPoint {CGPoint(x:3+CGFloat(index)/CGFloat(max(1,samples.count-1))*max(0,size.width-6),y:3+(1-Double(samples[index])/ceiling)*max(0,size.height-6))}
                var line=Path();line.move(to:point(0));for i in samples.indices.dropFirst(){line.addLine(to:point(i))}
                context.stroke(line,with:.color(Color(nsColor(palette.alive))),style:StrokeStyle(lineWidth:2,lineCap:.round,lineJoin:.round))
                let last=point(samples.count-1);context.fill(Path(ellipseIn:CGRect(x:last.x-3,y:last.y-3,width:6,height:6)),with:.color(Color(nsColor(palette.alive))))
            }.frame(height:44)
        }.padding(12).background(Color(nsColor(palette.panel)),in:RoundedRectangle(cornerRadius:12))
        .accessibilityElement(children:.ignore).accessibilityLabel("Live cells over time").accessibilityValue("\(values.last ?? 0) live cells; \(values.count) recorded generations")
        .help("Live-cell trend over the latest 2,048 generations. Edits update the current point; Back and Undo restore earlier history.")
    }
}
struct PatternPreview: View {
    var pattern: LifePattern
    var color:Color
    var body: some View { Canvas { context,size in
        let w = pattern.rows.map(\.count).max() ?? 1; let s = min(size.width/CGFloat(w),size.height/CGFloat(pattern.rows.count))
        for (y,row) in pattern.rows.enumerated() { for (x,c) in row.enumerated() where c == "O" { let r = CGRect(x:(size.width-CGFloat(w)*s)/2+CGFloat(x)*s,y:(size.height-CGFloat(pattern.rows.count)*s)/2+CGFloat(y)*s,width:max(1,s-0.8),height:max(1,s-0.8)); context.fill(Path(roundedRect:r,cornerRadius:0.8),with:.color(color)) } }
    }.accessibilityHidden(true) }
}
@main struct LifeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var store = LifeStore()
    var body: some Scene {
        WindowGroup(Bundle.main.object(forInfoDictionaryKey:"LifeQATitle") as? String ?? "Conway's Game Of Life Lab v3.0") { RootView(store:store) }.defaultSize(width:1220,height:800)
            .commands {
                CommandGroup(replacing:.newItem) { Button("Import") {store.open()}.tourFocus("Export",store); Button("Export") {store.save()}.tourFocus("Export",store); Button("Load Canvas",action:store.loadCanvas).tourFocus("Save Canvas",store).keyboardShortcut("o"); Button("Save Canvas",action:store.saveCanvas).tourFocus("Save Canvas",store).keyboardShortcut("s") }
                CommandGroup(replacing:.undoRedo) { Button("Undo",action:store.undo).keyboardShortcut("z").disabled(store.engine.history.isEmpty && store.textEditor()==nil); Button("Redo",action:store.redo).keyboardShortcut("y").disabled(store.engine.redos.isEmpty && store.textEditor()==nil);Button("Copy Selection",action:store.copySelection).keyboardShortcut("c");Button("Paste Selection",action:store.pasteSelection).keyboardShortcut("v") }
                CommandMenu("Simulation") { Button("Start / Stop",action:store.toggle); Button("Step",action:store.step).keyboardShortcut(".",modifiers:[]); Button("Reset Gen 0",action:store.reset).keyboardShortcut("r"); Button("Generate",action:store.random); Button("Fit Live Cells") { store.canvas?.fit(living:true) }.keyboardShortcut("f",modifiers:[]) }
            }
    }
}

@MainActor final class CloseDelegate:NSObject,NSWindowDelegate {unowned let store:LifeStore;var allow=false;init(store:LifeStore){self.store=store};func windowShouldClose(_ sender:NSWindow)->Bool{if allow{return true};store.requestClose{self.allow=true;sender.close()};return false}}
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate {static weak var store:LifeStore?;func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply{guard let store=Self.store,store.dirty else{return .terminateNow};store.quitPending=true;store.requestClose{store.quitPending=false;sender.reply(toApplicationShouldTerminate:true)};return .terminateLater}}
struct PopupView:View {
 @ObservedObject var store:LifeStore
 var panel:Color{Color(nsColor(store.palette.panel))}
 var mint:Color{Color(nsColor(store.palette.alive))}
 var body:some View {VStack(alignment:.leading,spacing:18){
  switch store.sheet {
  case "tour":if !store.tour.isEmpty{let step=store.tour[store.tourIndex];Text("GUIDED TOUR · \(store.tourIndex+1) / \(store.tour.count)").font(.caption).foregroundStyle(.secondary);Text(step.title).font(.title2.bold());Text(step.text.replacingOccurrences(of:"{MOD}",with:"Cmd")).lineSpacing(5);HStack{Button("Skip"){store.finishTour()};Spacer();Button("Back"){store.tourIndex-=1}.disabled(store.tourIndex==0);Button(store.tourIndex==store.tour.count-1 ? "Finish":"Next"){if store.tourIndex==store.tour.count-1{store.finishTour()}else{store.tourIndex+=1}}.keyboardShortcut(.defaultAction)}}
  case "save","pattern":Text(store.sheet=="save" ? "Save Canvas":"Save to Pattern Library").font(.title2.bold());TextField("Name",text:$store.entry).textFieldStyle(.plain).padding(8).background(Color(nsColor(store.palette.background)),in:RoundedRectangle(cornerRadius:7)).overlay(RoundedRectangle(cornerRadius:7).stroke(Color(nsColor(store.palette.muted)).opacity(0.5)));HStack{Button("Cancel"){store.afterSave=nil;store.sheet=nil};Spacer();Button("Save"){if store.sheet=="save"{store.writeCanvas()}else{store.storePattern()}}.keyboardShortcut(.defaultAction)}
  case "overwrite":Text("Save changes to \(store.engine.name)?").font(.title2.bold());Text("Overwrite the saved canvas or give this version a new name.");HStack{Button("Cancel"){store.afterSave=nil;store.sheet=nil};Button("Save as New Canvas"){store.sheet="save"};Button("Save to Same Canvas"){store.writeCanvas(true)}}
  case "load":Text("Load Canvas").font(.title2.bold());if store.savedFiles.isEmpty{Text("No saved canvases yet.")}else{ScrollView{VStack(alignment:.leading){ForEach(store.savedFiles,id:\.path){url in Button(url.lastPathComponent.replacingOccurrences(of:".life.json",with:"")){if store.dirty{store.closeCompletion={store.loadFile(url)};store.sheet="replace"}else{store.loadFile(url)}}.buttonStyle(.bordered)}}}.frame(maxHeight:280)};Button("Cancel"){store.sheet=nil}
  case "close","replace":Text("Save your canvas changes?").font(.title2.bold());Text("Your current canvas has unsaved changes.");HStack{Button("Cancel"){store.sheet=nil;store.closeCompletion=nil;if store.quitPending{store.quitPending=false;NSApplication.shared.reply(toApplicationShouldTerminate:false)}};Button("Discard"){store.sheet=nil;store.closeCompletion?();store.closeCompletion=nil};Button("Save"){store.afterSave=store.closeCompletion;store.closeCompletion=nil;store.saveCanvas()}.keyboardShortcut(.defaultAction)}
  case "rules":Text("Edit Rules").font(.title2.bold());input("Survival minimum",$store.low);input("Survival maximum",$store.high);input("Birth count",$store.birth);Text("Neighbor counts are 0–8. Birth at zero requires a finite canvas.").font(.caption);Button("Reset to Classic Conway"){store.low="2";store.high="3";store.birth="3"};HStack{Button("Cancel"){store.sheet=nil};Spacer();Button("Apply"){guard let l=Int(store.low),let h=Int(store.high),let b=Int(store.birth),(0...8).contains(l),(l...8).contains(h),(0...8).contains(b),store.engine.borders || b != 0 else{store.error="Use counts 0–8 with minimum ≤ maximum. Birth at 0 needs a finite canvas.";return};store.pause();store.engine.configureRules(l,h,b);store.persist();store.sheet=nil}}
  case "borders":Text("Specify Chart Size").font(.title2.bold());input("Width (columns)",$store.width);input("Height (rows)",$store.height);Text("Choose 5–512. Cells outside the new borders are removed; Undo restores them.").font(.caption);HStack{Button("Cancel"){store.sheet=nil};Button("Infinite"){if store.engine.birthCount==0{store.error="Reset birth count above zero before choosing Infinite.";return};store.pause();store.engine.configureBorders(false,store.engine.cols,store.engine.rows);store.persist();store.canvas?.fit(living:true);store.sheet=nil};Spacer();Button("Apply"){guard let w=Int(store.width),let h=Int(store.height),(5...512).contains(w),(5...512).contains(h)else{store.error="Width and height must be 5–512.";return};store.pause();store.engine.configureBorders(true,w,h);store.persist();store.canvas?.fit(living:true);store.sheet=nil}}
  case "export":Text("Canvas is too large").font(.title2.bold());Text("Portable files support up to 100 × 100. Please choose a smaller canvas or select a region up to 100 × 100. Save Canvas keeps the entire infinite canvas locally.");HStack{Button("Close"){store.sheet=nil};Button("Export Selected Region"){store.exportRegion()}.disabled(store.engine.selection.isEmpty)}
  case "error":Text("Could not complete action").font(.title2.bold());Button("Close"){store.sheet=nil}
  default:EmptyView()
  }
  if !store.error.isEmpty{Text(store.error).foregroundStyle(.red).font(.caption)}
 }.padding(28).frame(width:540).background(panel).foregroundStyle(Color(nsColor(store.palette.text))).preferredColorScheme(store.theme=="Dark" ? .dark:.light).onDisappear{store.error=""}}
 func input(_ label:String,_ binding:Binding<String>)->some View{HStack{Text(label);Spacer();TextField(label,text:binding).textFieldStyle(.plain).padding(8).frame(width:90).background(Color(nsColor(store.palette.background)),in:RoundedRectangle(cornerRadius:7)).overlay(RoundedRectangle(cornerRadius:7).stroke(Color(nsColor(store.palette.muted)).opacity(0.5)))}}
}
