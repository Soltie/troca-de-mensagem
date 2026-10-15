"""Gera o módulo RGBA a partir da textura otimizada, sem alterar a referência."""

import base64
from pathlib import Path

from PIL import Image


def main():
    root = Path(__file__).resolve().parents[2]
    texture = Image.open(root / "assets/ademir/face-128.png").convert("RGBA")
    width, height = texture.size
    encoded = base64.b64encode(texture.tobytes()).decode("ascii")
    lines = [
        "--!strict",
        "-- Dados RGBA do rosto fornecido pelo humano, tratado por imagegen e reduzido para 128 x 128.",
        "-- Gerado a partir de assets/ademir/face-128.png; sem upload ou dependência de asset externo.",
        "",
        "return table.freeze({",
        f"\tWidth = {width},",
        f"\tHeight = {height},",
        "\tRgbaBase64 = table.concat({",
    ]
    lines.extend(f'\t\t"{encoded[index:index + 96]}",' for index in range(0, len(encoded), 96))
    lines.extend(["\t}),", "})", ""])
    destination = root / "src/ReplicatedStorage/Client/Creature/AdemirFaceData.luau"
    destination.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"Baked {width}x{height} RGBA portrait: {destination}")


if __name__ == "__main__":
    main()
