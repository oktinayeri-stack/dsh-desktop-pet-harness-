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

public static class Splitter {
    public static string Run(string path, string outDir) {
        using (var bmp = new Bitmap(path)) {
            int w=bmp.Width,h=bmp.Height;
            var rect=new Rectangle(0,0,w,h);
            var data=bmp.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
            int stride=data.Stride;
            byte[] bytes=new byte[stride*h];
            Marshal.Copy(data.Scan0,bytes,0,bytes.Length);
            bmp.UnlockBits(data);

            Func<int,int,bool> isBlack = (x,y) => { int i=y*stride+x*4; return bytes[i+2]<24 && bytes[i+1]<24 && bytes[i]<24; };
            Func<int,int,bool> isCool = (x,y) => { int i=y*stride+x*4; int r=bytes[i+2],g=bytes[i+1],b=bytes[i]; return (b>r+40 && b>g+40 && b>90) || (g>150 && b>150 && r<100); };

            // 1. horizontal cool bands
            var hband = new List<int>();
            for(int y=0;y<h;y++){ int c=0; for(int x=0;x<w;x++) if(isCool(x,y)) c++; if((double)c/w > 0.12) hband.Add(y); }
            var hb=new List<int[]>();
            if(hband.Count>0){ int s=hband[0],p=hband[0]; for(int k=1;k<hband.Count;k++){ if(hband[k]==p+1){p=hband[k];} else {hb.Add(new[]{s,p}); s=hband[k];p=hband[k];} } hb.Add(new[]{s,p}); }

            // character bands = between cool bands (and image edges)
            var cbands=new List<int[]>();
            int top=0;
            foreach(var b in hb){ if(b[0]-top >= 60) cbands.Add(new[]{top,b[0]}); top=b[1]+1; }
            if(h-top >= 60) cbands.Add(new[]{top,h-1});

            var sb=new System.Text.StringBuilder();
            sb.AppendLine("Character bands:");
            foreach(var b in cbands) sb.AppendLine("  y "+b[0]+".."+b[1]);

            // 2. per band, vertical content profile and column gaps
            Directory.CreateDirectory(outDir);
            int fi=0;
            var cells=new List<int[]>();
            foreach(var b in cbands){
                int y0=b[0], y1=b[1]; int bh=y1-y0+1;
                // find gap columns: content < 6% of band height
                var gapCols=new bool[w];
                for(int x=0;x<w;x++){ int c=0; for(int y=y0;y<=y1;y++) if(!isBlack(x,y)) c++; gapCols[x] = (double)c/bh < 0.06; }
                // group gap columns into runs; take runs wider than 6px
                var gaps=new List<int[]>();
                int gs=-1, gp=-1;
                for(int x=0;x<w;x++){ if(gapCols[x]){ if(gs<0){gs=x;} gp=x; } else if(gs>=0){ if(gp-gs+1>=6) gaps.Add(new[]{gs,gp}); gs=-1; } }
                if(gs>=0 && gp-gs+1>=6) gaps.Add(new[]{gs,gp});

                // cut positions = midpoints of gaps
                var cuts=new List<int>();
                foreach(var g in gaps) cuts.Add((g[0]+g[1])/2);

                // cells = [y0, y1, x0, x1]
                var xs=new List<int>(); xs.Add(0); foreach(var c in cuts) xs.Add(c+1); xs.Add(w-1);
                for(int k=0;k<xs.Count-1;k++){
                    int x0=xs[k], x1=xs[k+1];
                    if(x1-x0 < 20) continue; // skip tiny
                    cells.Add(new[]{x0,y0,x1,y1});
                }
            }

            // sort cells
            cells.Sort((a,b)=> a[1]==b[1] ? a[0]-b[0] : a[1]-b[1]);
            sb.AppendLine("Cells: "+cells.Count);
            foreach(var c in cells){
                int x0=c[0],y0=c[1],x1=c[2],y1=c[3];
                int cw=x1-x0+1, ch=y1-y0+1;
                sb.AppendLine("  cell x="+x0+" y="+y0+" w="+cw+" h="+ch);
                // crop & save
                var crop=new Bitmap(cw,ch,PixelFormat.Format32bppArgb);
                var g=Graphics.FromImage(crop);
                g.DrawImage(bmp, new Rectangle(0,0,cw,ch), new Rectangle(x0,y0,cw,ch), GraphicsUnit.Pixel);
                g.Dispose();
                crop.Save(Path.Combine(outDir,"frame_"+fi.ToString("D3")+".png"), ImageFormat.Png);
                crop.Dispose();
                fi++;
            }
            sb.AppendLine("Saved "+fi+" frames to "+outDir);
            return sb.ToString();
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[Splitter]::Run($Path, $OutDir)
