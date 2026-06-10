#!/usr/bin/env bash
set -e

AVE_SRC="/c/soft/GitHub/AVE/src"
TARGET_SRC="/c/soft/GitHub/observer_sa_src"
TARGET_DIR="/c/soft/GitHub"
OUTPUT_FILE="z_ave_observer_sa.prog.abap"

echo "Copying src files..."
rm -rf "$TARGET_SRC"
mkdir -p "$TARGET_SRC"
cp "$AVE_SRC"/*.abap "$TARGET_SRC/" 2>/dev/null || true
cp "$AVE_SRC"/*.xml  "$TARGET_SRC/" 2>/dev/null || true

echo "Removing files not needed as merge inputs..."
rm -f "$TARGET_SRC/z_ave_standalone.prog.abap"
rm -f "$TARGET_SRC/z_ave_standalone.prog.xml"
rm -f "$TARGET_SRC/z_ave_observer_sa.prog.abap"
rm -f "$TARGET_SRC/z_ave_observer_sa.prog.xml"
rm -f "$TARGET_SRC/z_ave.prog.abap"
rm -f "$TARGET_SRC/z_ave.prog.xml"

echo "Running abapmerge..."
cd "$TARGET_DIR"
abapmerge -f observer_sa_src/z_ave_observer.prog.abap -o "$OUTPUT_FILE"

echo "Renaming REPORT statement to Z_AVE_OBSERVER_SA..."
sed -i 's/^REPORT z_ave_observer\b/REPORT z_ave_observer_sa/' "$TARGET_DIR/$OUTPUT_FILE"

echo "Restoring header comments..."
header=$(awk 'NR==1{next} /^[[:space:]]*($|")/{print; next} {exit}' "$AVE_SRC/z_ave_observer.prog.abap")
{ head -1 "$TARGET_DIR/$OUTPUT_FILE"; echo "$header"; tail -n +2 "$TARGET_DIR/$OUTPUT_FILE"; } \
  > /tmp/z_ave_observer_sa_fixed.abap
cp /tmp/z_ave_observer_sa_fixed.abap "$TARGET_DIR/$OUTPUT_FILE"

echo "Copying result back to AVE/src..."
cp "$TARGET_DIR/$OUTPUT_FILE" "$AVE_SRC/$OUTPUT_FILE"

echo "Cleaning up temp folder..."
rm -rf "$TARGET_SRC"
rm -f  "$TARGET_DIR/$OUTPUT_FILE"

echo "Done. Result: $AVE_SRC/$OUTPUT_FILE"
