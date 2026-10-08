using System.IO;
using System.Diagnostics;
using System.Text.Json;
using System.Windows.Media.Imaging;

using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;
namespace Nithi.Life;
public class LifeApplication : Application {
}
public class LifeWindow : Window {
    public readonly LifeEngine Engine=new();
    public readonly BoardCanvas Board;
    readonly PopulationGraph populationGraph;
    readonly Grid mainRoot;
    public string Tool="Paint";
    public bool ShowGrid=true,Running,Pan;
    readonly DispatcherTimer timer=new();
    readonly TextBlock title,gen,pop,status,tempo,zoom,activity,dimensions;
    readonly Button play,undo,restart,redo;
    readonly CheckBox wrap;
    Button unselect=null!,savePattern=null!;TextBlock rulesText=null!;StackPanel seeds=null!;ComboBox themePicker=null!;
    public string Theme="Dark";public string[]? Pending;public string PendingName="";
    string? currentFile;string savedFingerprint="";bool allowClose,closePromptPending;
    readonly List<UserPattern> userPatterns=[];
    readonly string baseDir=AppPaths.Data;
    readonly string sharedDir=AppPaths.Library;
    int tourIndex;List<TourStep> tour=[];bool tourSeen;
    readonly Slider speed;
    readonly ToggleButton panButton;
    readonly TextBox density=new(){Text="25",Width=64,Height=32,Padding=new Thickness(8,4,8,4),VerticalAlignment=VerticalAlignment.Center,VerticalContentAlignment=VerticalAlignment.Center,TextAlignment=TextAlignment.Center,Margin=new Thickness(10,0,0,0)};
    readonly string autosave=Path.Combine(AppPaths.Data,"canvas.life.json");
    public static readonly SolidColorBrush Ink=Brush("#091111"),Panel=Brush("#121A1A"),Mint=Brush("#73E8B0"),Text=Brush("#E3EDE8"),Muted=Brush("#8C9F98");
    public static SolidColorBrush Brush(string hex)=>new((Color)ColorConverter.ConvertFromString(hex));
    public LifeWindow(){
        Title="Conway’s Game of Life Lab";
        WindowStyle=WindowStyle.SingleBorderWindow;ResizeMode=ResizeMode.CanResize;ShowInTaskbar=true;
        var workArea=SystemParameters.WorkArea;
        Width=Math.Min(1380,workArea.Width);Height=Math.Min(980,workArea.Height);
        MinWidth=Math.Min(1160,Width);MinHeight=Math.Min(700,Height);
        Left=workArea.Left+(workArea.Width-Width)/2;Top=workArea.Top+(workArea.Height-Height)/2;
        WindowStartupLocation=WindowStartupLocation.Manual;
        Background=Ink;Foreground=Text;FontFamily=new FontFamily("Segoe UI");FontSize=12;
        Engine.LoadPattern(Catalog.All[1]);Engine.Name="Default";Engine.History.Clear();try{if(File.Exists(autosave))Engine.Load(File.ReadAllText(autosave));}catch{}
        if(!Directory.Exists(sharedDir))Directory.CreateDirectory(sharedDir);try{var preferences=JsonDocument.Parse(File.ReadAllText(System.IO.Path.Combine(sharedDir,"preferences.json")));if(preferences.RootElement.TryGetProperty("theme",out var t))Theme=t.GetString()??"Dark";if(preferences.RootElement.TryGetProperty("tour_seen",out var seen))tourSeen=seen.GetBoolean();}catch{};ApplyTheme();
        try{userPatterns.AddRange(JsonSerializer.Deserialize<List<UserPattern>>(File.ReadAllText(System.IO.Path.Combine(baseDir,"patterns.json")))??[]);}catch{};
        foreach(var file in Directory.GetFiles(sharedDir,"*.pattern.json")){try{var d=JsonDocument.Parse(File.ReadAllText(file));var name=d.RootElement.GetProperty("name").GetString()??System.IO.Path.GetFileNameWithoutExtension(file);if(userPatterns.Any(p=>p.Name==name))continue;var rows=d.RootElement.GetProperty("grid").EnumerateArray().Select(row=>string.Concat(row.EnumerateArray().Select(v=>v.GetInt32()==1?'O':'.'))).ToArray();userPatterns.Add(new(name,rows));}catch{}}
        try{using var stream=AppResources.Open("tour.json");tour=JsonSerializer.Deserialize<List<TourStep>>(stream,new JsonSerializerOptions{PropertyNameCaseInsensitive=true})??[];}catch{};
        savedFingerprint=Engine.Save();try{var session=JsonDocument.Parse(File.ReadAllText(System.IO.Path.Combine(baseDir,"session.json")));savedFingerprint=session.RootElement.GetProperty("saved").GetString()??savedFingerprint;currentFile=session.RootElement.GetProperty("file").GetString();if(string.IsNullOrEmpty(currentFile))currentFile=null;}catch{}
        Resources[typeof(Button)]=ButtonStyle();Resources[typeof(TextBox)]=TextBoxStyle();Resources[typeof(ToggleButton)]=PanStyle();
        Resources["LifePanel"]=Panel;Resources["LifeText"]=Text;Resources["LifeMuted"]=Muted;Resources["LifeMint"]=Mint;Resources["LifeInk"]=Ink;
        Resources[typeof(ComboBox)]=ThemeComboStyle();Resources[typeof(ComboBoxItem)]=ThemeComboItemStyle();
        var root=mainRoot=new Grid();root.ColumnDefinitions.Add(new(){Width=new GridLength(290)});root.ColumnDefinitions.Add(new(){Width=new GridLength(1,GridUnitType.Star)});Content=new AdornerDecorator{Child=root};
        var sidebar=new DockPanel{Background=Panel,LastChildFill=true,Margin=new Thickness(0)};root.Children.Add(sidebar);
        var brand=new StackPanel{Margin=new Thickness(20,24,20,20)};var brandRow=new DockPanel();var icon=new Image{Source=LoadAppIcon(),Width=44,Height=44,Margin=new Thickness(0,0,12,0),UseLayoutRounding=true,SnapsToDevicePixels=true};RenderOptions.SetBitmapScalingMode(icon,BitmapScalingMode.HighQuality);Icon=icon.Source;DockPanel.SetDock(icon,Dock.Left);brandRow.Children.Add(icon);var brandName=new StackPanel();brandName.Children.Add(Label("Conway’s Game of Life Lab",14,true));brandName.Children.Add(Label("v3.2 · Pre-testing",10,false,Muted,new Thickness(0,4,0,0)));brandRow.Children.Add(brandName);brand.Children.Add(brandRow);brand.Children.Add(Label("PATTERN LIBRARY",10,true,Muted,new Thickness(0,26,0,0)));DockPanel.SetDock(brand,Dock.Top);sidebar.Children.Add(brand);
        var bottom=new StackPanel{Margin=new Thickness(18)};var densityRow=new StackPanel{Orientation=Orientation.Horizontal,Margin=new Thickness(0,0,0,8)};var densityLabel=Label("Random %",11,false,Muted);densityLabel.VerticalAlignment=VerticalAlignment.Center;densityRow.Children.Add(densityLabel);densityRow.Children.Add(density);bottom.Children.Add(densityRow);bottom.Children.Add(new TextBlock{Text="Fills the specified amount of the grid randomly",TextWrapping=TextWrapping.Wrap,FontSize=11,Foreground=Muted,Margin=new Thickness(0,0,0,10)});var random=Btn("Generate",()=>{Pause();Generate();Update();Persist();});bottom.Children.Add(random);
        var rules=new Border{Background=Ink,CornerRadius=new CornerRadius(12),Padding=new Thickness(14),Margin=new Thickness(0,16,0,16)};var rulesStack=new StackPanel();rulesStack.Children.Add(Label("Rules",10,true,Mint));rulesStack.Children.Add(rulesText=new TextBlock{Text="Three neighbors bring a cell to life. Two or three keep it alive. Everything else fades.",TextWrapping=TextWrapping.Wrap,Foreground=Muted,FontSize=11,LineHeight=19,Margin=new Thickness(0,8,0,0)});rulesStack.Children.Add(Btn("Edit Rules",EditRules));rules.Child=rulesStack;bottom.Children.Add(rules);
        var files=new UniformGrid{Columns=2};files.Children.Add(Btn("Save Canvas",()=>Save(true)));files.Children.Add(Btn("Load Canvas",()=>Open(true)));files.Children.Add(Btn("Export",()=>Save()));files.Children.Add(Btn("Import",()=>Open()));bottom.Children.Add(files);var themeRow=new DockPanel{Margin=new Thickness(0,12,0,12)};themeRow.Children.Add(Label("Theme",11,false,Muted));themePicker=new ComboBox{ItemsSource=new[]{"Dark","Light","Sepia"},SelectedItem=Theme,Background=Panel,Foreground=Text,Padding=new Thickness(8,5,8,5),Margin=new Thickness(12,0,0,0)};themePicker.SelectionChanged+=(_,_)=>{Theme=themePicker.SelectedItem?.ToString()??"Dark";ApplyTheme();SavePreferences();Board.InvalidateVisual();populationGraph?.InvalidateVisual();};RegisterTour(themePicker,"Theme");themeRow.Children.Add(themePicker);bottom.Children.Add(themeRow);bottom.Children.Add(Btn("Help",StartTour));var credit=new TextBlock{FontSize=10,Foreground=Muted,Margin=new Thickness(0,14,0,0)};credit.Inlines.Add("v3.2 · Nithilan Vivek · ");var link=new System.Windows.Documents.Hyperlink(new System.Windows.Documents.Run("nithi.land")){NavigateUri=new Uri("https://nithi.land"),Foreground=Mint};link.RequestNavigate+=(_,e)=>Process.Start(new ProcessStartInfo(e.Uri.ToString()){UseShellExecute=true});credit.Inlines.Add(link);bottom.Children.Add(credit);DockPanel.SetDock(bottom,Dock.Bottom);sidebar.Children.Add(bottom);
        var library=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Auto,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled};seeds=new StackPanel{Margin=new Thickness(14,0,14,0)};library.Content=seeds;RegisterTour(library,"Pattern Library");sidebar.Children.Add(library);
        foreach(var p in Catalog.All){var b=Btn("",()=>{Pause();Pending=p.Rows;PendingName=p.Name;status.Text="Move the preview and click to place "+p.Name+". Esc cancels.";Update();});b.ToolTip=p.Detail;b.HorizontalContentAlignment=HorizontalAlignment.Stretch;b.Margin=new Thickness(0,0,0,6);var row=new DockPanel();var preview=new SeedPreview(p){Width=42,Height=38,Margin=new Thickness(0,0,12,0)};DockPanel.SetDock(preview,Dock.Left);row.Children.Add(preview);var text=new StackPanel{VerticalAlignment=VerticalAlignment.Center};text.Children.Add(Label(p.Name,12,true));text.Children.Add(Label(p.Category,10,false,Muted,new Thickness(0,4,0,0)));row.Children.Add(text);b.Content=row;seeds.Children.Add(b);}
        foreach(var p in userPatterns)AddUserPattern(p);savePattern=Btn("Save to Pattern Library",SavePattern);savePattern.Margin=new Thickness(0,8,0,8);bottom.Children.Insert(0,savePattern);
        var main=new Grid();Grid.SetColumn(main,1);root.Children.Add(main);foreach(var height in new[]{88d,64d,88d,-1d,64d,84d,48d})main.RowDefinitions.Add(new(){Height=height<0?new GridLength(1,GridUnitType.Star):new GridLength(height)});
        var header=new DockPanel{Margin=new Thickness(22,20,22,14)};Add(main,header,0);var actions=new StackPanel{Orientation=Orientation.Horizontal};DockPanel.SetDock(actions,Dock.Right);header.Children.Add(actions);undo=Btn("Undo",()=>{Pause();UndoEdit();Update();Persist();});undo.ToolTip="Undo (Ctrl+Z)";actions.Children.Add(undo);redo=Btn("Redo",()=>{Pause();Engine.Redo();Update();Persist();});actions.Children.Add(redo);actions.Children.Add(Btn("Back",()=>{Pause();if(Engine.Generation>0){Engine.Back();Update();Persist();}}));restart=Btn("Reset Gen 0",()=>{Pause();Engine.Restart();Update();Persist();});restart.ToolTip="Reset Gen 0";actions.Children.Add(restart);actions.Children.Add(Btn("Help",StartTour));actions.Children.Add(Btn("Clear",()=>{Pause();Engine.Clear();status.Text="Canvas cleared.";Update();Persist();}));var heading=new StackPanel();title=Label(Engine.Name,23,true);heading.Children.Add(title);heading.Children.Add(Label("CONWAY’S GAME OF LIFE",10,false,Muted,new Thickness(0,6,0,0)));header.Children.Add(heading);
        var stats=new DockPanel{Margin=new Thickness(22,0,22,18)};Add(main,stats,1);activity=Label("●  Paused",11,false,Muted);DockPanel.SetDock(activity,Dock.Right);stats.Children.Add(activity);var sizeAction=Btn("Specify Chart Size",EditBorders);DockPanel.SetDock(sizeAction,Dock.Right);stats.Children.Add(sizeAction);var statRow=new StackPanel{Orientation=Orientation.Horizontal};stats.Children.Add(statRow);gen=Stat(statRow,"GENERATION");pop=Stat(statRow,"Live cells");dimensions=Stat(statRow,"Canvas");dimensions.Text=$"{Engine.Cols} × {Engine.Rows}";
        populationGraph=new PopulationGraph(Engine){Margin=new Thickness(16,0,16,12)};RegisterTour(populationGraph,"Population Graph");Add(main,populationGraph,2);
        Board=new BoardCanvas(this){Margin=new Thickness(16,0,16,0)};RegisterTour(Board,"Canvas");Add(main,Board,3);
        var tools=new DockPanel{Margin=new Thickness(16,10,16,10)};Add(main,tools,4);var zoomTools=new StackPanel{Orientation=Orientation.Horizontal};DockPanel.SetDock(zoomTools,Dock.Right);tools.Children.Add(zoomTools);zoomTools.Children.Add(Btn("−",()=>Board.Zoom(1/1.2)));zoom=Label("100%",10,false,Muted);zoom.Width=48;zoom.VerticalAlignment=VerticalAlignment.Center;zoom.TextAlignment=TextAlignment.Center;zoomTools.Children.Add(zoom);zoomTools.Children.Add(Btn("+",()=>Board.Zoom(1.2)));zoomTools.Children.Add(Btn("Fit",()=>Board.Fit(true)));var editTools=new StackPanel{Orientation=Orientation.Horizontal};tools.Children.Add(editTools);foreach(var t in new[]{"Paint","Erase"}){var b=new ToggleButton{Content=ToolContent(t),IsChecked=t=="Paint",Padding=new Thickness(12,8,12,8),Margin=new Thickness(3,0,3,0),Background=t=="Paint"?Mint:Panel,Foreground=t=="Paint"?Ink:Text,Style=PanStyle()};b.Click+=(_,_)=>{Tool=t;foreach(var item in editTools.Children.OfType<ToggleButton>().Where(x=>x.Tag as string=="tool")){bool on=(item.Content as StackPanel)?.Tag as string==t;item.IsChecked=on;item.Background=on?Mint:Panel;item.Foreground=on?Ink:Text;}};b.Tag="tool";editTools.Children.Add(b);}var pan=panButton=new ToggleButton{Content="Pan",Padding=new Thickness(14,7,14,7),Margin=new Thickness(8,0,8,0),Background=Ink,Foreground=Mint,BorderBrush=Mint,BorderThickness=new Thickness(1),IsChecked=false};pan.Checked+=(_,_)=>{Pan=true;pan.Background=Mint;pan.Foreground=Ink;};pan.Unchecked+=(_,_)=>{Pan=false;pan.Background=Ink;pan.Foreground=Mint;};pan.Style=PanStyle();editTools.Children.Add(pan);var grid=new CheckBox{Content="Grid",IsChecked=true,Margin=new Thickness(8,10,0,0),Foreground=Text};grid.Click+=(_,_)=>{ShowGrid=grid.IsChecked==true;Board.InvalidateVisual();};editTools.Children.Add(grid);unselect=Btn("Unselect",()=>{Engine.Unselect();Pending=null;Update();SelectionChanged();});editTools.Children.Add(unselect);
        var transport=new DockPanel{Background=Panel,LastChildFill=true};Add(main,transport,5);var transportRow=new DockPanel{Margin=new Thickness(22,15,22,15)};transport.Children.Add(transportRow);wrap=new CheckBox{Content="Wrap edges",IsChecked=Engine.Wrap,VerticalAlignment=VerticalAlignment.Center,Foreground=Text};wrap.Click+=(_,_)=>{Engine.Wrap=wrap.IsChecked==true;Persist();};DockPanel.SetDock(wrap,Dock.Right);transportRow.Children.Add(wrap);var controlRow=new StackPanel{Orientation=Orientation.Horizontal};transportRow.Children.Add(controlRow);play=Btn("▶  Start",Toggle);play.Background=Mint;play.Foreground=Ink;play.FontWeight=FontWeights.SemiBold;play.Width=106;controlRow.Children.Add(play);controlRow.Children.Add(Btn("Step",()=>{Pause();Engine.Step();Update();Persist();}));var tempoPanel=new StackPanel{Width=178,Margin=new Thickness(14,0,0,0),VerticalAlignment=VerticalAlignment.Center};tempo=Label("Duration (seconds) · 0.50",10,false,Muted);tempoPanel.Children.Add(tempo);speed=new Slider{Minimum=.1,Maximum=10,Value=1/Engine.Speed,TickFrequency=.01,IsSnapToTickEnabled=true,Margin=new Thickness(0,8,0,0)};speed.ValueChanged+=(_,_)=>{Engine.Speed=1/speed.Value;tempo.Text=$"Duration (seconds) · {speed.Value:F2}";timer.Interval=TimeSpan.FromSeconds(1/Engine.Speed);};tempoPanel.Children.Add(speed);controlRow.Children.Add(tempoPanel);
        status=Label("Ready. Draw cells or choose a pattern.  •  Space: invert cells  •  Wheel: zoom",11,false,Muted,new Thickness(22,12,22,0));Add(main,status,6);
        timer.Interval=TimeSpan.FromSeconds(1/Engine.Speed);timer.Tick+=(_,_)=>{if(!Running)return;Engine.Step(true);status.Text=Engine.Equilibrium?"Equilibrium reached":"Running.";Update();Persist();};
        Loaded+=(_,_)=>{Board.Fit(true,true);Board.Focus();};
        bool firstFrame=true;
        ContentRendered+=(_,_)=>{
            if(!firstFrame)return;firstFrame=false;
            if(!tourSeen)Dispatcher.BeginInvoke(DispatcherPriority.ContextIdle,new Action(()=>{
                if(IsVisible&&!allowClose&&!closePromptPending)StartTour();
            }));
        };
        Closing+=(_,e)=>{
            if(allowClose){timer.Stop();Persist();return;}
            if(closePromptPending){e.Cancel=true;return;}
            if(!Dirty){timer.Stop();Persist();return;}
            e.Cancel=true;closePromptPending=true;Pause();
            // Return from Closing before showing dialogs or attempting a second Close.
            Dispatcher.BeginInvoke(new Action(()=>{
                try{if(IsVisible)ConfirmUnsaved(()=>{allowClose=true;Close();});}
                finally{closePromptPending=false;}
            }));
        };
        PreviewKeyDown+=HandleKey;Update();
    }
    public void Update(){title.Text=Engine.Name;dimensions.Text=Engine.Borders?$"{Engine.Cols} × {Engine.Rows}":"Infinite";wrap.IsEnabled=Engine.Borders;rulesText.Text=$"Dead cells are born with {Engine.BirthCount} neighbors. Live cells survive with {Engine.SurvivalMin}–{Engine.SurvivalMax}. Everything else fades.";unselect.IsEnabled=Engine.Selection.Count>0;savePattern.IsEnabled=Engine.Selection.Count>0;gen.Text=Engine.Generation.ToString("N0");pop.Text=Engine.Population.ToString("N0");play.Content=Running?"■  Stop":"▶  Start";activity.Text=Running?"●  Running":"●  Paused";activity.Foreground=Running?Mint:Muted;undo.IsEnabled=Engine.History.Count>0;redo.IsEnabled=Engine.Redos.Count>0;restart.IsEnabled=Engine.Seed!=null;Board.InvalidateVisual();populationGraph.InvalidateVisual();}
    public void SelectionChanged(){status.Text=Engine.Selection.Count>0?$"Selected {Engine.Selection.Count} cells. Enter: alive · Delete/Backspace: dead · Space: invert · Esc: clear selection":$"Cell {Engine.CursorX+1}, {Engine.CursorY+1}. Space: toggle.";}
    public void ZoomChanged(double s){zoom.Text=$"{(int)(s/12*100)}%";}
    public void Pause(){bool wasRunning=Running;timer.Stop();Running=false;if(wasRunning&&status!=null)status.Text=Engine.Equilibrium?"Paused · Equilibrium reached":"Paused.";Persist();if(play!=null)Update();}
    public void Toggle(){if(Running){Pause();return;}Running=true;status.Text="Running.";timer.Start();Update();}
    public void Persist(){try{Directory.CreateDirectory(Path.GetDirectoryName(autosave)!);File.WriteAllText(autosave+".tmp",Engine.Save());File.Move(autosave+".tmp",autosave,true);File.WriteAllText(System.IO.Path.Combine(baseDir,"session.json"),JsonSerializer.Serialize(new{saved=savedFingerprint,file=currentFile}));}catch(Exception e){if(status!=null)status.Text="Could not autosave: "+e.Message;}}
    void UndoEdit(){Engine.Undo();status.Text="Undid the latest change.";}
    string Library{get{if(!Directory.Exists(sharedDir))Directory.CreateDirectory(sharedDir);return sharedDir;}}
    bool Dirty=>!Engine.MatchesSaved(savedFingerprint);
    void Open(bool local=false){Pause();if(local){LoadCanvasDialog();return;}if(Dirty){ConfirmUnsaved(()=>ImportFile());return;}ImportFile();}
    void ImportFile(){var dialog=new OpenFileDialog{Title="Import",Filter="Canvas (*.life.json;*.json)|*.life.json;*.json"};if(dialog.ShowDialog(this)!=true)return;try{if(new FileInfo(dialog.FileName).Length>16_000_000)throw new FormatException("Choose a Life file smaller than 16 MB.");var data=File.ReadAllText(dialog.FileName);using(var doc=JsonDocument.Parse(data)){if(doc.RootElement.GetProperty("rows").GetInt32()>100||doc.RootElement.GetProperty("cols").GetInt32()>100)throw new FormatException("This canvas exceeds 100 × 100. Please import a smaller canvas.");}Engine.Load(data);currentFile=null;savedFingerprint=Engine.Save();wrap.IsChecked=Engine.Wrap;speed.Value=1/Engine.Speed;Board.Fit(true);Update();Persist();status.Text="Opened "+Path.GetFileName(dialog.FileName);}catch(Exception e){ShowError(e.Message);}}
    void Save(bool local=false){Pause();if(local){SaveCanvasDialog();return;}using(var doc=JsonDocument.Parse(Engine.Save())){if(!doc.RootElement.GetProperty("v2_compatible").GetBoolean()){ShowError("This canvas exceeds 100 × 100. Please choose a smaller canvas. Save Canvas keeps the whole canvas locally.");return;}}var dialog=new SaveFileDialog{Title="Export",Filter="Canvas (*.life.json)|*.life.json",FileName=Engine.Name+".life.json"};if(dialog.ShowDialog(this)!=true)return;try{File.WriteAllText(dialog.FileName,Engine.Save());status.Text="Saved "+Path.GetFileName(dialog.FileName);}catch(Exception e){ShowError(e.Message);}}
    void HandleKey(object sender,KeyEventArgs e){if(Keyboard.FocusedElement is TextBox)return;bool ctrl=(Keyboard.Modifiers&(ModifierKeys.Control|ModifierKeys.Windows))!=0;bool shift=(Keyboard.Modifiers&ModifierKeys.Shift)!=0;Action? action=e.Key switch{Key.Space=>()=>Board.EditSelected(2),Key.OemPeriod=>()=>{Pause();Engine.Step();Update();Persist();},Key.F=>()=>Board.Fit(true),Key.B=>()=>Tool="Paint",Key.E=>()=>Tool="Erase",Key.H=>()=>{panButton.IsChecked=!Pan;},Key.Left=>()=>Board.Navigate(-1,0,shift),Key.Right=>()=>Board.Navigate(1,0,shift),Key.Up=>()=>Board.Navigate(0,-1,shift),Key.Down=>()=>Board.Navigate(0,1,shift),Key.Escape=>()=>{if(!e.IsRepeat){Engine.Unselect();Pending=null;Update();}},Key.Return=>()=>Board.EditSelected(1),Key.Delete=>()=>Board.EditSelected(0),Key.Back=>()=>Board.EditSelected(0),Key.Y when ctrl=>()=>{Pause();Engine.Redo();Update();Persist();},Key.C when ctrl=>CopySelection,Key.V when ctrl=>PasteSelection,Key.O when ctrl=>()=>Open(true),Key.S when ctrl=>()=>Save(true),Key.Z when ctrl=>()=>{Pause();UndoEdit();Update();Persist();},Key.R when ctrl=>()=>{Pause();Engine.Restart();Update();Persist();},Key.OemPlus=>()=>Board.Zoom(1.2),Key.OemMinus=>()=>Board.Zoom(1/1.2),_=>null};if(action!=null){action();e.Handled=true;}}
    static BitmapSource? LoadAppIcon(){
        try {
            using var stream=AppResources.Open("AppIcon.ico");
            // ICO frames start at 16px. BitmapFrame.Create chooses that first frame,
            // which blurs when enlarged for the sidebar or a scaled Windows taskbar.
            var decoder=new IconBitmapDecoder(stream,BitmapCreateOptions.PreservePixelFormat,BitmapCacheOption.OnLoad);
            var icon=decoder.Frames.OrderByDescending(frame=>frame.PixelWidth*frame.PixelHeight).First();
            icon.Freeze();
            return icon;
        } catch(Exception error) {
            StartupDiagnostics.Stage("Could not load app icon: "+error);
            return null;
        }
    }
    static void Add(Grid parent,UIElement child,int row){Grid.SetRow(child,row);parent.Children.Add(child);}
    static TextBlock Label(string text,int size,bool bold=false,Brush? brush=null,Thickness? margin=null)=>new(){Text=text,FontSize=size,FontWeight=bold?FontWeights.SemiBold:FontWeights.Normal,Foreground=brush??Text,Margin=margin??new Thickness(0)};
    static TextBlock Stat(Panel parent,string name){var s=new StackPanel{Margin=new Thickness(0,0,30,0)};s.Children.Add(Label(name,9,false,Muted));var value=Label("0",19,false,Text,new Thickness(0,7,0,0));value.FontFamily=new FontFamily("Consolas");s.Children.Add(value);parent.Children.Add(s);return value;}
    Button Btn(string text,Action action){var b=new Button{Content=ToolContent(text),Margin=new Thickness(3,0,3,0)};b.Click+=(_,_)=>action();RegisterTour(b,TourAreaFor(text));return b;}
    static Style PanStyle(){var s=ButtonTemplate(typeof(ToggleButton));s.Setters.Add(new Setter(Control.BackgroundProperty,new System.Windows.Data.Binding{Source=Panel}));s.Setters.Add(new Setter(Control.ForegroundProperty,new System.Windows.Data.Binding{Source=Text}));return s;}
    static Style ButtonStyle(){var s=ButtonTemplate(typeof(Button));s.Setters.Add(new Setter(Control.BackgroundProperty,new System.Windows.Data.Binding{Source=Panel}));s.Setters.Add(new Setter(Control.ForegroundProperty,new System.Windows.Data.Binding{Source=Text}));return s;}
    static Style ButtonTemplate(Type type){var s=new Style(type);s.Setters.Add(new Setter(Control.PaddingProperty,new Thickness(13,9,13,9)));s.Setters.Add(new Setter(Control.FontSizeProperty,12d));s.Setters.Add(new Setter(Control.VerticalContentAlignmentProperty,VerticalAlignment.Center));s.Setters.Add(new Setter(Control.HorizontalContentAlignmentProperty,HorizontalAlignment.Center));s.Setters.Add(new Setter(Control.BorderThicknessProperty,new Thickness(1)));s.Setters.Add(new Setter(Control.BorderBrushProperty,new System.Windows.Data.Binding{Source=Muted}));s.Setters.Add(new Setter(Control.CursorProperty,Cursors.Hand));var border=new FrameworkElementFactory(typeof(Border));border.SetValue(Border.CornerRadiusProperty,new CornerRadius(8));border.SetValue(Border.BackgroundProperty,new TemplateBindingExtension(Control.BackgroundProperty));border.SetValue(Border.BorderBrushProperty,new TemplateBindingExtension(Control.BorderBrushProperty));border.SetValue(Border.BorderThicknessProperty,new TemplateBindingExtension(Control.BorderThicknessProperty));var content=new FrameworkElementFactory(typeof(ContentPresenter));content.SetValue(FrameworkElement.MarginProperty,new TemplateBindingExtension(Control.PaddingProperty));content.SetValue(FrameworkElement.HorizontalAlignmentProperty,new TemplateBindingExtension(Control.HorizontalContentAlignmentProperty));content.SetValue(FrameworkElement.VerticalAlignmentProperty,new TemplateBindingExtension(Control.VerticalContentAlignmentProperty));border.AppendChild(content);s.Setters.Add(new Setter(Control.TemplateProperty,new ControlTemplate(type){VisualTree=border}));foreach(var (property,value,opacity) in new[]{(UIElement.IsMouseOverProperty,true,.85),(ButtonBase.IsPressedProperty,true,.65),(UIElement.IsEnabledProperty,false,.35)}){var trigger=new Trigger{Property=property,Value=value};trigger.Setters.Add(new Setter(UIElement.OpacityProperty,opacity));s.Triggers.Add(trigger);}var focus=new Trigger{Property=UIElement.IsKeyboardFocusedProperty,Value=true};focus.Setters.Add(new Setter(Control.BorderBrushProperty,new System.Windows.Data.Binding{Source=Mint}));focus.Setters.Add(new Setter(Control.BorderThicknessProperty,new Thickness(2)));s.Triggers.Add(focus);return s;}
    static Style ThemeComboStyle() => (Style)System.Windows.Markup.XamlReader.Parse("""
        <Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
               xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="ComboBox">
          <Setter Property="Background" Value="{DynamicResource LifePanel}"/>
          <Setter Property="Foreground" Value="{DynamicResource LifeText}"/>
          <Setter Property="BorderBrush" Value="{DynamicResource LifeMuted}"/>
          <Setter Property="BorderThickness" Value="1"/>
          <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
          <Setter Property="Template">
            <Setter.Value>
              <ControlTemplate TargetType="ComboBox">
                <Grid>
                  <ToggleButton Focusable="False" ClickMode="Press"
                     IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                    <ToggleButton.Template>
                      <ControlTemplate TargetType="ToggleButton">
                        <Border Background="{Binding Background, RelativeSource={RelativeSource AncestorType=ComboBox}}"
                                BorderBrush="{Binding BorderBrush, RelativeSource={RelativeSource AncestorType=ComboBox}}"
                                BorderThickness="1" CornerRadius="6">
                          <ContentPresenter Margin="{Binding Padding, RelativeSource={RelativeSource AncestorType=ComboBox}}"/>
                        </Border>
                      </ControlTemplate>
                    </ToggleButton.Template>
                    <DockPanel>
                      <TextBlock DockPanel.Dock="Right" Text="⌄" Margin="12,0,0,0" Foreground="{DynamicResource LifeText}"/>
                      <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                          ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                          ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                          TextElement.Foreground="{DynamicResource LifeText}" VerticalAlignment="Center"/>
                    </DockPanel>
                  </ToggleButton>
                  <Popup x:Name="PART_Popup" Placement="Bottom" AllowsTransparency="True"
                         IsOpen="{TemplateBinding IsDropDownOpen}" Focusable="False" PopupAnimation="None">
                    <Border Background="{DynamicResource LifePanel}" BorderBrush="{DynamicResource LifeMuted}"
                            BorderThickness="1" CornerRadius="6" Padding="4"
                            MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}"
                            MaxHeight="{TemplateBinding MaxDropDownHeight}">
                      <ScrollViewer CanContentScroll="True"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/></ScrollViewer>
                    </Border>
                  </Popup>
                </Grid>
                <ControlTemplate.Triggers>
                  <Trigger Property="IsKeyboardFocusWithin" Value="True">
                    <Setter Property="BorderBrush" Value="{DynamicResource LifeMint}"/>
                  </Trigger>
                </ControlTemplate.Triggers>
              </ControlTemplate>
            </Setter.Value>
          </Setter>
        </Style>
        """);
    static Style ThemeComboItemStyle() => (Style)System.Windows.Markup.XamlReader.Parse("""
        <Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
               xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="ComboBoxItem">
          <Setter Property="Background" Value="{DynamicResource LifePanel}"/>
          <Setter Property="Foreground" Value="{DynamicResource LifeText}"/>
          <Setter Property="Padding" Value="9,6"/>
          <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
          <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ComboBoxItem">
            <Border Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter TextElement.Foreground="{TemplateBinding Foreground}"/>
            </Border>
          </ControlTemplate></Setter.Value></Setter>
          <Style.Triggers>
            <Trigger Property="IsHighlighted" Value="True">
              <Setter Property="Background" Value="{DynamicResource LifeMint}"/>
              <Setter Property="Foreground" Value="{DynamicResource LifeInk}"/>
            </Trigger>
            <Trigger Property="IsSelected" Value="True">
              <Setter Property="Background" Value="{DynamicResource LifeMint}"/>
              <Setter Property="Foreground" Value="{DynamicResource LifeInk}"/>
            </Trigger>
          </Style.Triggers>
        </Style>
        """);
    static Style TextBoxStyle(){var s=new Style(typeof(TextBox));s.Setters.Add(new Setter(Control.BackgroundProperty,new System.Windows.Data.Binding{Source=Ink}));s.Setters.Add(new Setter(Control.ForegroundProperty,new System.Windows.Data.Binding{Source=Text}));s.Setters.Add(new Setter(Control.BorderBrushProperty,new System.Windows.Data.Binding{Source=Muted}));s.Setters.Add(new Setter(Control.BorderThicknessProperty,new Thickness(1)));s.Setters.Add(new Setter(Control.PaddingProperty,new Thickness(9,7,9,7)));s.Setters.Add(new Setter(TextBox.CaretBrushProperty,new System.Windows.Data.Binding{Source=Mint}));s.Setters.Add(new Setter(TextBox.SelectionBrushProperty,new System.Windows.Data.Binding{Source=Mint}));var border=new FrameworkElementFactory(typeof(Border));border.SetValue(Border.CornerRadiusProperty,new CornerRadius(6));border.SetValue(Border.BackgroundProperty,new TemplateBindingExtension(Control.BackgroundProperty));border.SetValue(Border.BorderBrushProperty,new TemplateBindingExtension(Control.BorderBrushProperty));border.SetValue(Border.BorderThicknessProperty,new TemplateBindingExtension(Control.BorderThicknessProperty));var scroller=new FrameworkElementFactory(typeof(ScrollViewer),"PART_ContentHost");scroller.SetValue(FrameworkElement.MarginProperty,new TemplateBindingExtension(Control.PaddingProperty));scroller.SetValue(FrameworkElement.VerticalAlignmentProperty,new TemplateBindingExtension(Control.VerticalContentAlignmentProperty));border.AppendChild(scroller);s.Setters.Add(new Setter(Control.TemplateProperty,new ControlTemplate(typeof(TextBox)){VisualTree=border}));var focus=new Trigger{Property=UIElement.IsKeyboardFocusWithinProperty,Value=true};focus.Setters.Add(new Setter(Control.BorderBrushProperty,new System.Windows.Data.Binding{Source=Mint}));s.Triggers.Add(focus);return s;}
    static StackPanel ToolContent(string name){var row=new StackPanel{Orientation=Orientation.Horizontal,Tag=name};var geometries=new Dictionary<string,string>{{"Paint","M 2,14 L 5,5 L 11,2 L 14,5 L 5,14 Z"},{"Erase","M 2,10 L 8,2 L 14,8 L 8,14 L 5,14 Z M 6,5 L 11,10"},{"Pan","M 8,1 L 8,15 M 1,8 L 15,8 M 5,4 L 8,1 L 11,4 M 4,5 L 1,8 L 4,11 M 12,5 L 15,8 L 12,11 M 5,12 L 8,15 L 11,12"},{"Undo","M 5,2 L 1,6 L 5,10 M 1,6 L 9,6 C 16,6 16,14 9,14"},{"Redo","M 11,2 L 15,6 L 11,10 M 15,6 L 7,6 C 0,6 0,14 7,14"},{"Help","M 4,5 C 4,0 12,0 12,5 C 12,9 8,7 8,11 M 8,14 L 8,15"}};if(geometries.TryGetValue(name,out var data)){var icon=new System.Windows.Shapes.Path{Data=Geometry.Parse(data),StrokeThickness=1.5,Width=16,Height=16,Stretch=Stretch.Uniform,Margin=new Thickness(0,0,7,0)};icon.SetBinding(System.Windows.Shapes.Path.StrokeProperty,new System.Windows.Data.Binding("Foreground"){RelativeSource=new System.Windows.Data.RelativeSource(System.Windows.Data.RelativeSourceMode.FindAncestor,typeof(Control),1)});row.Children.Add(icon);}row.Children.Add(new TextBlock{Text=name,VerticalAlignment=VerticalAlignment.Center});return row;}
    public static SolidColorBrush GridColor=Brush("#73E8B0"),CursorColor=Brush("#8AB4FF"),SelectionColor=Brush("#F5A623"),PreviewColor=Brush("#A2F2CF");
    void ApplyTheme(){string[] c=Theme switch{"Light"=>["#FFFFFF","#F0F0F0","#000000","#000000","#555555","#000000","#0000FF","#FF9F1C","#68D391"],"Sepia"=>["#F5EAD3","#EAD8B8","#5A351D","#4B2D18","#6D4A28","#5A351D","#8A5A2B","#B66A2A","#9D6B36"],_=>["#091111","#121A1A","#73E8B0","#E3EDE8","#8C9F98","#73E8B0","#8AB4FF","#F5A623","#A2F2CF"]};var brushes=new[]{Ink,Panel,Mint,Text,Muted,GridColor,CursorColor,SelectionColor,PreviewColor};for(int i=0;i<c.Length;i++)brushes[i].Color=(Color)ColorConverter.ConvertFromString(c[i]);}
    void SavePreferences(){File.WriteAllText(System.IO.Path.Combine(sharedDir,"preferences.json"),JsonSerializer.Serialize(new{theme=Theme,tour_seen=tourSeen}));}
    Window Popup(string title,out StackPanel body){var w=new Window{Owner=this,Title=title,Width=560,SizeToContent=SizeToContent.Height,MaxHeight=700,WindowStartupLocation=WindowStartupLocation.CenterOwner,ResizeMode=ResizeMode.NoResize,Background=Panel,Foreground=Text,FontFamily=FontFamily,FontSize=13};w.Resources[typeof(Button)]=ButtonStyle();w.Resources[typeof(TextBox)]=TextBoxStyle();body=new StackPanel{Margin=new Thickness(26)};body.Children.Add(Label(title,21,true,Text,new Thickness(0,0,0,18)));w.Content=body;return w;}
    TextBox Entry(StackPanel body,string label,string value){body.Children.Add(Label(label,12,false,Muted,new Thickness(0,5,0,6)));var input=new TextBox{Text=value,Margin=new Thickness(0,0,0,14)};body.Children.Add(input);return input;}
    void Message(StackPanel body,string text)=>body.Children.Add(new TextBlock{Text=text,TextWrapping=TextWrapping.Wrap,Foreground=Muted,LineHeight=21,Margin=new Thickness(0,0,0,16)});
    void ShowError(string text){var w=Popup("Could not complete action",out var body);Message(body,text);body.Children.Add(Btn("Close",w.Close));w.ShowDialog();}
    void ConfirmUnsaved(Action continuation){Pause();var w=Popup("Save your canvas changes?",out var body);Message(body,"Your current canvas has unsaved changes.");var row=new StackPanel{Orientation=Orientation.Horizontal};row.Children.Add(Btn("Cancel",w.Close));row.Children.Add(Btn("Discard",()=>{w.Close();continuation();}));row.Children.Add(Btn("Save",()=>{w.Close();SaveCanvasDialog(continuation);}));body.Children.Add(row);w.ShowDialog();}
    void SaveCanvasDialog(Action? completed=null){Pause();if(currentFile!=null){var w=Popup("Save changes to "+Engine.Name+"?",out var b);Message(b,"Overwrite the saved canvas or save a new copy.");b.Children.Add(Btn("Save to Same Canvas",()=>{if(WriteCanvas(currentFile,Engine.Name)){w.Close();completed?.Invoke();}}));b.Children.Add(Btn("Save as New Canvas",()=>{w.Close();NameCanvas(completed);}));b.Children.Add(Btn("Cancel",w.Close));w.ShowDialog();}else NameCanvas(completed);}
    void NameCanvas(Action? completed){var w=Popup("Save Canvas",out var b);var name=Entry(b,"Name",Engine.Name);var error=Label("",11,false,Muted);b.Children.Add(error);b.Children.Add(Btn("Save",()=>{var n=name.Text.Trim();if(n.Length==0){error.Text="Enter a name.";return;}var safe=string.Concat(n.Select(c=>char.IsLetterOrDigit(c)||" _-".Contains(c)?c:'_'));var path=System.IO.Path.Combine(Library,safe+".life.json");if(File.Exists(path)){error.Text="That name exists. Choose another name or load it to overwrite.";return;}if(WriteCanvas(path,n)){w.Close();completed?.Invoke();}}));b.Children.Add(Btn("Cancel",w.Close));w.ShowDialog();}
    bool WriteCanvas(string path,string name){try{Engine.Name=name;File.WriteAllText(path+".tmp",Engine.Save());File.Move(path+".tmp",path,true);currentFile=path;savedFingerprint=Engine.Save();status.Text="Saved "+name;Update();Persist();return true;}catch(Exception e){ShowError(e.Message);return false;}}
    void LoadCanvasDialog(){Pause();void Choose(){var w=Popup("Load Canvas",out var b);var files=Directory.GetFiles(Library,"*.life.json").OrderBy(p=>p,StringComparer.OrdinalIgnoreCase).ToArray();if(files.Length==0)Message(b,"No saved canvases yet.");var list=new StackPanel();foreach(var file in files){string name=System.IO.Path.GetFileName(file).Replace(".life.json","");list.Children.Add(Btn(name,()=>{try{Engine.Load(File.ReadAllText(file));currentFile=file;savedFingerprint=Engine.Save();Pending=null;speed.Value=1/Engine.Speed;wrap.IsChecked=Engine.Wrap;Update();Board.Fit(true);Persist();w.Close();}catch(Exception e){ShowError(e.Message);}}));}b.Children.Add(new ScrollViewer{Content=list,MaxHeight=350,VerticalScrollBarVisibility=ScrollBarVisibility.Auto});b.Children.Add(Btn("Cancel",w.Close));w.ShowDialog();}if(Dirty)ConfirmUnsaved(Choose);else Choose();}
    void SavePattern(){if(Engine.Selection.Count==0)return;var rows=Engine.CopiedRows();if(rows==null)return;var w=Popup("Save to Pattern Library",out var b);var name=Entry(b,"Pattern name","My pattern");b.Children.Add(Btn("Save",()=>{var n=name.Text.Trim();if(n.Length==0||userPatterns.Any(p=>p.Name==n)){ShowError("Choose a unique, nonempty name.");return;}var p=new UserPattern(n,rows);userPatterns.Add(p);Directory.CreateDirectory(baseDir);File.WriteAllText(System.IO.Path.Combine(baseDir,"patterns.json"),JsonSerializer.Serialize(userPatterns));var safe=string.Concat(n.Select(c=>char.IsLetterOrDigit(c)||" _-".Contains(c)?c:'_'));File.WriteAllText(System.IO.Path.Combine(Library,safe+".pattern.json"),JsonSerializer.Serialize(new{app="Conway's Game of Life Tool",type="pattern",version=1,name=n,rows=rows.Length,cols=rows.Max(r=>r.Length),grid=rows.Select(r=>r.Select(c=>c=='O'?1:0).ToArray()).ToArray()}));AddUserPattern(p);w.Close();}));b.Children.Add(Btn("Cancel",w.Close));w.ShowDialog();}
    void AddUserPattern(UserPattern p){var b=Btn("",()=>{Pause();Pending=p.Rows;PendingName=p.Name;status.Text="Move the preview and click to place "+p.Name;Update();});b.HorizontalContentAlignment=HorizontalAlignment.Stretch;b.Margin=new Thickness(0,0,0,6);var row=new DockPanel();var preview=new SeedPreview(new Pattern(p.Name,"Saved","Place your saved pattern.",p.Rows)){Width=42,Height=38,Margin=new Thickness(0,0,12,0)};DockPanel.SetDock(preview,Dock.Left);row.Children.Add(preview);var text=new StackPanel{VerticalAlignment=VerticalAlignment.Center};text.Children.Add(Label(p.Name,12,true));text.Children.Add(Label("Saved",10,false,Muted,new Thickness(0,4,0,0)));row.Children.Add(text);b.Content=row;seeds.Children.Add(b);}
    void CopySelection(){try{var rows=Engine.CopiedRows();if(rows!=null){Clipboard.SetText("life-pattern:"+JsonSerializer.Serialize(rows));status.Text="Copied selection.";}}catch(Exception e){ShowError(e.Message);}}
    void PasteSelection(){try{var text=Clipboard.GetText();if(!text.StartsWith("life-pattern:"))return;var rows=JsonSerializer.Deserialize<string[]>(text[13..]);if(rows==null||rows.Length==0||rows.Length>512||rows.Any(r=>r.Length>512||r.Any(c=>c!='O'&&c!='.')))return;Pause();Engine.Place(rows,Engine.CursorX,Engine.CursorY,true);Update();Persist();}catch(Exception e){ShowError(e.Message);}}
    public void PlacePending(){if(Pending==null)return;Pause();Engine.Place(Pending,Board.PointerX,Board.PointerY);Pending=null;Update();Persist();}
    void EditBorders(){Pause();var w=Popup("Specify Chart Size",out var b);var width=Entry(b,"Width (columns)",Engine.Cols.ToString());var height=Entry(b,"Height (rows)",Engine.Rows.ToString());Message(b,"Choose 5–512. Outside cells are removed; Undo restores them.");b.Children.Add(Btn("Apply",()=>{try{Engine.ConfigureBorders(true,int.Parse(width.Text),int.Parse(height.Text));Update();Board.Fit(true);Persist();w.Close();}catch(Exception e){ShowError(e.Message);}}));b.Children.Add(Btn("Infinite",()=>{try{Engine.ConfigureBorders(false,Engine.Cols,Engine.Rows);Update();Board.Fit(true);Persist();w.Close();}catch(Exception e){ShowError(e.Message);}}));b.Children.Add(Btn("Cancel",()=>{w.Close();Update();}));w.ShowDialog();}
    void EditRules(){Pause();var w=Popup("Edit Rules",out var b);var low=Entry(b,"Survival minimum",Engine.SurvivalMin.ToString());var high=Entry(b,"Survival maximum",Engine.SurvivalMax.ToString());var birth=Entry(b,"Birth count",Engine.BirthCount.ToString());Message(b,"Neighbor counts are 0–8. Birth at zero requires a finite canvas.");b.Children.Add(Btn("Reset to Classic Conway",()=>{low.Text="2";high.Text="3";birth.Text="3";}));b.Children.Add(Btn("Apply",()=>{try{Engine.ConfigureRules(int.Parse(low.Text),int.Parse(high.Text),int.Parse(birth.Text));Update();Persist();w.Close();}catch(Exception e){ShowError(e.Message);}}));b.Children.Add(Btn("Cancel",w.Close));w.ShowDialog();}
    void Generate(){double d=int.TryParse(density.Text,out var n)?Math.Clamp(n,0,100)/100.0:.25;if(Engine.Borders)Engine.Randomize(d);else{var r=Board.VisibleRegion();Engine.RandomizeRegion(d,r.X,r.Y,r.W,r.H);}}
    readonly Dictionary<FrameworkElement,string> tourTargets=new();
    AdornerLayer? tourLayer;TourSpotlight? tourSpotlight;
    static string TourAreaFor(string name)=>name switch{"Specify Chart Size"=>"Specify Chart Size","Paint" or "Erase" or "Pan"=>"Tools","Fit"=>"Fit","Unselect"=>"Unselect","Save to Pattern Library"=>"Save to Pattern Library","▶  Start" or "Start" or "Step"=>"Start","Undo" or "Redo" or "Back" or "Reset Gen 0" or "Clear"=>"Undo","Generate"=>"Generate","Edit Rules"=>"Edit Rules","Save Canvas" or "Load Canvas"=>"Save Canvas","Import" or "Export"=>"Export","Help"=>"Help",_=>""};
    void RegisterTour(FrameworkElement target,string area){if(area.Length>0)tourTargets[target]=area;}
    void ClearTourHighlight(){if(tourSpotlight!=null)tourLayer?.Remove(tourSpotlight);tourSpotlight=null;tourLayer=null;}
    void HighlightTour(string area){
        ClearTourHighlight();tourLayer=AdornerLayer.GetAdornerLayer(mainRoot);if(tourLayer==null)return;
        var targets=tourTargets.Where(pair=>pair.Value==area&&pair.Key.IsVisible&&pair.Key.IsDescendantOf(mainRoot)).Select(pair=>pair.Key).ToArray();
        tourSpotlight=new TourSpotlight(mainRoot,targets){IsHitTestVisible=false};tourLayer.Add(tourSpotlight);
    }
    void StartTour(){Pause();if(tour.Count==0)return;tourIndex=0;ShowTourStep();}
    void ShowTourStep(){var step=tour[tourIndex];var w=Popup(step.Title,out var b);Message(b,$"GUIDED TOUR · {tourIndex+1} / {tour.Count}");Message(b,step.Text.Replace("{MOD}","Ctrl"));var row=new StackPanel{Orientation=Orientation.Horizontal};row.Children.Add(Btn("Skip",()=>{tourSeen=true;SavePreferences();w.Close();}));if(tourIndex>0)row.Children.Add(Btn("Back",()=>{tourIndex--;w.Close();Dispatcher.BeginInvoke(ShowTourStep);}));row.Children.Add(Btn(tourIndex==tour.Count-1?"Finish":"Next",()=>{w.Close();if(tourIndex==tour.Count-1){tourSeen=true;SavePreferences();}else{tourIndex++;Dispatcher.BeginInvoke(ShowTourStep);}}));b.Children.Add(row);HighlightTour(step.Area);w.Closed+=(_,_)=>ClearTourHighlight();w.ShowDialog();}

}
// Dim the main window while leaving the current step's controls uncovered.
internal sealed class TourSpotlight(FrameworkElement root,FrameworkElement[] targets):Adorner(root) {
    protected override void OnRender(DrawingContext dc){
        var bounds=new Rect(root.RenderSize);Geometry shade=new RectangleGeometry(bounds);var holes=new List<Rect>();
        foreach(var target in targets){
            if(target.ActualWidth<1||target.ActualHeight<1)continue;
            var hole=target.TransformToAncestor(root).TransformBounds(new Rect(target.RenderSize));hole.Intersect(bounds);
            if(hole.IsEmpty)continue;holes.Add(hole);
            shade=Geometry.Combine(shade,new RectangleGeometry(hole,6,6),GeometryCombineMode.Exclude,null);
        }
        dc.DrawGeometry(new SolidColorBrush(Color.FromArgb(153,0,0,0)),null,shade);
        foreach(var hole in holes)dc.DrawRoundedRectangle(null,new Pen(LifeWindow.Mint,2),hole,6,6);
    }
}
public class SeedPreview(Pattern pattern):FrameworkElement {
    protected override void OnRender(DrawingContext dc){double s=Math.Min(ActualWidth/pattern.Rows.Max(r=>r.Length),ActualHeight/pattern.Rows.Length);for(int y=0;y<pattern.Rows.Length;y++)for(int x=0;x<pattern.Rows[y].Length;x++)if(pattern.Rows[y][x]=='O')dc.DrawRoundedRectangle(LifeWindow.Mint,null,new Rect(x*s,(ActualHeight-pattern.Rows.Length*s)/2+y*s,Math.Max(1,s-.8),Math.Max(1,s-.8)),1,1);}
}
public class BoardCanvas:FrameworkElement {
    readonly LifeWindow host;double scale=12;Point origin;Point? last,lastCell;bool dragging,panning,selecting,keyboardCursor=true,cursorCentered;public int PointerX=80,PointerY=50;
    readonly Pen gridPen=new(LifeWindow.GridColor,.5),borderPen=new(LifeWindow.Muted,1);
    public BoardCanvas(LifeWindow h){host=h;ClipToBounds=true;Focusable=true;Cursor=Cursors.Cross;SizeChanged+=(_,e)=>{origin.X+=(e.NewSize.Width-e.PreviousSize.Width)/2;origin.Y+=(e.NewSize.Height-e.PreviousSize.Height)/2;InvalidateVisual();};MouseWheel+=(_,e)=>Zoom(e.Delta>0?1.15:1/1.15,e.GetPosition(this));MouseLeftButtonDown+=Down;MouseMove+=Move;MouseLeftButtonUp+=Up;LostMouseCapture+=(_,_)=>{dragging=false;lastCell=null;};}
    public void Fit(bool living,bool defaultZoom=false){var b=host.Engine;int x0=0,y0=0,x1=b.Cols-1,y1=b.Rows-1;if(living&&b.Population>0){x0=y0=int.MaxValue;x1=y1=int.MinValue;foreach(var p in b.Live){x0=Math.Min(x0,p.X);x1=Math.Max(x1,p.X);y0=Math.Min(y0,p.Y);y1=Math.Max(y1,p.Y);}x0-=8;y0-=8;x1+=8;y1+=8;}scale=defaultZoom?12:Math.Clamp(Math.Min(ActualWidth/(x1-x0+1),ActualHeight/(y1-y0+1)),2,28);origin=new(ActualWidth/2-(x0+x1+1)/2.0*scale,ActualHeight/2-(y0+y1+1)/2.0*scale);if(!cursorCentered&&ActualWidth>0&&ActualHeight>0){b.CursorX=(int)Math.Floor((ActualWidth/2-origin.X)/scale);b.CursorY=(int)Math.Floor((ActualHeight/2-origin.Y)/scale);PointerX=b.CursorX;PointerY=b.CursorY;cursorCentered=true;}host.ZoomChanged(scale);InvalidateVisual();}
    public void Zoom(double factor,Point? at=null){var p=at??new Point(ActualWidth/2,ActualHeight/2);double next=Math.Clamp(scale*factor,2,48),f=next/scale;origin=new(p.X-(p.X-origin.X)*f,p.Y-(p.Y-origin.Y)*f);scale=next;host.ZoomChanged(scale);InvalidateVisual();}
    public (int X,int Y,int W,int H) VisibleRegion()=>((int)Math.Floor(-origin.X/scale),(int)Math.Floor(-origin.Y/scale),Math.Max(1,(int)Math.Ceiling(ActualWidth/scale)),Math.Max(1,(int)Math.Ceiling(ActualHeight/scale)));
    protected override void OnRender(DrawingContext dc){var e=host.Engine;dc.DrawRectangle(LifeWindow.Ink,null,new Rect(0,0,ActualWidth,ActualHeight));var board=new Rect(origin.X,origin.Y,e.Cols*scale,e.Rows*scale);if(e.Borders)dc.DrawRectangle(null,borderPen,board);var r=VisibleRegion();int x0=e.Borders?Math.Max(0,r.X):r.X,y0=e.Borders?Math.Max(0,r.Y):r.Y,x1=e.Borders?Math.Min(e.Cols,r.X+r.W+1):r.X+r.W+1,y1=e.Borders?Math.Min(e.Rows,r.Y+r.H+1):r.Y+r.H+1;if(host.ShowGrid&&scale>=5){for(int x=x0;x<=x1;x++)dc.DrawLine(gridPen,new(origin.X+x*scale,e.Borders?Math.Max(0,board.Top):0),new(origin.X+x*scale,e.Borders?Math.Min(ActualHeight,board.Bottom):ActualHeight));for(int y=y0;y<=y1;y++)dc.DrawLine(gridPen,new(e.Borders?Math.Max(0,board.Left):0,origin.Y+y*scale),new(e.Borders?Math.Min(ActualWidth,board.Right):ActualWidth,origin.Y+y*scale));}double inset=scale>=6?1:0;Rect Square(int x,int y)=>new(origin.X+x*scale+inset,origin.Y+y*scale+inset,scale-inset*2,scale-inset*2);foreach(var p in e.Live){var square=Square(p.X,p.Y);if(square.Right>=0&&square.Left<=ActualWidth&&square.Bottom>=0&&square.Top<=ActualHeight)dc.DrawRectangle(LifeWindow.Mint,null,square);}var selection=new SolidColorBrush(LifeWindow.SelectionColor.Color){Opacity=.3};foreach(var p in e.Selection)dc.DrawRectangle(selection,null,Square(p.X,p.Y));if(host.Pending is string[] rows){int w=rows.Max(r=>r.Length);var preview=new SolidColorBrush(LifeWindow.PreviewColor.Color){Opacity=.65};for(int y=0;y<rows.Length;y++)for(int x=0;x<rows[y].Length;x++)if(rows[y][x]=='O'&&e.Valid(PointerX-w/2+x,PointerY-rows.Length/2+y))dc.DrawRectangle(preview,null,Square(PointerX-w/2+x,PointerY-rows.Length/2+y));dc.DrawRectangle(null,new Pen(LifeWindow.PreviewColor,1),new Rect(origin.X+(PointerX-w/2)*scale,origin.Y+(PointerY-rows.Length/2)*scale,w*scale,rows.Length*scale));}if(keyboardCursor)dc.DrawRectangle(null,new Pen(LifeWindow.CursorColor,2),Square(e.CursorX,e.CursorY));}
    public void EditSelected(int mode){host.Pause();host.Engine.EditSelection(mode);keyboardCursor=true;host.Update();host.SelectionChanged();host.Persist();}
    public void Navigate(int dx,int dy,bool select){var e=host.Engine;e.MoveCursor(dx,dy,select);keyboardCursor=true;double x=origin.X+(e.CursorX+.5)*scale,y=origin.Y+(e.CursorY+.5)*scale;if(x<scale||x>ActualWidth-scale)origin.X+=ActualWidth/2-x;if(y<scale||y>ActualHeight-scale)origin.Y+=ActualHeight/2-y;host.SelectionChanged();InvalidateVisual();}
    void Select(Point p){var e=host.Engine;int x=(int)Math.Floor((p.X-origin.X)/scale),y=(int)Math.Floor((p.Y-origin.Y)/scale);if(!e.Valid(x,y))return;var prev=lastCell??new Point(x,y);int steps=Math.Max(1,(int)Math.Max(Math.Abs(x-prev.X),Math.Abs(y-prev.Y)));for(int i=0;i<=steps;i++)e.Select((int)Math.Round(prev.X+(x-prev.X)*i/steps),(int)Math.Round(prev.Y+(y-prev.Y)*i/steps));lastCell=new Point(x,y);keyboardCursor=true;host.SelectionChanged();InvalidateVisual();}
    void Down(object sender,MouseButtonEventArgs e){Focus();CaptureMouse();dragging=true;panning=host.Pan||(Keyboard.Modifiers&ModifierKeys.Alt)!=0;last=e.GetPosition(this);lastCell=null;if(host.Pending!=null&&!panning){SetPointer(last.Value);host.PlacePending();dragging=false;ReleaseMouseCapture();return;}selecting=(Keyboard.Modifiers&ModifierKeys.Shift)!=0;if(selecting){Select(last.Value);}else if(!panning){host.Engine.Unselect();host.Pause();host.Engine.Checkpoint();Paint(last.Value);}e.Handled=true;}
    void Paint(Point p){var cell=new Point(Math.Floor((p.X-origin.X)/scale),Math.Floor((p.Y-origin.Y)/scale));var prev=lastCell??cell;int steps=Math.Max(1,(int)Math.Max(Math.Abs(cell.X-prev.X),Math.Abs(cell.Y-prev.Y)));for(int i=0;i<=steps;i++)host.Engine.Set((int)Math.Round(prev.X+(cell.X-prev.X)*i/steps),(int)Math.Round(prev.Y+(cell.Y-prev.Y)*i/steps),host.Tool!="Erase");lastCell=cell;host.Update();}
    void SetPointer(Point p){int x=(int)Math.Floor((p.X-origin.X)/scale),y=(int)Math.Floor((p.Y-origin.Y)/scale);if(host.Engine.Valid(x,y)){PointerX=x;PointerY=y;}InvalidateVisual();}
    void Move(object sender,MouseEventArgs e){if(!dragging){SetPointer(e.GetPosition(this));return;}var p=e.GetPosition(this);if(selecting)Select(p);else if(panning&&last.HasValue){origin.X+=p.X-last.Value.X;origin.Y+=p.Y-last.Value.Y;InvalidateVisual();}else Paint(p);last=p;}
    void Up(object sender,MouseButtonEventArgs e){if(!dragging)return;dragging=false;ReleaseMouseCapture();lastCell=null;if(!panning&&!selecting){if(host.Engine.Generation==0)host.Engine.RememberSeed();host.Persist();}}
}

