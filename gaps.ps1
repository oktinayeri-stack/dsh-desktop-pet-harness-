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

public static class Gaps {
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
                sb.AppendLine("=== Band y "+y0+".."+y1+" (bh="+bh+") ===");
                var runs=new List<int[]>(); // x0,x1,type
                int s=-1,p=-1;
                for(int x=0;x<w;x++){
                    int c=0;
                    for(int y=y0;y<=y1;y++){ int i=y*stride+x*4; if(bytes[i+2]>=24||bytes[i+1]>=24||bytes[i]>=24) c++; }
                    double f=(double)c/bh;
                    bool gap = f<0.05;
                    if(gap){ if(s<0)s=x; p=x; } else if(s>=0){ runs.Add(new[]{s,p,(int)((double)(p-s+1))}); s=-1; }
                }
                if(s>=0) runs.Add(new[]{s,p,p-s+1});
                var line=new List<string>();
                foreach(var r in runs) line.Add(r[0]+"-"+r[1]+"("+(r[1]-r[0]+1)+")");
                sb.AppendLine("gap runs (f<5%): "+string.Join(", ", line));
            }
            return sb.ToString();
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[Gaps]::Run($Path)
