import json, sys, os

if len(sys.argv) < 2:
    print("Usage: python3 convert.py <annotation.json>")
    sys.exit(1)

input_path = sys.argv[1]
output_path = os.path.splitext(input_path)[0] + "_createML.json"

with open(input_path, "r") as f:
    data = json.load(f)

converted = []

for key, item in data.items():
    filename = item.get("filename") or key
    regions = item.get("regions") or {}

    if isinstance(regions, dict):
        regions = list(regions.values())

    anns = []
    for region in regions:
        shape = region.get("shape_attributes") or {}
        attrs = region.get("region_attributes") or {}
        label = attrs.get("label") or "screen"

        xs = shape.get("all_points_x")
        ys = shape.get("all_points_y")
        if not xs or not ys:
            continue

        # обчислюємо рамку (bounding box) із полігону
        x_min, x_max = min(xs), max(xs)
        y_min, y_max = min(ys), max(ys)
        w = x_max - x_min
        h = y_max - y_min

        anns.append({
            "label": label,
            "coordinates": {
                "x": x_min + w / 2,
                "y": y_min + h / 2,
                "width": w,
                "height": h
            }
        })

    if anns:
        converted.append({
            "image": filename,
            "annotations": anns
        })

with open(output_path, "w") as f:
    json.dump(converted, f, indent=2)

print(f"✅ Converted {len(converted)} images → {output_path}")
