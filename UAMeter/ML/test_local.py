from ultralytics import YOLO
import cv2
from pathlib import Path

# --- Конфіг ---
MODEL_PATH = Path("runs/detect/train_digits/weights/best.pt")
TEST_DIR = Path("DigitsDataset/train")  # заміни на свій шлях

# --- Завантаження моделі ---
model = YOLO(str(MODEL_PATH))
print(f"✅ Модель завантажена: {MODEL_PATH}")

# --- Тестування на нових зображеннях ---
for img_path in TEST_DIR.glob("*.jpg"):
    results = model(img_path, conf=0.25)
    boxes = results[0].boxes
    print(f"\n📸 {img_path.name}: {len(boxes)} цифр знайдено")

    for box in boxes:
        cls = int(box.cls[0])
        conf = float(box.conf[0])
        print(f" → {cls} (conf={conf:.2f})")

    annotated = results[0].plot()
    cv2.imshow("Result", annotated)
    cv2.waitKey(5000)

cv2.destroyAllWindows()
print("\n✅ Тестування завершено.")