public record UserPattern(string Name,string[] Rows);
public record TourStep(string Title,string Area,string Text);

public sealed class PopulationGraph : FrameworkElement {
    readonly LifeEngine engine;
    public PopulationGraph(LifeEngine engine){this.engine=engine;Focusable=false;ToolTip="Live-cell trend over the latest 2,048 generations.";System.Windows.Automation.AutomationProperties.SetName(this,"Live cells over time");}
    protected override void OnRender(DrawingContext dc){
        base.OnRender(dc);double width=ActualWidth,height=ActualHeight;if(width<30||height<30)return;
        dc.DrawRoundedRectangle(LifeWindow.Panel,null,new Rect(0,0,width,height),12,12);
        var label=new FormattedText("Live cells over time",System.Globalization.CultureInfo.CurrentCulture,FlowDirection.LeftToRight,new Typeface("Segoe UI"),11,LifeWindow.Muted,VisualTreeHelper.GetDpi(this).PixelsPerDip);
        dc.DrawText(label,new Point(12,9));var samples=engine.PopulationSeries;double ceiling=Math.Max(1,samples.Max()*1.12),plotHeight=Math.Max(1,height-39);
        Point At(int i)=>new(15+i/(double)Math.Max(1,samples.Length-1)*Math.Max(1,width-30),31+(1-samples[i]/ceiling)*plotHeight);
        var line=new StreamGeometry();using(var path=line.Open()){path.BeginFigure(At(0),false,false);for(int i=1;i<samples.Length;i++)path.LineTo(At(i),true,false);}line.Freeze();
        var pen=new Pen(LifeWindow.Mint,2){StartLineCap=PenLineCap.Round,EndLineCap=PenLineCap.Round,LineJoin=PenLineJoin.Round};dc.DrawGeometry(null,pen,line);dc.DrawEllipse(LifeWindow.Mint,null,At(samples.Length-1),3,3);
    }
}
