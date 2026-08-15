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

public static class Blobs {
    public static string Find(string path) {
        using (var bmp = new Bitmap(path)) {
            int w = bmp.Width, h = bmp.Height;
            var rect = new Rectangle(0, 0, w, h);
            var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int stride = data.Stride;
            byte[] bytes = new byte[stride * h];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            bmp.UnlockBits(data);

            // background teal (0,31,31)
            int br=0, bg=31, bb=31, thresh=45;
            bool[] content = new bool[w*h];
            for (int y=0;y<h;y++) for(int x=0;x<w;x++){
                int i=y*stride+x*4;
                int dr=Math.Abs(bytes[i+2]-br), dg=Math.Abs(bytes[i+1]-bg), db=Math.Abs(bytes[i]-bb);
                content[y*w+x] = (dr>=thresh || dg>=thresh || db>=thresh);
            }

            // 4-connectivity flood fill (iterative, using a stack of ints)
            int[] label = new int[w*h];
            var boxes = new List<int[]>(); // x0,y0,x1,y1,count
            for (int idx=0; idx<w*h; idx++) {
                if (!content[idx] || label[idx]!=0) continue;
                int x0=w,y0=h,x1=-1,y1=-1,count=0;
                var stack = new Stack<int>();
                stack.Push(idx);
                label[idx]=1;
                while(stack.Count>0){
                    int c=stack.Pop();
                    int x=c%w, y=c/w;
                    if(x<x0)x0=x; if(x>x1)x1=x; if(y<y0)y0=y; if(y>y1)y1=y; count++;
                    // neighbors
                    if(x>0 && content[c-1] && label[c-1]==0){label[c-1]=1; stack.Push(c-1);}
                    if(x<w-1 && content[c+1] && label[c+1]==0){label[c+1]=1; stack.Push(c+1);}
                    if(y>0 && content[c-w] && label[c-w]==0){label[c-w]=1; stack.Push(c-w);}
                    if(y<h-1 && content[c+w] && label[c+w]==0){label[c+w]=1; stack.Push(c+w);}
                }
                boxes.Add(new int[]{x0,y0,x1,y1,count});
            }

            // sort by y then x
            boxes.Sort((a,b)=> a[1]==b[1] ? a[0]-b[0] : a[1]-b[1]);
            var sb = new System.Text.StringBuilder();
            sb.AppendLine("Total components: " + boxes.Count);
            foreach(var b in boxes){
                int bw=b[2]-b[0]+1, bh=b[3]-b[1]+1;
                sb.AppendLine("box x="+b[0]+" y="+b[1]+" w="+bw+" h="+bh+" px="+b[4]);
            }
            return sb.ToString();
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Drawing
[Blobs]::Find($Path)
