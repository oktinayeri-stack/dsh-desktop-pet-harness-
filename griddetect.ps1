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

public static class GridDetect {
    public static string Run(string path) {
        using (var bmp = new Bitmap(path)) {
            int w=bmp.Width,h=bmp.Height;
            var rect=new Rectangle(0,0,w,h);
            var data=bmp.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
            int stride=data.Stride;
            byte[] bytes=new byte[stride*h];
            Marshal.Copy(data.Scan0,bytes,0,bytes.Length);
            bmp.UnlockBits(data);

            // classify per pixel: bar (blue or cyan), content (other non-black), black
            // horizontal bar fraction per row
            var sb=new System.Text.StringBuilder();
            sb.AppendLine("Horizontal 'cool' (blue/cyan) band rows (fraction>0.25):");
            var rows=new List<int>();
            for(int y=0;y<h;y++){
                int cool=0;
                for(int x=0;x<w;x++){
                    int i=y*stride+x*4;
                    int r=bytes[i+2],g=bytes[i+1],b=bytes[i];
                    bool isCool = (b>r+40 && b>g+40 && b>90) || (g>150 && b>150 && r<100);
                    if(isCool) cool++;
                }
                double frac=(double)cool/w;
                if(frac>0.25) rows.Add(y);
            }
            // group contiguous
            var bands=new List<string>();
            if(rows.Count>0){
                int s=rows[0],p=rows[0];
                for(int k=1;k<rows.Count;k++){ if(rows[k]==p+1){p=rows[k];} else { bands.Add(s+"-"+p); s=rows[k];p=rows[k]; } }
                bands.Add(s+"-"+p);
            }
            sb.AppendLine(string.Join(", ", bands));

            // vertical cool bands
            sb.AppendLine("Vertical 'cool' (blue/cyan) band cols (fraction>0.15):");
            var cols=new List<int>();
            for(int x=0;x<w;x++){
                int cool=0;
                for(int y=0;y<h;y++){
                    int i=y*stride+x*4;
                    int r=bytes[i+2],g=bytes[i+1],b=bytes[i];
                    bool isCool = (b>r+40 && b>g+40 && b>90) || (g>150 && b>150 && r<100);
                    if(isCool) cool++;
                }
                double frac=(double)cool/h;
                if(frac>0.15) cols.Add(x);
            }
            var cbands=new List<string>();
            if(cols.Count>0){
                int s=cols[0],p=cols[0];
                for(int k=1;k<cols.Count;k++){ if(cols[k]==p+1){p=cols[k];} else { cbands.Add(s+"-"+p); s=cols[k];p=cols[k]; } }
                cbands.Add(s+"-"+p);
            }
            sb.AppendLine(string.Join(", ", cbands));
            return sb.ToString();
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[GridDetect]::Run($Path)
