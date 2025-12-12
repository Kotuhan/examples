import os
import cv2
import numpy as np
from pathlib import Path
from PIL import Image
from tqdm import tqdm
import pytesseract
import coremltools as ct

# --- Конфіг ---
MODEL_PATH = Path("ScreenDetectorML.mlproj/ScreenBoundaryML.mlmodel")
DATASET_DIR = Path(".")  # ми вже у dataset/
DEBUG_DIR = Path("DebugOutput")
CATEGORIES = ["total", "day", "night"]

tess_config = r"--psm 6 -c tessedit_char_whitelist=0123456789."

# --- Завантаження моделі ---
try:
    mlmodel = ct.models.MLModel(str(MODEL_PATH))
    print(f"✅ ML модель завантажено: {MODEL_PATH.name}")
except Exception as e:
    print(f"❌ Не вдалося завантажити ML модель: {e}")
    exit(1)

# --- Папки ---
DEBUG_DIR.mkdir(exist_ok=True)
for cat in CATEGORIES:
    (DEBUG_DIR / cat).mkdir(parents=True, exist_ok=True)

# --- Функції ---
def crop_screen_region(image_path):
    """Знаходимо екран за допомогою ML-моделі"""
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
        return None, None

    best_idx = np.argmax(conf)
    x, y, width, height = coords[best_idx]

    left = int((x - width / 2) * w)
    top = int((y - height / 2) * h)
    right = int((x + width / 2) * w)
    bottom = int((y + height / 2) * h)

    expand = 20
    left, top = max(0, left - expand), max(0, top - expand)
    right, bottom = min(w, right + expand), min(h, bottom + expand)

    cropped = np.array(image)[top:bottom, left:right]
    return cropped, (left, top, right, bottom)

def extract_digits(image):
    """Розпізнає цифри"""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = cv2.convertScaleAbs(gray, alpha=1.5, beta=0)
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    data = pytesseract.image_to_data(thresh, output_type=pytesseract.Output.DICT, config=tess_config)
    digits = []
    for i, text in enumerate(data["text"]):
        text = text.strip()
        if text and all(ch.isdigit() for ch in text):
            x, y, w, h = data["left"][i], data["top"][i], data["width"][i], data["height"][i]
            digits.append((x, y, w, h, text))
    return digits

def draw_debug(original, box=None, digits=None):
    """Малює рамку і цифри"""
    debug_img = original.copy()
    if box:
        left, top, right, bottom = map(int, box)
        cv2.rectangle(debug_img, (left, top), (right, bottom), (0, 255, 0), 3)
    if digits:
        for (x, y, w, h, text) in digits:
            cv2.rectangle(debug_img, (x + box[0], y + box[1]), (x + box[0] + w, y + box[1] + h), (255, 255, 0), 2)
            cv2.putText(debug_img, text, (x + box[0], y + box[1] - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
    return debug_img

# --- Основна логіка ---
for category in CATEGORIES:
    folder = DATASET_DIR / category
    if not folder.exists():
        continue
    images = list(folder.glob("*.jpg")) + list(folder.glob("*.jpeg")) + list(folder.glob("*.png"))
    for img_path in tqdm(images, desc=f"Processing {category}"):
        orig = cv2.imread(str(img_path))
        if orig is None:
            continue

        cropped, box = crop_screen_region(img_path)
        if cropped is None:
            continue

        digits = extract_digits(cropped)
        debug_img = draw_debug(orig, box=box, digits=digits)
        cv2.imwrite(str(DEBUG_DIR / category / img_path.name), debug_img)

print(f"\n✅ Debug-версії збережені у {DEBUG_DIR.resolve()}")
