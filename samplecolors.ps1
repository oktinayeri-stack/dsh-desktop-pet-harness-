param(
  [string]$Path = "E:\download\dsh-desktop-pet\source.png"
)

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class SampleColors {
    public static string Run(string path) {
        using (var bmp = new Bitmap(path)) {
            int w=bmp.Width,h=bmp.Height;
            var rect=new Rectangle(0,0,w,h);
            var data=bmp.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
            int stride=data.Stride;
            byte[] bytes=new byte[stride*h];
            Marshal.Copy(data.Scan0,bytes,0,bytes.Length);
            bmp.UnlockBits(data);
            var sb=new System.Text.StringBuilder();

            // sample rows every 20px, and for each, list the most common colors (quantized)
            sb.AppendLine("ROW COLOR SAMPLES (y, top colors):");
            for(int y=0;y<h;y+=20){
                var hist=new System.Collections.Generic.Dictionary<int,int>();
                for(int x=0;x<w;x+=3){
                    int i=y*stride+x*4;
                    int r=bytes[i+2],g=bytes[i+1],b=bytes[i];
                    int key=((r>>4)<<8)|((g>>4)<<4)|(b>>4);
                    if(!hist.ContainsKey(key))hist[key]=0; hist[key]++;
                }
                var tops=new System.Collections.Generic.List<int[]>();
                foreach(var kv in hist) tops.Add(new int[]{kv.Key,kv.Value});
                tops.Sort((a,b)=>b[1]-a[1]);
                var line="y="+y+" : ";
                for(int k=0;k<Math.Min(5,tops.Count);k++){
                    int key=tops[k][0];
                    int r=((key>>8)&0xF)<<4, g=((key>>4)&0xF)<<4, b=(key&0xF)<<4;
                    line+=" ("+r+","+g+","+b+")x"+tops[k][1]+" ";
                }
                sb.AppendLine(line);
            }
            return sb.ToString();
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[SampleColors]::Run($Path)
