using System.IO;

namespace Nithi.Life;

internal static class AppResources {
    public static Stream Open(string name) => typeof(AppResources).Assembly
        .GetManifestResourceStream("Nithi.Life." + name)
        ?? throw new IOException("Missing embedded app resource: " + name);
}
