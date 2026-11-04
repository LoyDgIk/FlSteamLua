"""Rasterize the original geometric FL mark without external image assets."""

from pathlib import Path

from PIL import Image, ImageDraw


def main():
    project = Path(__file__).resolve().parent.parent
    size = 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", image.size)
    ImageDraw.Draw(mask).rounded_rectangle((32, 32, 992, 992), radius=248, fill=255)
    start, end = (13, 68, 68), (23, 125, 115)
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            fraction = (x + y) / (2 * (size - 1))
            pixels[x, y] = tuple(round(a + (b - a) * fraction) for a, b in zip(start, end)) + (255,)
    image.putalpha(mask)
    draw = ImageDraw.Draw(image)
    draw.polygon([(x * 4, y * 4) for x, y in [
        (65, 65), (139, 65), (139, 90), (92, 90), (92, 116),
        (132, 116), (132, 140), (92, 140), (92, 191), (65, 191),
    ]], fill="#F5FFF4")
    draw.polygon([(x * 4, y * 4) for x, y in [
        (153, 65), (180, 65), (180, 166), (208, 166), (208, 191), (153, 191),
    ]], fill="#D9F178")
    target = project / "assets" / "branding"
    target.mkdir(parents=True, exist_ok=True)
    image.resize((256, 256), Image.Resampling.LANCZOS).save(target / "app.png")
    image.save(target / "app.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    (project / "windows" / "runner" / "resources" / "app_icon.ico").write_bytes((target / "app.ico").read_bytes())


if __name__ == "__main__":
    main()
