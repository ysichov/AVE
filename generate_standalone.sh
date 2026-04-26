#!/usr/bin/env bash
set -e

AVE_SRC="/c/soft/GitHub/AVE/src"
TARGET_SRC="/c/soft/GitHub/src"
TARGET_DIR="/c/soft/GitHub"

echo "Copying src files..."
mkdir -p "$TARGET_SRC"
cp "$AVE_SRC"/* "$TARGET_SRC/"

echo "Removing standalone files from target src..."
rm -f "$TARGET_SRC/z_ave_standalone.prog.abap"
rm -f "$TARGET_SRC/z_ave_standalone.prog.xml"

echo "Running abapmerge..."
cd "$TARGET_DIR"
abapmerge -f src/z_ave.prog.abap -o z_ave_standalone.prog.abap

echo "Copying result back to AVE/src..."
cp "$TARGET_DIR/z_ave_standalone.prog.abap" "$AVE_SRC/z_ave_standalone.prog.abap"

echo "Restoring header comments..."
# Extract comment/blank lines from z_ave.prog.abap after line 1, stop at first code line
header=$(awk 'NR==1{next} /^[[:space:]]*($|")/{print; next} {exit}' "$AVE_SRC/z_ave.prog.abap")
# Insert header between line 1 and the rest of standalone
{ head -1 "$AVE_SRC/z_ave_standalone.prog.abap"; echo "$header"; tail -n +2 "$AVE_SRC/z_ave_standalone.prog.abap"; } \
  > /tmp/z_ave_standalone_fixed.abap
cp /tmp/z_ave_standalone_fixed.abap "$AVE_SRC/z_ave_standalone.prog.abap"

echo "Done."
