param(
  [string]$Path = "E:\download\dsh-desktop-pet\source.png"
)

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class BandCols {
    public static string Run(string path) {
        using (var bmp = new Bitmap(path)) {
            int w=bmp.Width,h=bmp.Height;
            var rect=new Rectangle(0,0,w,h);
            var data=bmp.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
            int stride=data.Stride;
            byte[] bytes=new byte[stride*h];
            Marshal.Copy(data.Scan0,bytes,0,bytes.Length);
            bmp.UnlockBits(data);

            int[][] bands = new int[][]{ new[]{42,276}, new[]{317,541}, new[]{583,803}, new[]{835,1001} };
            var sb=new System.Text.StringBuilder();
            foreach(var band in bands){
                int y0=band[0], y1=band[1]; int bh=y1-y0+1;
                sb.AppendLine("=== Band y "+y0+".."+y1+" ===");
                // per column: content = non-black
                for(int x=0;x<w;x++){
                    int c=0;
                    for(int y=y0;y<=y1;y++){ int i=y*stride+x*4; if(bytes[i+2]>=24||bytes[i+1]>=24||bytes[i]>=24) c++; }
                    double f=(double)c/bh;
                    char ch = f<0.03?'.' : f<0.10?'1' : f<0.25?'2' : f<0.45?'3' : f<0.70?'4' : f<0.90?'5' : '#';
                    sb.Append(ch);
                    if(x%100==99) sb.Append("|");
                }
                sb.AppendLine();
            }
            return sb.ToString();
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[BandCols]::Run($Path)
