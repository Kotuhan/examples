import os
import random
import json
from pathlib import Path
from tqdm import tqdm
import numpy as np
from PIL import Image
import coremltools as ct

# --- Конфіг ---
MODEL_PATH = Path("ScreenDetectorML.mlproj/ScreenBoundaryML.mlmodel")
DATASET_DIR = Path(".")  # ми вже в dataset/
OUTPUT_DIR = Path("DigitsDataset")
CATEGORIES = ["total", "day", "night"]

TRAIN_RATIO = 0.8  # 80% train, 20% validation

# --- Завантаження моделі ---
try:
    mlmodel = ct.models.MLModel(str(MODEL_PATH))
    print(f"✅ ML модель завантажено: {MODEL_PATH.name}")
except Exception as e:
    print(f"❌ Не вдалося завантажити ML модель: {e}")
    exit(1)

# --- Підготовка вихідних папок ---
for split in ["train", "validation"]:
    (OUTPUT_DIR / split).mkdir(parents=True, exist_ok=True)

annotations = {"train": [], "validation": []}

def crop_screen_region(image_path):
    """Використовує ML-модель для пошуку екрана"""
    image = Image.open(image_path).convert("RGB")
    w, h = image.size
    resized = image.resize((416, 416))

    preds = mlmodel.predict({
        "imagePath": resized,
        "iouThreshold": 0.3,
        "confidenceThreshold": 0.1,
    })

    coords = np.array(preds.get("coordinates"))
    conf = np.array(preds.get("confidence"))
    if coords.size == 0:
        return None

    best_idx = np.argmax(conf)
    x, y, width, height = coords[best_idx]

    left = int((x - width / 2) * w)
    top = int((y - height / 2) * h)
    right = int((x + width / 2) * w)
    bottom = int((y + height / 2) * h)

    expand = 20
    left, top = max(0, left - expand), max(0, top - expand)
    right, bottom = min(w, right + expand), min(h, bottom + expand)

    return image.crop((left, top, right, bottom))

# --- Основна логіка ---
for category in CATEGORIES:
    folder = DATASET_DIR / category
    if not folder.exists():
        continue

    images = list(folder.glob("*.jpg")) + list(folder.glob("*.jpeg")) + list(folder.glob("*.png"))
    random.shuffle(images)
    split_idx = int(len(images) * TRAIN_RATIO)
    train_imgs = images[:split_idx]
    val_imgs = images[split_idx:]

    for split, img_list in [("train", train_imgs), ("validation", val_imgs)]:
        for i, img_path in enumerate(tqdm(img_list, desc=f"{split} {category}")):
            cropped = crop_screen_region(img_path)
            if cropped is None:
                continue

            filename = f"{category}_{i:04d}.jpg"
            save_path = OUTPUT_DIR / split / filename
            cropped.save(save_path, quality=95)

            # Поки без тексту — додамо вручну пізніше
            annotations[split].append({"image": filename, "text": ""})

# --- Записуємо annotations.json ---
for split in ["train", "validation"]:
    with open(OUTPUT_DIR / split / "annotations.json", "w") as f:
        json.dump({"annotations": annotations[split]}, f, indent=2, ensure_ascii=False)

print(f"\n✅ Готово! Датасет збережено у {OUTPUT_DIR.resolve()}")
print("Тепер відкрий DigitsDataset у CreateML → Text Recognition Project")
