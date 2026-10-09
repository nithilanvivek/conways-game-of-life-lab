using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Automation.Peers;
using System.Windows.Automation.Provider;
using System.Windows.Controls;
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
        var button = Descendants<Button>(window).Single(b => b.Content as string == label);
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
        // Real rendered UI screenshots, with a built-in demo pattern and no tour overlay.
        window.Engine.LoadPattern(Catalog.All[2]); window.Update(); window.Board.Fit(true);
        var picker = Descendants<ComboBox>(window).Single();
        foreach (var theme in new[] { "Dark", "Light", "Sepia" }) {
            picker.SelectedItem = theme; await Task.Delay(250);
            Require(window.Theme == theme, theme + " theme selection updates the app");
            window.UpdateLayout();
            var content = (FrameworkElement)window.Content;
            var dpi = VisualTreeHelper.GetDpi(content);
            var bitmap = new RenderTargetBitmap((int)Math.Ceiling(content.ActualWidth * dpi.DpiScaleX), (int)Math.Ceiling(content.ActualHeight * dpi.DpiScaleY), dpi.PixelsPerInchX, dpi.PixelsPerInchY, PixelFormats.Pbgra32);
            bitmap.Render(content);
            var encoder = new PngBitmapEncoder(); encoder.Frames.Add(BitmapFrame.Create(bitmap));
            using var file = File.Create(Path.Combine(output, "Conway-Windows-3.0-" + theme + ".png")); encoder.Save(file);
        }
        File.WriteAllText(Path.Combine(output, "windows-ui-report.json"), JsonSerializer.Serialize(new {
            platform = Environment.OSVersion.ToString(), compiledAssembly = typeof(LifeWindow).Assembly.GetName().Version?.ToString(), checks,
            interaction = "WPF UI Automation Invoke provider; actual mouse and installed MSIX testing remain separate",
            screenshots = "Native WPF RenderTargetBitmap captures of the compiled app content"
        }, new JsonSerializerOptions { WriteIndented = true }));
    }
}
