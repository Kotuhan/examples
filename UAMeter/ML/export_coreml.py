from ultralytics import YOLO

# Завантажуємо натреновану модель
model = YOLO("runs/detect/train_digits/weights/best.pt")

# Експортуємо в CoreML
model.export(format="coreml", imgsz=416)
