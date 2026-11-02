using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

namespace FriishProduce
{
    /// <summary>
    /// Small operating-system boundary for opening URLs and revealing generated files.
    /// Keeping shell integration here prevents Windows Explorer calls from leaking into
    /// application workflows that will be reused by the cross-platform frontend.
    /// </summary>
    public static class PlatformServices
    {
        private static string QuoteArgument(string value)
        {
            return "\"" + (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        }

        private static void StartDetached(string fileName, string arguments)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            Process.Start(startInfo);
        }

        public static void OpenUrl(string url)
        {
            if (string.IsNullOrWhiteSpace(url))
                throw new ArgumentException("A URL is required.", nameof(url));

            if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
                StartDetached("/usr/bin/open", QuoteArgument(url));
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
                StartDetached("xdg-open", QuoteArgument(url));
            else
                Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }

        public static void OpenDirectory(string directory)
        {
            if (string.IsNullOrWhiteSpace(directory))
                throw new ArgumentException("A directory is required.", nameof(directory));

            string fullPath = Path.GetFullPath(directory);
            if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
                StartDetached("/usr/bin/open", QuoteArgument(fullPath));
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
                StartDetached("xdg-open", QuoteArgument(fullPath));
            else
                StartDetached("explorer.exe", QuoteArgument(fullPath));
        }

        public static void RevealFile(string filePath)
        {
            if (string.IsNullOrWhiteSpace(filePath))
                throw new ArgumentException("A file path is required.", nameof(filePath));

            string fullPath = Path.GetFullPath(filePath);
            if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
                StartDetached("/usr/bin/open", "-R " + QuoteArgument(fullPath));
            else if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
                OpenDirectory(Path.GetDirectoryName(fullPath));
            else
                StartDetached("explorer.exe", "/select, " + QuoteArgument(fullPath));
        }
    }
}
