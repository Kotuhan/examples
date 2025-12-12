# План виконання (ML-1-convert-yolo-to-xcode)

## Варіант A (Python/Ultralytics)
- [ ] Експорт `runs/detect/train_digits/weights/best.pt` у CoreML через `export_coreml.py` (або `yolo export ... format=coreml imgsz=416`).
- [ ] Перевірити класи/виходи у згенерованому `.mlmodel` (names, input shape).
- [ ] Скопіювати `.mlmodel` до `iOS/UAMeter/Models`, додати в Xcode target (Copy Bundle Resources).
- [ ] Протестувати на пристрої або симуляторі (за наявності моків).

## Варіант B (Direct coremltools)
- [ ] Завантажити `best.pt`, конвертувати через `coremltools.convert` з явно заданими `class_labels`.
- [ ] Опціонально оптимізувати (fp16, compute units).
- [ ] Перевірити виходи, додати до `iOS/UAMeter/Models` і Xcode.
- [ ] Швидкий smoke-тест у Swift (init моделі, прогнати один скоуп).

## Варіант C (Xcode integration first)
- [ ] Додати `.pt` у проєкт і використати Xcode conversion pipeline (Create ML/Model Compiler).
- [ ] Валідувати в Xcode Preview/Playground.
- [ ] Замінити артефакт у `Models`, оновити код на нову назву класу/виходу.
- [ ] Перевірити бандл і розмір.
