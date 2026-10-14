using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Text;

public static class HandleFontAtlasBuilder
{
    private const int TileWidth = 128;
    private const int TileHeight = 64;
    private const int Columns = 8;
    private const int Rows = 13;

    public static void FromOtf(string fontPath, string outputPath)
    {
        using (var fonts = new PrivateFontCollection())
        {
            fonts.AddFontFile(fontPath);
            if (fonts.Families.Length == 0) throw new InvalidOperationException("The OTF font could not be loaded.");
            using (var font = new Font(fonts.Families[0], 44f, FontStyle.Regular, GraphicsUnit.Pixel))
            using (var sheet = new Bitmap(Columns * TileWidth, Rows * TileHeight, PixelFormat.Format32bppArgb))
            using (var graphics = Graphics.FromImage(sheet))
            using (var brush = new SolidBrush(Color.White))
            using (var format = (StringFormat)StringFormat.GenericTypographic.Clone())
            {
                graphics.Clear(Color.Transparent);
                graphics.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
                format.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces;
                for (int value = 0; value <= 100; value++)
                {
                    string text = value.ToString(System.Globalization.CultureInfo.InvariantCulture);
                    float[] advances = new float[text.Length];
                    float width = 0;
                    float height = 0;
                    for (int i = 0; i < text.Length; i++)
                    {
                        SizeF glyphSize = graphics.MeasureString(text[i].ToString(), font, int.MaxValue, format);
                        advances[i] = glyphSize.Width;
                        width += glyphSize.Width;
                        height = Math.Max(height, glyphSize.Height);
                    }
                    const float tracking = -2f; // One logical pixel closer after 2x reduction.
                    width += tracking * (text.Length - 1);
                    float x = (value % Columns) * TileWidth + (TileWidth - width) / 2;
                    float y = (value / Columns) * TileHeight + (TileHeight - height) / 2 - 3f;
                    for (int i = 0; i < text.Length; i++)
                    {
                        graphics.DrawString(text[i].ToString(), font, brush, x, y, format);
                        x += advances[i] + tracking;
                    }
                }
                sheet.Save(outputPath, ImageFormat.Png);
            }
        }
    }
}
