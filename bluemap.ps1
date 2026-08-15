param(
  [string]$Path = "E:\download\dsh-desktop-pet\source.png",
  [int]$Cols = 150,
  [int]$Rows = 84
)

Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class BlueMap {
    public static string Run(string path, int cols, int rows) {
        using (var bmp = new Bitmap(path)) {
            int w=bmp.Width,h=bmp.Height;
            var rect=new Rectangle(0,0,w,h);
            var data=bmp.LockBits(rect,ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
            int stride=data.Stride;
            byte[] bytes=new byte[stride*h];
            Marshal.Copy(data.Scan0,bytes,0,bytes.Length);
            bmp.UnlockBits(data);
            var sb=new System.Text.StringBuilder();
            for(int ry=0;ry<rows;ry++){
                int y0=ry*h/rows, y1=(ry+1)*h/rows; if(y1<=y0)y1=y0+1;
                for(int rx=0;rx<cols;rx++){
                    int x0=rx*w/cols, x1=(rx+1)*w/cols; if(x1<=x0)x1=x0+1;
                    long blue=0, cyan=0, other=0, black=0; int n=0;
                    for(int y=y0;y<y1;y++)for(int x=x0;x<x1;x++){
                        int i=y*stride+x*4;
                        int r=bytes[i+2],g=bytes[i+1],b=bytes[i]; n++;
                        if(r<24&&g<24&&b<24) black++;
                        else if(b>r+40 && b>g+40 && b>90) blue++;
                        else if(g>150 && b>150 && r<100) cyan++;
                        else other++;
                    }
                    char c;
                    if(blue*4>n) c='B';
                    else if(cyan*4>n) c='C';
                    else if(black*4>n) c=' ';
                    else if(black*10>n*6) c='.';
                    else c='#';
                    sb.Append(c);
                }
                sb.AppendLine();
            }
            return sb.ToString();
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[BlueMap]::Run($Path, $Cols, $Rows)
