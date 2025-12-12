from ultralytics import YOLO
import cv2
from pathlib import Path

# Зміни шлях на свій
MODEL_PATH = "best.pt"
IMAGE_DIR = Path("dataset/day")  # твоя папка з фото

model = YOLO(MODEL_PATH)

for img_path in IMAGE_DIR.glob("*.jpg"):
    results = model(img_path)
    print(f"📸 {img_path.name}")
    results[0].show()  # покаже з вікном OpenCV
