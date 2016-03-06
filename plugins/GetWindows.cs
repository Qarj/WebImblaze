using System;
using System.Collections.Generic;
using System.Diagnostics;
//using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace GetWindows
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Returning visible window handles for processes named chrome");
            Process[] processes = Process.GetProcessesByName("chrome");
            foreach (Process process in processes)
            {
                IDictionary<IntPtr, string> windows = GetOpenWindowsFromPID(process.Id);
                foreach (KeyValuePair<IntPtr, string> kvp in windows)
                {
                    Console.WriteLine("{0}", kvp.ToString());
                }
            }
        }

        private delegate bool EnumWindowsProc(IntPtr hWnd, int lParam);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        [DllImport("USER32.DLL")]
        private static extern bool EnumWindows(EnumWindowsProc enumFunc, int lParam);

        [DllImport("USER32.DLL")]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("USER32.DLL")]
        private static extern int GetWindowTextLength(IntPtr hWnd);

        [DllImport("USER32.DLL")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("USER32.DLL")]
        private static extern IntPtr GetShellWindow();


        public static IDictionary<IntPtr, string> GetOpenWindowsFromPID(int processID)
        {
            IntPtr hShellWindow = GetShellWindow();
            Dictionary<IntPtr, string> dictWindows = new Dictionary<IntPtr, string>();

            EnumWindows(delegate(IntPtr hWnd, int lParam)
            {
                if (hWnd == hShellWindow) return true;
                if (!IsWindowVisible(hWnd)) return true; //comment out this line to find window handle when not running interactively

                int length = GetWindowTextLength(hWnd);
                if (length == 0) return true;

                uint windowPid;
                GetWindowThreadProcessId(hWnd, out windowPid);
                if (windowPid != processID) return true;

                StringBuilder stringBuilder = new StringBuilder(length);
                GetWindowText(hWnd, stringBuilder, length + 1);
                dictWindows.Add(hWnd, stringBuilder.ToString());
                return true;
            }, 0);

            return dictWindows;
        }
    }

}
