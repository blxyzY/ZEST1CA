# Disable app compaction
# Guard the patch as the source firmware might have this already disabled
LOG "- Applying \"Disable app compaction\" to /system/system/framework/services.jar"
APPLY_PATCH "system" "system/framework/services.jar" \
    "$MODPATH/appcompactor/services.jar/0001-Disable-app-compaction.patch" &> /dev/null || true

# Show "Samsung DeX" in Settings (menu entry only).
# Wireless DeX over WFD additionally needs WFD blob/hex patches, which this module does NOT do.
# Disable: create an empty file named "disable" in this module folder.
DEX_APK="system/priv-app/SecSettings/SecSettings.apk"
DECODE_APK "system" "$DEX_APK"

DEX_ROOT="$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk"
DEX_SMALI="$(find "$DEX_ROOT" -type f -path "*/com/samsung/android/settings/multidevices/dex/DexModePreferenceController.smali" | head -n 1 || true)"

if [ -z "$DEX_SMALI" ]; then
    LOGW "DexModePreferenceController.smali not found, DeX menu patch skipped"
else
    DEX_REL="${DEX_SMALI#"$DEX_ROOT"/}"
    SMALI_PATCH "system" "$DEX_APK" "$DEX_REL" "return" \
        'getAvailabilityStatus()I' \
        '0'
    unset DEX_REL
fi
unset DEX_APK DEX_ROOT DEX_SMALI
