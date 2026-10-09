using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Automation.Peers;
using System.Windows.Automation.Provider;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Nithi.Life;

internal static class Program {
    static string output = "";
    static readonly List<string> checks = [];
    [STAThread]
    static int Main(string[] args) {
        output = Path.GetFullPath(args[0]);
        Directory.CreateDirectory(output);
        var data = Path.Combine(output, "isolated-data");
        var library = Path.Combine(output, "isolated-library");
        Directory.CreateDirectory(data); Directory.CreateDirectory(library);
        Environment.SetEnvironmentVariable("NITHI_LIFE_DATA_DIR", data);
        Environment.SetEnvironmentVariable("NITHI_LIFE_LIBRARY_DIR", library);
        File.WriteAllText(Path.Combine(library, "preferences.json"), "{\"theme\":\"Dark\",\"tour_seen\":false}");
        RenderOptions.ProcessRenderMode = RenderMode.SoftwareOnly;
        var app = new LifeApplication { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        var window = new LifeWindow { Width = 1616, Height = 1039, Left = 0, Top = 0 };
        app.Dispatcher.BeginInvoke(DispatcherPriority.Background, new Action(async () => {
            try { await Check(app, window); app.Shutdown(0); }
            catch (Exception error) { Console.Error.WriteLine(error); app.Shutdown(1); }
        }));
        return app.Run(window);
    }
    static void Require(bool condition, string description) {
        if (!condition) throw new Exception(description);
        checks.Add(description); Console.WriteLine("PASS: " + description);
    }
    static IEnumerable<T> Descendants<T>(DependencyObject parent) where T : DependencyObject {
        for (int i = 0; i < VisualTreeHelper.GetChildrenCount(parent); i++) {
            var child = VisualTreeHelper.GetChild(parent, i);
            if (child is T match) yield return match;
            foreach (var descendant in Descendants<T>(child)) yield return descendant;
        }
    }
    static void Invoke(Window window, string label) {
        var button = Descendants<Button>(window).Single(b => b.Content as string == label ||
            b.Content is FrameworkElement content && (content.Tag as string == label || Descendants<TextBlock>(content).Any(text => text.Text == label)));
        if (!button.IsEnabled) throw new Exception("Disabled button: " + label);
        var peer = new ButtonAutomationPeer(button);
        ((IInvokeProvider)peer.GetPattern(PatternInterface.Invoke)).Invoke();
    }
    static async Task Check(Application app, LifeWindow window) {
        await Task.Delay(1200); // Allow the real first-use modal tour to appear.
        var tour = app.Windows.OfType<Window>().SingleOrDefault(w => w != window && w.IsVisible);
        Require(tour != null, "First-use tour opens in the compiled Windows app");
        Invoke(tour!, "Skip"); await Task.Delay(250);
        Require(app.Windows.OfType<Window>().All(w => w == window || !w.IsVisible), "Tour dismisses without leaving a modal window");
        Require(window.Icon is BitmapSource { PixelWidth: 256, PixelHeight: 256 }, "Window/sidebar use the 256px ICO frame instead of enlarging 16px");
        Require(window.UseLayoutRounding && window.SnapsToDevicePixels, "Windows interface uses pixel-aligned layout");
        var brand = Descendants<Image>(window).Single(image => image.Width == 44);
        Require(RenderOptions.GetBitmapScalingMode(brand) == BitmapScalingMode.HighQuality, "Sidebar icon uses high-quality downsampling");
        Invoke(window, "Step"); await Task.Delay(200);
        Require(window.Engine.Generation == 1, "Step advances the simulation after the tour");
        Invoke(window, "Undo"); await Task.Delay(200);
        Require(window.Engine.Generation == 0, "Undo restores generation zero");
        Invoke(window, "Redo"); await Task.Delay(200);
        Require(window.Engine.Generation == 1, "Redo restores the stepped generation");
        int population = window.Engine.Population;
        Invoke(window, "Clear"); await Task.Delay(200);
        Require(window.Engine.Population == 0, "Clear removes live cells");
        Invoke(window, "Undo"); await Task.Delay(200);
        Require(window.Engine.Population == population, "Undo restores the cleared pattern");
        Invoke(window, "▶  Start"); await Task.Delay(1250);
        Require(window.Running && window.Engine.Generation > 1, "Start runs the timer and advances generations");
        Invoke(window, "■  Stop"); await Task.Delay(200);
        long paused = window.Engine.Generation;
        await Task.Delay(650);
        Require(!window.Running && window.Engine.Generation == paused, "Stop pauses the simulation");
        using (var saved = JsonDocument.Parse(File.ReadAllText(Path.Combine(output, "isolated-data/canvas.life.json"))))
            Require(saved.RootElement.GetProperty("generation").GetInt64() == paused, "Simulation autosave records the displayed generation");
        // Render the real app layout at its natural 1600 × 1000 window size.
        // The host monitor is only 1024px wide; enlarging its screenshot would blur text.
        var root = (Grid)((AdornerDecorator)window.Content).Child;
        const int captureWidth = 1600, captureHeight = 1000;
        root.Width = captureWidth; root.Height = captureHeight; root.Background = window.Background;
        root.Resources = window.Resources;
        TextElement.SetFontFamily(root, window.FontFamily);
        TextElement.SetFontSize(root, window.FontSize);
        TextElement.SetForeground(root, window.Foreground);
        TextOptions.SetTextRenderingMode(root, TextRenderingMode.Grayscale);
        var picker = Descendants<ComboBox>(window).Single();
        // Remove the CI desktop's ancestor clip while retaining the actual UI controls,
        // resources and inherited typography. This changes the capture host only.
        ((AdornerDecorator)window.Content).Child = null;
        using var captureHost = new HwndSource(new HwndSourceParameters("Conway native screenshot host") {
            Width = captureWidth, Height = captureHeight, PositionX = 0, PositionY = 0,
            WindowStyle = unchecked((int)0x90000000) // Visible native popup; no OS caption in content captures.
        });
        captureHost.RootVisual = root;
        await Task.Delay(250);
        void Layout() {
            root.InvalidateMeasure();
            root.Measure(new Size(captureWidth, captureHeight)); root.Arrange(new Rect(0, 0, captureWidth, captureHeight));
            root.UpdateLayout();
        }
        async Task Capture(string name, bool fitLiving = true) {
            window.Update(); Layout(); window.Board.Fit(fitLiving);
            // Let WPF repaint the canvas after Fit updates its origin and zoom.
            await Task.Delay(150);
            var bitmap = new RenderTargetBitmap(captureWidth, captureHeight, 96, 96, PixelFormats.Pbgra32);
            bitmap.Render(root);
            var corner = new byte[4];
            bitmap.CopyPixels(new Int32Rect(captureWidth - 1, captureHeight - 1, 1, 1), corner, 4, 0);
            Require(corner[3] == 255, name + " fills the full capture beyond the CI monitor bounds");
            var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
            using var file = File.Create(Path.Combine(output, name + ".png")); encoder.Save(file);
            Require(root.ActualWidth == captureWidth && root.ActualHeight == captureHeight, name + " renders at native 1600 × 1000");
        }
        foreach (var theme in new[] { "Dark", "Light", "Sepia" }) {
            picker.SelectedItem = theme; await Task.Delay(250);
            Require(window.Theme == theme, theme + " theme selection updates the app");
            Require(!LifeWindow.Panel.IsFrozen, theme + " theme brush remains mutable after WPF rendering");
            var expectedPanel = theme == "Light" ? "#FFF0F0F0" : theme == "Sepia" ? "#FFEAD8B8" : "#FF121A1A";
            Require(LifeWindow.Panel.Color.ToString() == expectedPanel, theme + " theme paints the expected panel color");
            int pattern = theme == "Dark" ? 2 : theme == "Light" ? 1 : 5;
            window.Engine.LoadPattern(Catalog.All[pattern]);
            for (int i = 0; i < (theme == "Light" ? 18 : 80); i++) window.Engine.Step();
            await Capture("Conway-Windows-3.0-" + theme);
        }
        picker.SelectedItem = "Dark"; await Task.Delay(250);
        window.Engine.LoadPattern(Catalog.All[1]);
        foreach (var cell in window.Engine.Live) window.Engine.Select(cell.X, cell.Y);
        window.SelectionChanged();
        await Capture("Conway-Windows-3.0-Pattern-Selection");
        Require(window.Engine.Selection.Count > 0, "Editing screenshot contains a selected pattern");
        picker.SelectedItem = "Light"; await Task.Delay(250);
        window.Engine.ConfigureBorders(true, 64, 40); window.Engine.LoadPattern(Catalog.All[2]);
        for (int i = 0; i < 40; i++) window.Engine.Step();
        window.SelectionChanged();
        await Capture("Conway-Windows-3.0-Finite-Canvas", false);
        Require(window.Engine.Borders && window.Engine.Cols == 64 && window.Engine.Rows == 40, "Finite canvas screenshot displays configured boundaries");
        File.WriteAllText(Path.Combine(output, "windows-ui-report.json"), JsonSerializer.Serialize(new {
            platform = Environment.OSVersion.ToString(), compiledAssembly = typeof(LifeWindow).Assembly.GetName().Version?.ToString(), checks,
            interaction = "WPF UI Automation Invoke provider; actual mouse and installed MSIX testing remain separate",
            screenshots = "Five native 1600 × 1000 WPF RenderTargetBitmap captures of compiled app content; no upscaling, padding, OS chrome or marketing overlays"
        }, new JsonSerializerOptions { WriteIndented = true }));
    }
}
