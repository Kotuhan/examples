import shutil
from pathlib import Path
import random
from tqdm import tqdm

BASE = Path("downloaded")
IMG_DIR = BASE / "train" / "images"
LBL_DIR = BASE / "train" / "labels"

VAL_RATIO = 0.2

# Нові директорії
VAL_IMG_DIR = BASE / "valid" / "images"
VAL_LBL_DIR = BASE / "valid" / "labels"

for d in [VAL_IMG_DIR, VAL_LBL_DIR]:
    d.mkdir(parents=True, exist_ok=True)

images = list(IMG_DIR.glob("*.jpg")) + list(IMG_DIR.glob("*.png"))
random.shuffle(images)
split = int(len(images) * (1 - VAL_RATIO))

for img in tqdm(images[split:], desc="Moving val images"):
    lbl = LBL_DIR / (img.stem + ".txt")
    if lbl.exists():
        shutil.move(str(img), VAL_IMG_DIR)
        shutil.move(str(lbl), VAL_LBL_DIR)

print("✅ Dataset split complete!")
print(f"Train images: {split}, Val images: {len(images) - split}")