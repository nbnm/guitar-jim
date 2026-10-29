#!/bin/zsh
set -euo pipefail
task_root="${0:A:h:h}"
source_image="$task_root/Sources/GuitarPractice/Resources/jimmy-page-logo.png"
iconset="$task_root/build/AppIcon.iconset"
mkdir -p "$iconset" "$task_root/Assets"
# Mechanical resizing only; the original generated illustration is preserved.
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source_image" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" "$source_image" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$task_root/Assets/AppIcon.icns"
print "Built $task_root/Assets/AppIcon.icns"
