import os
from PySide6.QtGui import QImage, QPainter, QColor
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtCore import QRectF, QByteArray
from PIL import Image

def generate_ico():
    svg_path = os.path.abspath("assets/icons/icon.svg")
    # Monochrome SVG content
    svg_content = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="100%" height="100%">
  <defs>
    <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#181818" />
      <stop offset="100%" stop-color="#0E0E0E" />
    </linearGradient>
  </defs>
  <circle cx="256" cy="256" r="240" fill="url(#bgGrad)" />
  <g stroke="#FFFFFF" stroke-linecap="round" fill="none">
    <path d="M 256 90 A 166 166 0 0 1 422 256" stroke-width="38" />
    <path d="M 256 150 A 106 106 0 0 1 362 256" stroke-width="36" />
    <path d="M 256 422 A 166 166 0 0 1 90 256" stroke-width="38" />
    <path d="M 256 362 A 106 106 0 0 1 150 256" stroke-width="36" />
  </g>
  <path d="M 232 200 C 232 192 242 186 250 192 L 306 238 C 314 244 314 256 306 262 L 250 308 C 242 314 232 308 232 300 Z" fill="#FFFFFF" />
</svg>"""

    # First write the monochrome icon.svg
    with open("assets/icons/icon.svg", "w", encoding="utf-8") as f:
        f.write(svg_content)
    print("Updated assets/icons/icon.svg to monochrome Black & White.")

    renderer = QSvgRenderer(QByteArray(svg_content.encode("utf-8")))
    if not renderer.isValid():
        raise RuntimeError("Failed to parse SVG")

    sizes = [16, 24, 32, 48, 64, 128, 256]
    pil_images = []

    for sz in sizes:
        qimg = QImage(sz, sz, QImage.Format_ARGB32_Premultiplied)
        qimg.fill(QColor(0, 0, 0, 0))
        p = QPainter(qimg)
        p.setRenderHint(QPainter.Antialiasing, True)
        p.setRenderHint(QPainter.SmoothPixmapTransform, True)
        renderer.render(p, QRectF(0, 0, sz, sz))
        p.end()

        # Convert QImage to PIL Image
        # QImage format ARGB32_Premultiplied -> RGBA
        qimg_converted = qimg.convertToFormat(QImage.Format_RGBA8888)
        width = qimg_converted.width()
        height = qimg_converted.height()
        ptr = qimg_converted.bits()
        # Create PIL Image from bytes
        bytes_per_line = qimg_converted.bytesPerLine()
        raw_bytes = bytes(ptr)
        pil_img = Image.frombytes("RGBA", (width, height), raw_bytes, "raw", "RGBA", bytes_per_line, 1)
        pil_images.append(pil_img)

    # Save multi-resolution ICO
    ico_path = os.path.abspath("assets/icons/app.ico")
    pil_images[-1].save(
        ico_path,
        format="ICO",
        sizes=[(img.width, img.height) for img in pil_images],
        append_images=pil_images[:-1]
    )
    print(f"Generated {ico_path} with sizes: {sizes}")

if __name__ == "__main__":
    generate_ico()
