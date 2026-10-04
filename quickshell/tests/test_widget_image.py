import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "widget_image", Path(__file__).parents[1] / "bin/widget-image.py")
widget_image = importlib.util.module_from_spec(spec)
spec.loader.exec_module(widget_image)


class ImageFolderTests(unittest.TestCase):
    def test_nested_images_and_encoded_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp) / "photos # % café"
            nested = folder / "nested"
            nested.mkdir(parents=True)
            image = nested / "one # %.PNG"
            image.touch()
            (folder / "notes.txt").touch()
            result = widget_image.pick_image(folder.as_uri())
            self.assertEqual(result["image"], image.as_uri())
            self.assertEqual(result["error"], "")
            self.assertEqual(result["source"], folder.as_uri())

    def test_rotation_avoids_previous_image(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            first = folder / "first.jpg"
            second = folder / "second.webp"
            first.touch()
            second.touch()
            self.assertEqual(widget_image.pick_image(folder.as_uri(), first.as_uri())["image"], second.as_uri())
            second.unlink()
            self.assertEqual(widget_image.pick_image(folder.as_uri(), first.as_uri())["image"], first.as_uri())

    def test_empty_and_missing_folders(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            self.assertEqual(widget_image.pick_image(folder.as_uri())["error"], "No images in this folder")
            self.assertEqual(widget_image.pick_image((folder / "missing").as_uri())["error"], "Folder is unavailable")

    def test_remote_sources_are_rejected(self):
        for url in ["https://example.com/photos", "file://remote/photos"]:
            self.assertEqual(widget_image.pick_image(url)["error"], "Choose a local folder")


if __name__ == "__main__":
    unittest.main()
