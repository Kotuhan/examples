# Codex helper for UAMeter

## Що це за проєкт
- Дві частини: `ML` (навчання моделей) та `iOS/UAMeter` (SwiftUI застосунок, що сканує екран електролічильника та витягує показники).
- Ціль: знайти рамку екрану, зробити OCR, класифікувати рядки у «сума/ніч/день/дата/час», показати та скопіювати їх у буфер.

## ML
- Стек: Python 3.11, Ultralytics YOLOv8, CoreML експорт.
- Основний пайплайн:
  - `prepare_yolo_dataset.py` — збирає датасет цифр (`DigitsDataset`) у формат YOLO, генерує `digits.yaml`.
  - `train.py` — тренує YOLOv8n на `downloaded/data.yaml` (замінити, якщо інший yaml), зберігає `runs/detect/train_digits/weights/best.pt`.
  - `export_coreml.py` — експортує `best.pt` у CoreML (створює `best.mlmodel` у підпапці `runs`).
  - Swift-скрипти `prepare_dataset.swift`/`train_digits.swift` — альтернативні утиліти для підготовки/тренування.
- Моделі в iOS:
  - `ScreenDetectorML.mlproj` → збірка CoreML, що знаходить рамку екрану (Vision Object Detection).
  - Друга модель для цифр — YOLO, експортується через `export_coreml.py`, потім додається в iOS таргет.
- Швидкі команди (з активованим venv):
  - `python prepare_yolo_dataset.py`
  - `python train.py`
  - `python export_coreml.py`
  - Тести/перевірки: `python test_local.py`, `python test_yolo_digits.py`

### Промпти для роботи з ML
- «Онови датасет/скрипт підготовки для YOLO, щоб підтримати клас …»
- «Проведи швидкий рев’ю гіперпараметрів train.py, порадь зміни для точності/швидкості на MPS».
- «Як правильно експортувати best.pt у CoreML і інтегрувати в iOS?»
- «Напиши інструкцію, як прогнати локальний inference на зображенні …»

## iOS / SwiftUI застосунок
- Вхідна точка: `iOS/UAMeter/UAMeterApp.swift` → `ContentView`.
- Камера: `CameraView` (UIViewRepresentable) конфігурує `AVCaptureSession`, отримує фрейми у `PreviewView`.
- Обробка:
  - `PreviewView` тримає `MeterScreenDetector`, який запускає CoreML (ScreenBoundaryML) і Vision OCR у рамці; колбек `onReadingDetected` повертає `MeterReading`.
  - `MeterDetector` — текстова логіка: шукає «gama100», коди `1580/1581/1582`, `kWh`, `2000imp`, дати (`092`) і час (`091`); нормалізує значення.
  - `MeterDigitsDetector` — Vision OCR у ROI, шар для роботи з `MeterDetector`.
- UI: `ContentView` показує картку камери, рядки для сума/ніч/день/дата; копіює всі показники в буфер; кнопка ліхтарика через `Notification.Name.toggleTorch`.
- Очікувані ресурси: CoreML моделі в бандлі (`ScreenBoundaryML`, модель цифр/екрана), камера, Vision.

### Промпти для роботи з iOS
- «Додай новий тип показника/екрану й адаптуй `MeterDetector`/UI».
- «Покращ UI/UX копіювання або індикатор стану OCR».
- «Інтегруй нову CoreML модель (назва файлу) в `MeterScreenDetector`/`MeterDigitsDetector`».
- «Напиши юніт-тести на парсинг `MeterDetector` для таких рядків…».
- «Оптимізуй роботу ліхтарика/камери під низьке освітлення».

## Як користуватися цим файлом
- Додавай нові сценарії/команди сюди, щоб Codex одразу мав контекст.
- Якщо міняєш шляхи до моделей чи датасету, зафіксуй нові шляхи й команди експорту.
