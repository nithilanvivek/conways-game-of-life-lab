using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Nithi.Life;

// Keep the entry point independent of WPF so framework-initialization failures are caught too.
public static class WindowsStartup {
    [STAThread]
    public static int Main() {
        StartupDiagnostics.Begin();
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            StartupDiagnostics.Report(e.ExceptionObject as Exception ?? new Exception(e.ExceptionObject.ToString()));
        try { return RunWindow(); }
        catch (Exception error) { StartupDiagnostics.Report(error); return 1; }
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    static int RunWindow() {
        // Set this before any windows are created; all app windows and dialogs use
        // the CPU renderer without changing the computer's graphics settings.
        System.Windows.Media.RenderOptions.ProcessRenderMode = System.Windows.Interop.RenderMode.SoftwareOnly;
        StartupDiagnostics.Stage("Software rendering enabled for this app process");
        StartupDiagnostics.Stage("Initializing Windows interface");
        var app = new LifeApplication();
        app.DispatcherUnhandledException += (_, e) => {
            StartupDiagnostics.Report(e.Exception);
            e.Handled = true;
            app.Shutdown(1);
        };
        StartupDiagnostics.Stage("Constructing app window");
        var window = new LifeWindow();
        window.ContentRendered += (_, _) => StartupDiagnostics.Stage("App window rendered successfully");
        return app.Run(window);
    }
}

internal static class StartupDiagnostics {
    static string logPath = "";
    static int reported;
    public static void Begin() {
        foreach (var directory in new[] {
            AppPaths.Data,
            Path.Combine(Path.GetTempPath(), "Nithi Life")
        }) {
            try {
                Directory.CreateDirectory(directory);
                logPath = Path.Combine(directory, "startup.log");
                File.AppendAllText(logPath,
                    $"Conway's Game of Life Lab v3.2-testing · Windows build 4{Environment.NewLine}" +
                    $"{DateTimeOffset.Now:O}{Environment.NewLine}" +
                    $"OS: {Environment.OSVersion}; architecture: {RuntimeInformation.ProcessArchitecture}{Environment.NewLine}" +
                    $"Runtime: {RuntimeInformation.FrameworkDescription}{Environment.NewLine}");
                return;
            } catch { logPath = ""; }
        }
    }
    public static void Stage(string message) {
        try { if (logPath.Length > 0) File.AppendAllText(logPath, $"{DateTimeOffset.Now:O} {message}{Environment.NewLine}"); }
        catch { }
    }
    public static void Report(Exception error) {
        if (Interlocked.Exchange(ref reported, 1) != 0) return;
        Stage(error.ToString());
        var message = "The app could not start or continue.\n\n" + error.GetBaseException().Message;
        if (logPath.Length > 0) message += "\n\nError details were saved to:\n" + logPath;
        try { MessageBoxW(IntPtr.Zero, message, "Conway's Game of Life Lab", 0x10); }
        catch { }
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    static extern int MessageBoxW(IntPtr owner, string text, string caption, uint type);
}
