"""Genera el logo de GunaYala Ride: marca tipo InDrive, geométrica y nítida.
Dibuja en 1024px y baja a cadadensidad de mipmap con LANCZOS.
"""
from PIL import Image, ImageDraw, ImageFilter

S = 1024
CIAN = (0, 168, 198)
CIAN_OSC = (0, 105, 124)
CORAL = (209, 73, 91)
BLANCO = (255, 255, 255)


def gradiente(tl, br):
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        for_x = y / (S - 1)
        d.line([(0, y), (S, y)], fill=None)
    # interpolacion simple por columnas
    px = img.load()
    for y in range(S):
        fy = y / (S - 1)
        for x in range(S):
            fx = x / (S - 1)
            t = (fx + fy) / 2
            px[x, y] = tuple(int(tl[i] + (br[i] - tl[i]) * t) for i in range(3))
    return img


def squircle_mask(radius=232):
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=radius, fill=255)
    return mask


def poligono_carbon(d, puntos, radio=26, samples=14):
    """Rellena un poligono con esquinas redondeadas (muestreo por slicing)."""
    n = len(puntos)
    for i in range(n):
        a = puntos[(i - 1) % n]
        b = puntos[i]
        c = puntos[(i + 1) % n]
        for k in range(samples + 1):
            t = k / samples
            p1 = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            p2 = (b[0] + (c[0] - b[0]) * t, b[1] + (c[1] - b[1]) * t)
            r = radio * (1 - abs(t - 0.5) * 2) ** 0.5
            d.line([p1, p2], fill=BLANCO, width=max(1, int(r)))
            d.ellipse(
                [p2[0] - r / 2, p2[1] - r / 2, p2[0] + r / 2, p2[1] + r / 2], fill=BLANCO
            )


def carro(d):
    # carrocería baja
    d.rounded_rectangle((132, 486, 892, 662), radius=74, fill=BLANCO)
    # techo / cabina
    cabina = [(286, 500), (372, 372), (642, 372), (740, 500)]
    for i in range(len(cabina)):
        a = cabina[(i - 1) % len(cabina)]
        b = cabina[i]
        c = cabina[(i + 1) % len(cabina)]
        for k in range(13):
            t = k / 12
            p1 = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            p2 = (b[0] + (c[0] - b[0]) * t, b[1] + (c[1] - b[1]) * t)
            r = 26 * (1 - abs(t - 0.5) * 2) ** 0.5
            d.line([p1, p2], fill=BLANCO, width=max(1, int(r)))
    # ventanas en tono oscuro
    d.polygon([(352, 480), (410, 404), (604, 404), (664, 480)], fill=CIAN_OSC)
    d.line([(512, 404), (512, 480)], fill=BLANCO, width=16)
    # faros
    d.ellipse((806, 500, 878, 572), fill=CIAN)
    d.ellipse((146, 500, 218, 572), fill=CORAL)
    # ruedas
    for cx in (312, 712):
        d.ellipse((cx - 92, 596, cx + 92, 780), fill=BLANCO)
        d.ellipse((cx - 38, 650, cx + 38, 726), fill=CIAN_OSC)
    # linea de carretera
    d.rounded_rectangle((232, 812, 792, 856), radius=22, fill=CORAL)


def main():
    base = gradiente(CIAN, CIAN_OSC)
    capa = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    carro(ImageDraw.Draw(capa))
    base = base.convert("RGBA")
    base.alpha_composite(capa)

    out = base.copy()
    out.putalpha(squircle_mask())
    out.save("assets/images/logo.png")

    limpio = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    limpio.alpha_composite(capa)
    limpio.save("assets/images/logo-marca.png")

    for nombre, lado in [
        ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192),
    ]:
        dst = f"android/app/src/main/res/mipmap-{nombre}/ic_launcher.png"
        out.resize((lado, lado), Image.LANCZOS).save(dst)

    for lado in (512, 192, 96):
        limpio.resize((lado, lado), Image.LANCZOS).save(
            f"assets/images/logo-{lado}.png"
        )
    print("listo")


if __name__ == "__main__":
    main()