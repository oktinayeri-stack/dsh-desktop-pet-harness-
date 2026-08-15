param(
  [string]$Path = "E:\download\dsh-desktop-pet\source.png",
  [string]$OutDir = "E:\download\dsh-desktop-pet\frames"
)

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class FinalSplit {
    public static string Run(string path, string outDir) {
        using (var bmp = new Bitmap(path)) {
            // detected row bands
            int[][] bands = new int[][]{ new[]{42,276}, new[]{317,541}, new[]{583,803}, new[]{835,1001} };
            // detected gap midpoints per band (from projection analysis)
            int[][] gapMids = new int[][]{
                new[]{136, 272, 411, 544, 1086, 1289},
                new[]{265, 459, 689, 958, 1290},
                new[]{670, 905, 1224},
                new int[]{}
            };

            Directory.CreateDirectory(outDir);
            // clear existing frames
            foreach(var f in Directory.GetFiles(outDir,"frame_*.png")) File.Delete(f);

            var cells=new List<int[]>();
            for(int b=0;b<bands.Length;b++){
                int y0=bands[b][0], y1=bands[b][1];
                var xs=new List<int>(); xs.Add(0);
                foreach(var m in gapMids[b]) xs.Add(m+1);
                xs.Add(bmp.Width-1);
                for(int k=0;k<xs.Count-1;k++){
                    int x0=xs[k], x1=xs[k+1], cw=x1-x0+1;
                    if(cw<24) continue;
                    if(cw>350){
                        int n=(int)Math.Ceiling((double)cw/180.0);
                        int part=(int)Math.Ceiling((double)cw/n);
                        for(int i=0;i<n;i++){
                            int sx=x0+i*part, ex=Math.Min(x0+(i+1)*part-1, x1);
                            cells.Add(new[]{sx,y0,ex,y1});
                        }
                    } else {
                        cells.Add(new[]{x0,y0,x1,y1});
                    }
                }
            }

            cells.Sort((a,b)=> a[1]==b[1] ? a[0]-b[0] : a[1]-b[1]);
            var sb=new System.Text.StringBuilder();
            int fi=0;
            foreach(var c in cells){
                int x0=c[0],y0=c[1],x1=c[2],y1=c[3];
                int cw=x1-x0+1, ch=y1-y0+1;
                var crop=new Bitmap(cw,ch,PixelFormat.Format32bppArgb);
                var g=Graphics.FromImage(crop);
                g.DrawImage(bmp, new Rectangle(0,0,cw,ch), new Rectangle(x0,y0,cw,ch), GraphicsUnit.Pixel);
                g.Dispose();
                crop.Save(Path.Combine(outDir,"frame_"+fi.ToString("D3")+".png"), ImageFormat.Png);
                crop.Dispose();
                fi++;
            }
            sb.AppendLine("Total frames: "+fi);
            sb.AppendLine("Saved to "+outDir);
            return sb.ToString();
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[FinalSplit]::Run($Path, $OutDir)
