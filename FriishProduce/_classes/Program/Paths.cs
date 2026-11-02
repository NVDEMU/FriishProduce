using System;
using System.IO;
using System.Runtime.InteropServices;

namespace FriishProduce
{
    /// <summary>
    /// Centralized paths for bundled application resources and writable user data.
    /// Directory paths keep a trailing separator because legacy code appends filenames
    /// directly to several of these values.
    /// </summary>
    public static class Paths
    {
        private static string WithTrailingSeparator(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                throw new ArgumentException("A directory path is required.", nameof(path));

            string separator = Path.DirectorySeparatorChar.ToString();
            return path.EndsWith(separator, StringComparison.Ordinal)
                ? path
                : path + separator;
        }

        private static string JoinDirectory(string root, params string[] segments)
        {
            string path = root;
            foreach (string segment in segments)
                path = Path.Combine(path, segment);

            return WithTrailingSeparator(path);
        }

        private static string GetResourceFolder()
        {
            string baseDirectory = Path.GetFullPath(AppContext.BaseDirectory);

            if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            {
                var executableDirectory = new DirectoryInfo(baseDirectory);
                var contentsDirectory = executableDirectory.Parent;

                // In a normal macOS bundle, the executable lives in:
                // MyApp.app/Contents/MacOS/
                // Resources belong in MyApp.app/Contents/Resources/.
                if (string.Equals(executableDirectory.Name, "MacOS", StringComparison.OrdinalIgnoreCase)
                    && contentsDirectory != null
                    && string.Equals(contentsDirectory.Name, "Contents", StringComparison.OrdinalIgnoreCase))
                {
                    return WithTrailingSeparator(Path.Combine(contentsDirectory.FullName, "Resources"));
                }
            }

            // Also supports running from a development output directory.
            return WithTrailingSeparator(baseDirectory);
        }

        private static string GetWritableDataFolder()
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
                return ApplicationFolder;

            string supportFolder = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            if (string.IsNullOrWhiteSpace(supportFolder))
            {
                string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                supportFolder = Path.Combine(home, "Library", "Application Support");
            }

            string folder = Path.Combine(supportFolder, "FriishProduce");
            Directory.CreateDirectory(folder);
            return WithTrailingSeparator(folder);
        }

        /// <summary>Directory containing the executable and its app bundle.</summary>
        public static readonly string ApplicationFolder =
            WithTrailingSeparator(AppContext.BaseDirectory);

        /// <summary>Directory containing bundled, read-only data files.</summary>
        public static readonly string ResourceFolder = GetResourceFolder();

        /// <summary>
        /// Kept for compatibility with existing Windows-only update code.
        /// Writable files should use DataFolder.
        /// </summary>
        public static readonly string EnvironmentFolder = ApplicationFolder;

        /// <summary>
        /// Writable per-user storage. On Windows this preserves the legacy portable
        /// layout; on macOS it uses ~/Library/Application Support/FriishProduce.
        /// </summary>
        public static readonly string DataFolder = GetWritableDataFolder();

        // Writable application data
        public static readonly string Update = Path.Combine(DataFolder, "latest.zip");
        public static readonly string WorkingFolder = JoinDirectory(DataFolder, "resources", "temp");
        public static readonly string Config = Path.Combine(DataFolder, "FriishProduce.json");
        public static readonly string Log = Path.Combine(DataFolder, "log.txt");
        public static readonly string Out = JoinDirectory(DataFolder, "out");

        // Bundled, read-only application resources
        public static readonly string Banners = JoinDirectory(ResourceFolder, "resources", "tools", "banners");
        public static readonly string Databases = JoinDirectory(ResourceFolder, "resources", "databases");
        public static readonly string Tools = JoinDirectory(ResourceFolder, "resources", "tools");
        public static readonly string Languages = JoinDirectory(ResourceFolder, "strings");
        public static readonly string BIOSFiles = JoinDirectory(ResourceFolder, "resources", "bios");
        public static readonly string NativeTools = JoinDirectory(ResourceFolder, "tools", "native", "macos");

        // Extracted paths
        public static readonly string WAD = JoinDirectory(WorkingFolder, "wad");
        public static readonly string Manual = JoinDirectory(WorkingFolder, "manual");
        public static readonly string DataCCF = JoinDirectory(WorkingFolder, "data_ccf");
        public static readonly string MiscCCF = JoinDirectory(DataCCF, "misc_ccf");

        // C64 paths
        public static readonly string Frodo = JoinDirectory(Tools, "c64", "frodosrc");
        public static readonly string FrodoSnapshot = Path.Combine(Frodo, "ik.fss");
        public static readonly string FrodoRom = Path.Combine(Frodo, "rom.d64");
        public static readonly string FrodoOutput = Path.Combine(Frodo, "snap.fss");

        // Flash paths
        public static readonly string FlashContents = JoinDirectory(WorkingFolder, "flash");
        public static readonly string FlashSWF = Path.Combine(FlashContents, "content", "menu.swf");
        public static readonly string FlashConfig = Path.Combine(FlashContents, "config", "config.common.pcf");

        // Forwarder paths
        public static readonly string SDUSBRoot = JoinDirectory(WorkingFolder, "root");

        // Other
        public static readonly string PatchedSuffix = "-patched";
    }
}
