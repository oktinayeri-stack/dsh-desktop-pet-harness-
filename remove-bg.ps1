param(
  [string]$SrcDir = "E:\download\dsh-desktop-pet\frames",
  [string]$OutDir = "E:\download\dsh-desktop-pet\frames-png",
  [int]$Threshold = 42
)

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class RemoveBg {
    public static string Run(string srcDir, string outDir, int threshold) {
        Directory.CreateDirectory(outDir);
        foreach (var f in Directory.GetFiles(outDir, "*.png")) File.Delete(f);
        var files = Directory.GetFiles(srcDir, "*.png");
        Array.Sort(files);
        int n = 0;
        foreach (var f in files) {
            using (var bmp = new Bitmap(f)) {
                int w = bmp.Width, h = bmp.Height;
                var rect = new Rectangle(0, 0, w, h);
                var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                int stride = data.Stride;
                byte[] bytes = new byte[stride * h];
                Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
                bmp.UnlockBits(data);

                bool[] bg = new bool[w * h];
                for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                    int i = y * stride + x * 4;
                    int b = bytes[i], g = bytes[i + 1], r = bytes[i + 2];
                    bg[y * w + x] = (r <= threshold && g <= threshold && b <= threshold);
                }

                // flood fill from the four edges through near-black pixels
                bool[] remove = new bool[w * h];
                var stack = new Stack<int>();
                for (int x = 0; x < w; x++) { if (bg[x] && !remove[x]) { remove[x] = true; stack.Push(x); } }
                for (int x = 0; x < w; x++) { int idx = (h - 1) * w + x; if (bg[idx] && !remove[idx]) { remove[idx] = true; stack.Push(idx); } }
                for (int y = 0; y < h; y++) { int idx = y * w; if (bg[idx] && !remove[idx]) { remove[idx] = true; stack.Push(idx); } }
                for (int y = 0; y < h; y++) { int idx = y * w + (w - 1); if (bg[idx] && !remove[idx]) { remove[idx] = true; stack.Push(idx); } }
                while (stack.Count > 0) {
                    int c = stack.Pop();
                    int cx = c % w, cy = c / w;
                    if (cx > 0)     { int ni = c - 1; if (bg[ni] && !remove[ni]) { remove[ni] = true; stack.Push(ni); } }
                    if (cx < w - 1) { int ni = c + 1; if (bg[ni] && !remove[ni]) { remove[ni] = true; stack.Push(ni); } }
                    if (cy > 0)     { int ni = c - w; if (bg[ni] && !remove[ni]) { remove[ni] = true; stack.Push(ni); } }
                    if (cy < h - 1) { int ni = c + w; if (bg[ni] && !remove[ni]) { remove[ni] = true; stack.Push(ni); } }
                }

                using (var outBmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
                    var od = outBmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                    byte[] ob = new byte[od.Stride * h];
                    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
                        int si = y * stride + x * 4, di = y * od.Stride + x * 4;
                        ob[di] = bytes[si];
                        ob[di + 1] = bytes[si + 1];
                        ob[di + 2] = bytes[si + 2];
                        ob[di + 3] = remove[y * w + x] ? (byte)0 : (byte)255;
                    }
                    Marshal.Copy(ob, 0, od.Scan0, ob.Length);
                    outBmp.UnlockBits(od);
                    outBmp.Save(Path.Combine(outDir, Path.GetFileNameWithoutExtension(f) + ".png"), ImageFormat.Png);
                }
            }
            n++;
        }
        return "Processed " + n + " frames (threshold " + threshold + ")";
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[RemoveBg]::Run($SrcDir, $OutDir, $Threshold)
