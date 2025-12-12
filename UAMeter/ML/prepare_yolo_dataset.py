import shutil
from pathlib import Path
import random
from tqdm import tqdm
import yaml

# --- Конфіг ---
SOURCE_DIR = Path("DigitsDataset")
OUTPUT_DIR = Path("digits")
TRAIN_RATIO = 0.8

# --- Створюємо структуру
for sub in ["images/train", "images/val", "labels/train", "labels/val"]:
    (OUTPUT_DIR / sub).mkdir(parents=True, exist_ok=True)

# --- Збираємо всі зображення
all_images = list((SOURCE_DIR / "train").glob("*.jpg")) + list((SOURCE_DIR / "validation").glob("*.jpg"))
random.shuffle(all_images)
split_idx = int(len(all_images) * TRAIN_RATIO)

train_imgs = all_images[:split_idx]
val_imgs = all_images[split_idx:]

# --- Копіюємо
def copy_images(img_list, split):
    for img in tqdm(img_list, desc=f"Copying {split}"):
        shutil.copy(img, OUTPUT_DIR / f"images/{split}" / img.name)
        # Створюємо порожній YOLO-label файл
        (OUTPUT_DIR / f"labels/{split}" / img.with_suffix('.txt').name).touch()

copy_images(train_imgs, "train")
copy_images(val_imgs, "val")

# --- YAML-файл
data_yaml = {
    "path": str(OUTPUT_DIR.resolve()),
    "train": "images/train",
    "val": "images/val",
    "nc": 10,
    "names": [str(i) for i in range(10)]
}

with open(OUTPUT_DIR / "digits.yaml", "w") as f:
    yaml.dump(data_yaml, f, sort_keys=False)

print("\n✅ YOLO датасет готовий у:", OUTPUT_DIR.resolve())
print("   → images/train, images/val, labels/train, labels/val")
print("   → файл конфігурації: digits.yaml")
print("\nТепер відкрий папку 'digits' у LabelImg або Roboflow і розміть цифри 0-9.")
