using System.IO;

namespace Nithi.Life;

internal static class AppPaths {
    public static readonly string Data = Environment.GetEnvironmentVariable("NITHI_LIFE_DATA_DIR")
        ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Nithi Life");
    public static readonly string Library = Environment.GetEnvironmentVariable("NITHI_LIFE_LIBRARY_DIR")
        ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Conway Game of Life Canvases");
}
