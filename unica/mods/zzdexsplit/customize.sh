# Moves classes out of framework.jar's (full) classes.dex into a new dex, AFTER all other mods/patches,
# so adding method ids (patches) does not overflow the 65536 limit ("Unsigned short value out of range").
# Never touches classes that any patch / SMALI_PATCH in this source tree refers to.
# Disable: create an empty file named "disable" in this module folder.
FW_DIR="$APKTOOL_DIR/system/framework/framework.jar"
DECODE_APK "system" "system/framework/framework.jar"

if [ ! -d "$FW_DIR/smali" ]; then
    LOGW "framework.jar smali not found, dex split skipped"
else
    ZD_EX="$(mktemp)"
    # classes mentioned anywhere in the source tree as smali/<path>.smali (patches, customize.sh) are protected
    grep -rhoE "smali/[A-Za-z0-9_/\$-]+\.smali" "$SRC_DIR/unica" "$SRC_DIR/scripts" 2> /dev/null \
        | sed -E 's#^smali/##; s#\.smali$##' | sort -u > "$ZD_EX"
    LOG "- Splitting framework.jar classes.dex (move classes to a new dex)"
    if ! python3 "$MODPATH/split.py" "$FW_DIR" "$ZD_EX" 6000; then
        LOGW "dex split failed, framework.jar left unchanged"
    fi
    rm -f "$ZD_EX"
    unset ZD_EX
fi
unset FW_DIR
