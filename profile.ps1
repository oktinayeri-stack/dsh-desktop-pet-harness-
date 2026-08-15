param(
  [string]$Path = "E:\download\dsh-desktop-pet\source.png"
)

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Profile {
    public static string Run(string path) {
        using (var bmp = new Bitmap(path)) {
            int w = bmp.Width, h = bmp.Height;
            var rect = new Rectangle(0, 0, w, h);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = data.Stride;
            byte[] bytes = new byte[stride * h];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            bmp.UnlockBits(data);

            int br=0, bg=31, bb=31, thresh=40;
            int[] rowC = new int[h];
            int[] colC = new int[w];
            for (int y=0;y<h;y++){ int c=0; for(int x=0;x<w;x++){ int i=y*stride+x*4; if(Math.Abs(bytes[i+2]-br)>=thresh||Math.Abs(bytes[i+1]-bg)>=thresh||Math.Abs(bytes[i]-bb)>=thresh) c++; } rowC[y]=c; }
            for (int x=0;x<w;x++){ int c=0; for(int y=0;y<h;y++){ int i=y*stride+x*4; if(Math.Abs(bytes[i+2]-br)>=thresh||Math.Abs(bytes[i+1]-bg)>=thresh||Math.Abs(bytes[i]-bb)>=thresh) c++; } colC[x]=c; }

            var sb = new System.Text.StringBuilder();
            sb.AppendLine("ROW PROFILE (one char per row, y=0.."+(h-1)+", . = empty teal):");
            for (int y=0;y<h;y++){
                int c=rowC[y];
                char ch = c==0?'.' : c<10?'1' : c<50?'2' : c<150?'3' : c<400?'4' : c<700?'5' : c<1000?'6' : '7';
                sb.Append(ch);
                if(y%120==119) sb.AppendLine();
            }
            sb.AppendLine();
            sb.AppendLine();
            sb.AppendLine("COLUMN PROFILE (one char per col, x=0.."+(w-1)+", . = empty teal):");
            for (int x=0;x<w;x++){
                int c=colC[x];
                char ch = c==0?'.' : c<10?'1' : c<50?'2' : c<150?'3' : c<400?'4' : c<700?'5' : c<1000?'6' : '7';
                sb.Append(ch);
                if(x%120==119) sb.AppendLine();
            }
            return sb.ToString();
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[Profile]::Run($Path)
