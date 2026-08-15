param(
  [string]$Path = "E:\download\dsh-desktop-pet\source.png",
  [int]$Cols = 90,
  [int]$Rows = 48
)

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Preview {
    public static string Render(string path, int cols, int rows) {
        using (var bmp = new Bitmap(path)) {
            int w = bmp.Width, h = bmp.Height;
            var rect = new Rectangle(0, 0, w, h);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = data.Stride;
            byte[] bytes = new byte[stride * h];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            bmp.UnlockBits(data);

            var outp = new System.Text.StringBuilder();
            for (int ry = 0; ry < rows; ry++) {
                int y0 = ry * h / rows;
                int y1 = (ry+1) * h / rows;
                if (y1 <= y0) y1 = y0 + 1;
                for (int rx = 0; rx < cols; rx++) {
                    int x0 = rx * w / cols;
                    int x1 = (rx+1) * w / cols;
                    if (x1 <= x0) x1 = x0 + 1;
                    long sr=0,sg=0,sbl=0; int n=0;
                    for (int y = y0; y < y1; y++) {
                        for (int x = x0; x < x1; x++) {
                            int i = y*stride + x*4;
                            sr += bytes[i+2]; sg += bytes[i+1]; sbl += bytes[i]; n++;
                        }
                    }
                    int r=(int)(sr/n), g=(int)(sg/n), b=(int)(sbl/n);
                    char c = Classify(r,g,b);
                    outp.Append(c);
                }
                outp.AppendLine();
            }
            return outp.ToString();
        }
    }

    static char Classify(int r, int g, int b) {
        // background is (0,31,31) dark teal
        int dr = Math.Abs(r-0), dg = Math.Abs(g-31), db = Math.Abs(b-31);
        if (dr < 40 && dg < 40 && db < 40) return '.';
        int mx = Math.Max(r, Math.Max(g,b));
        int mn = Math.Min(r, Math.Min(g,b));
        if (mx - mn < 20) {
            // grayish
            if (mx > 200) return '#';
            if (mx > 120) return '+';
            return ':';
        }
        // colorful
        if (r > g && r > b) return (r > 150) ? 'R' : 'r';
        if (g > r && g > b) return (g > 150) ? 'G' : 'g';
        if (b > r && b > g) return (b > 150) ? 'B' : 'b';
        if (r > 150 && g > 120 && b < 120) return 'y';
        return 'o';
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing

[Preview]::Render($Path, $Cols, $Rows)
