from ultralytics import YOLO

# Шлях до YAML (опису датасету)
DATASET_YAML = "./downloaded/data.yaml"  # заміни, якщо інше ім'я або розташування

# Базова модель (легка і швидко навчається)
MODEL = "yolov8n.pt"

# Тренування
model = YOLO(MODEL)
model.train(
    data=DATASET_YAML,
    epochs=100,
    imgsz=416,
    batch=16,
    device="mps",  # GPU, якщо є; або 'cpu'
    project="runs/detect",
    name="train_digits",
    exist_ok=True
)

print("✅ Навчання завершено! Модель збережена у runs/detect/train_digits/weights/best.pt")
