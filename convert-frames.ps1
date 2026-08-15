param(
  [string]$SrcDir = "E:\download\dsh-desktop-pet\frames",
  [string]$OutDir = "E:\download\dsh-desktop-pet\frames-jpg",
  [int]$MaxDim = 180
)

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class ConvertFrames {
    public static string Run(string srcDir, string outDir, int maxDim) {
        Directory.CreateDirectory(outDir);
        foreach(var f in Directory.GetFiles(outDir)) File.Delete(f);
        var files = Directory.GetFiles(srcDir, "*.png");
        Array.Sort(files);
        int n=0; long total=0;
        foreach(var f in files){
            using(var img = new Bitmap(f)){
                int w=img.Width, h=img.Height;
                double scale = Math.Min(1.0, (double)maxDim/Math.Max(w,h));
                int nw=Math.Max(1,(int)Math.Round(w*scale)), nh=Math.Max(1,(int)Math.Round(h*scale));
                using(var resized = new Bitmap(nw,nh,PixelFormat.Format24bppRgb)){
                    using(var g=Graphics.FromImage(resized)){
                        g.InterpolationMode=InterpolationMode.HighQualityBicubic;
                        g.SmoothingMode=SmoothingMode.HighQuality;
                        g.PixelOffsetMode=PixelOffsetMode.HighQuality;
                        g.DrawImage(img, new Rectangle(0,0,nw,nh));
                    }
                    var enc = ImageCodecInfo.GetImageEncoders();
                    ImageCodecInfo jpeg = null;
                    foreach(var e in enc) if(e.FormatID==ImageFormat.Jpeg.Guid) jpeg=e;
                    var ep = new EncoderParameters(1);
                    ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 88L);
                    var name = Path.GetFileNameWithoutExtension(f)+".jpg";
                    resized.Save(Path.Combine(outDir,name), jpeg, ep);
                    ep.Dispose();
                    var fi=new FileInfo(Path.Combine(outDir,name));
                    total+=fi.Length;
                }
            }
            n++;
        }
        return "Converted "+n+" frames, total bytes="+total;
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[ConvertFrames]::Run($SrcDir, $OutDir, $MaxDim)
