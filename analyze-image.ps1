param(
  [string]$Path = "E:\download\dsh-desktop-pet\source.png"
)

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class ImageAnalyzer {
    public static string Analyze(string path) {
        using (var bmp = new Bitmap(path)) {
            int w = bmp.Width, h = bmp.Height;
            var rect = new Rectangle(0, 0, w, h);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = data.Stride;
            byte[] bytes = new byte[stride * h];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            bmp.UnlockBits(data);

            // background = average of corners + edge midpoints
            long sr = 0, sg = 0, sb = 0; int sn = 0;
            int[][] pts = new int[][] {
                new[]{0,0}, new[]{w-1,0}, new[]{0,h-1}, new[]{w-1,h-1},
                new[]{w/2,0}, new[]{0,h/2}, new[]{w-1,h/2}, new[]{w/2,h-1}
            };
            foreach (var p in pts) {
                int x = p[0], y = p[1];
                int i = y*stride + x*4;
                sr += bytes[i+2]; sg += bytes[i+1]; sb += bytes[i]; sn++;
            }
            int br = (int)(sr/sn), bg = (int)(sg/sn), bb = (int)(sb/sn);

            int thresh = 30;
            int[] rowContent = new int[h];
            int[] colContent = new int[w];
            for (int y = 0; y < h; y++) {
                int cnt = 0;
                for (int x = 0; x < w; x++) {
                    int i = y*stride + x*4;
                    int dr = Math.Abs(bytes[i+2]-br);
                    int dg = Math.Abs(bytes[i+1]-bg);
                    int db = Math.Abs(bytes[i]-bb);
                    if (dr >= thresh || dg >= thresh || db >= thresh) cnt++;
                }
                rowContent[y] = cnt;
            }
            for (int x = 0; x < w; x++) {
                int cnt = 0;
                for (int y = 0; y < h; y++) {
                    int i = y*stride + x*4;
                    int dr = Math.Abs(bytes[i+2]-br);
                    int dg = Math.Abs(bytes[i+1]-bg);
                    int db = Math.Abs(bytes[i]-bb);
                    if (dr >= thresh || dg >= thresh || db >= thresh) cnt++;
                }
                colContent[x] = cnt;
            }

            var rows = Bands(rowContent, 4);
            var cols = Bands(colContent, 4);

            var sb2 = new System.Text.StringBuilder();
            sb2.AppendLine("Dimensions: " + w + " x " + h);
            sb2.AppendLine("Background RGB: " + br + "," + bg + "," + bb);
            sb2.AppendLine("Row bands: " + rows.Count);
            foreach (var b in rows) sb2.AppendLine("  R " + b.Start + "-" + b.End + " (h=" + (b.End-b.Start+1) + ")");
            sb2.AppendLine("Column bands: " + cols.Count);
            foreach (var b in cols) sb2.AppendLine("  C " + b.Start + "-" + b.End + " (w=" + (b.End-b.Start+1) + ")");
            return sb2.ToString();
        }
    }

    static List<Band> Bands(int[] profile, int minContent) {
        var bands = new List<Band>();
        bool inBand = false; int start = 0;
        for (int i = 0; i < profile.Length; i++) {
            bool isContent = profile[i] > minContent;
            if (isContent && !inBand) { start = i; inBand = true; }
            else if (!isContent && inBand) { bands.Add(new Band{Start=start, End=i-1}); inBand = false; }
        }
        if (inBand) bands.Add(new Band{Start=start, End=profile.Length-1});
        return bands;
    }

    public struct Band { public int Start; public int End; }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing

[ImageAnalyzer]::Analyze($Path)
