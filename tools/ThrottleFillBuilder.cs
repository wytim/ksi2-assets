using System;
using System.Drawing;
using System.Drawing.Imaging;

public static class ThrottleFillBuilder
{
    public static void Generate(string maskPath, string radialPath, string outputPath)
    {
        using (var mask = new Bitmap(maskPath))
        using (var radial = new Bitmap(radialPath))
        using (var fill = new Bitmap(mask.Width, mask.Height, PixelFormat.Format32bppArgb))
        {
            if (mask.Width != 170 || mask.Height != 580 || radial.Width != 832 || radial.Height != 832)
                throw new InvalidOperationException("Unexpected throttle mask dimensions.");

            double angle = -44 * Math.PI / 180;
            double cos = Math.Cos(angle);
            double sin = Math.Sin(angle);
            for (int y = 0; y < mask.Height; y++)
            {
                for (int x = 0; x < mask.Width; x++)
                {
                    int maskAlpha = mask.GetPixel(x, y).A;
                    if (maskAlpha == 0) continue;

                    double px = (x + 0.5) * 85 / mask.Width - 204.5;
                    double py = (y + 0.5) * 290 / mask.Height - 145;
                    double rx = px * cos - py * sin;
                    double ry = px * sin + py * cos;
                    double radialX = (rx / 416 + 0.5) * radial.Width;
                    double radialY = (ry / 416 + 0.5) * radial.Height;

                    int covered = 0;
                    foreach (double dy in new[] { -0.5, 0.5 })
                    foreach (double dx in new[] { -0.5, 0.5 })
                        if (AlphaAt(radial, (int)Math.Floor(radialX + dx), (int)Math.Floor(radialY + dy)) != 0)
                            covered++;

                    int coverage = covered * 255 / 4;
                    int opacity = maskAlpha * coverage / 255;
                    if (opacity == 0) continue;

                    double shade = BilinearAlpha(radial, radialX, radialY) / 255;
                    int green = (int)Math.Round(80 + 175 * shade);
                    int blue = (int)Math.Round(40 + 62 * shade);
                    fill.SetPixel(x, y, Color.FromArgb(opacity, 0, green, blue));
                }
            }
            fill.Save(outputPath, ImageFormat.Png);
        }
    }

    private static int AlphaAt(Bitmap bitmap, int x, int y)
    {
        return x < 0 || y < 0 || x >= bitmap.Width || y >= bitmap.Height
            ? 0 : bitmap.GetPixel(x, y).A;
    }

    private static double BilinearAlpha(Bitmap bitmap, double x, double y)
    {
        x -= 0.5;
        y -= 0.5;
        int left = (int)Math.Floor(x);
        int top = (int)Math.Floor(y);
        double fx = x - left;
        double fy = y - top;
        return (1 - fy) * ((1 - fx) * AlphaAt(bitmap, left, top) + fx * AlphaAt(bitmap, left + 1, top))
             + fy * ((1 - fx) * AlphaAt(bitmap, left, top + 1) + fx * AlphaAt(bitmap, left + 1, top + 1));
    }
}
