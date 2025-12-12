# ML-1-convert-yolo-to-xcode — конвертувати YOLO для iOS

## Задача
Конвертувати натреновану модель з `ML/runs/detect/train_digits` у CoreML/банндл, придатний для використання в iOS, і покласти артефакт до `iOS/UAMeter/Models`.

## Очікуваний результат
- У `iOS/UAMeter/Models` лежить готовий `.mlmodel` (та/або `.mlmodelc`), згенерований з `ML/runs/detect/train_digits/weights/best.pt`.
- Опис коротких кроків, які виконані/потрібні (експорт, перевірка, копіювання у Xcode target).
