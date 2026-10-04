#!/usr/bin/env python3
"""Pick a local image from a widget's configured folder."""
import json
import os
from pathlib import Path
import random
import sys
from urllib.parse import unquote, urlsplit

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".svg", ".avif", ".tif", ".tiff"}


def pick_image(source, previous=""):
    result = {"source": source, "image": "", "error": ""}
    try:
        url = urlsplit(source)
        if url.scheme != "file" or url.netloc not in ("", "localhost"):
            raise ValueError("Choose a local folder")
        folder = Path(unquote(url.path))
        if not folder.is_dir():
            raise ValueError("Folder is unavailable")
        images = []
        def unreadable(error):
            if Path(error.filename) == folder:
                raise error
        for base, _, files in os.walk(folder, onerror=unreadable):
            for name in files:
                path = Path(base) / name
                if path.suffix.lower() in EXTENSIONS and path.is_file():
                    images.append(path.as_uri())
        if images:
            choices = [image for image in images if image != previous]
            result["image"] = random.choice(choices or images)
        else:
            result["error"] = "No images in this folder"
    except (OSError, ValueError) as error:
        result["error"] = str(error) if isinstance(error, ValueError) else "Cannot read this folder"
    return result


if __name__ == "__main__":
    print(json.dumps(pick_image(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "")))
