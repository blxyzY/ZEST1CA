# Show battery regulatory info in Settings
# Requires SEM_BATTERY_PROPERTY_IC_AUTHENTICATION_RESULT support
if [ "$(GET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_SETTINGS")" ]; then
    SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_SETTINGS" --delete
fi
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_SETTINGS_ENABLE_EU_BATTERY_REGULATORY" "TRUE"

SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali/android/app/Instrumentation.smali" "replace" \
    'newApplication(Ljava/lang/Class;Landroid/content/Context;)Landroid/app/Application;' \
    'invoke-virtual {p0, p1}, Landroid/app/Application;->attach(Landroid/content/Context;)V' \
    '    invoke-virtual {p0, p1}, Landroid/app/Application;->attach(Landroid/content/Context;)V\n\n    invoke-static {p1}, Lio/mesalabs/unica/SamsungPropsHooks;->init(Landroid/content/Context;)V' \
    > /dev/null
SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali/android/app/Instrumentation.smali" "replace" \
    'newApplication(Ljava/lang/ClassLoader;Ljava/lang/String;Landroid/content/Context;)Landroid/app/Application;' \
    'invoke-virtual {p0, p3}, Landroid/app/Application;->attach(Landroid/content/Context;)V' \
    '    invoke-virtual {p0, p3}, Landroid/app/Application;->attach(Landroid/content/Context;)V\n\n    invoke-static {p3}, Lio/mesalabs/unica/SamsungPropsHooks;->init(Landroid/content/Context;)V' \
    > /dev/null

# Route SystemProperties.get through SamsungPropsHooks (Galaxy Store / apps device spoof)
SYSPROPS_SMALI="$(find "$APKTOOL_DIR/system/framework/framework.jar" -type f \
    -path '*/android/os/SystemProperties.smali' -printf '%P\n' -quit)"
[ "$SYSPROPS_SMALI" ] || ABORT "SystemProperties.smali not found"
if ! grep -q "SamsungPropsHooks;->onSystemPropertiesGet" \
        "$APKTOOL_DIR/system/framework/framework.jar/$SYSPROPS_SMALI"; then
    SMALI_PATCH "system" "system/framework/framework.jar" \
        "$SYSPROPS_SMALI" "replace" \
        'get(Ljava/lang/String;)Ljava/lang/String;' \
        'invoke-static {p0}, Landroid/os/SystemProperties;->native_get(Ljava/lang/String;)Ljava/lang/String;' \
        '    invoke-static {p0}, Lio/mesalabs/unica/SamsungPropsHooks;->onSystemPropertiesGet(Ljava/lang/String;)Ljava/lang/String;\n\n    move-result-object v0\n\n    if-eqz v0, :cond_unica_spoof\n\n    return-object v0\n\n    :cond_unica_spoof\n    invoke-static {p0}, Landroid/os/SystemProperties;->native_get(Ljava/lang/String;)Ljava/lang/String;' \
        > /dev/null
    SMALI_PATCH "system" "system/framework/framework.jar" \
        "$SYSPROPS_SMALI" "replace" \
        'get(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;' \
        'invoke-static {p0, p1}, Landroid/os/SystemProperties;->native_get(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;' \
        '    invoke-static {p0}, Lio/mesalabs/unica/SamsungPropsHooks;->onSystemPropertiesGet(Ljava/lang/String;)Ljava/lang/String;\n\n    move-result-object v0\n\n    if-eqz v0, :cond_unica_spoof\n\n    return-object v0\n\n    :cond_unica_spoof\n    invoke-static {p0, p1}, Landroid/os/SystemProperties;->native_get(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;' \
        > /dev/null
fi

DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk"

DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk"
SECSETTINGS_APK="$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk"

# Disable stock OTA references
if [ ! -f "$WORK_DIR/system/system/priv-app/ChoiDujour/ChoiDujour.apk" ]; then
    SOFTWARE_UPDATE_UTILS="$(find "$SECSETTINGS_APK" \
        -type f -path '*/com/samsung/android/settings/softwareupdate/SoftwareUpdateUtils.smali' -printf '%P\n' -quit)"
    [ "$SOFTWARE_UPDATE_UTILS" ] || ABORT "SoftwareUpdateUtils.smali not found"
    if grep -q -F '.method public static isOTAUpgradeAllowed(Landroid/content/Context;)Z' \
            "$SECSETTINGS_APK/$SOFTWARE_UPDATE_UTILS"; then
        SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
            "$SOFTWARE_UPDATE_UTILS" "return" \
            'isOTAUpgradeAllowed(Landroid/content/Context;)Z' \
            'false'
    else
        SOFTWARE_UPDATE_CONTROLLER="$(find "$SECSETTINGS_APK" \
            -type f -path '*/com/samsung/android/settings/homepage/TopLevelSoftwareUpdatePreferenceController.smali' \
            -printf '%P\n' -quit)"
        [ "$SOFTWARE_UPDATE_CONTROLLER" ] || \
            ABORT "TopLevelSoftwareUpdatePreferenceController.smali not found"
        SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
            "$SOFTWARE_UPDATE_CONTROLLER" "return" \
            'getAvailabilityStatus()I' \
            '3'
    fi
    unset SOFTWARE_UPDATE_UTILS
fi

# Always show One UI minor version
ONEUI_VERSION_CONTROLLER="$(find "$SECSETTINGS_APK" -type f \
    -path '*/com/samsung/android/settings/deviceinfo/softwareinfo/OneUIVersionPreferenceController.smali' \
    -printf '%P\n' -quit)"
[ "$ONEUI_VERSION_CONTROLLER" ] || ABORT "OneUIVersionPreferenceController.smali not found"
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "$ONEUI_VERSION_CONTROLLER" "replace" \
    'isDeviceWithMicroVersion()Z' \
    'move-result p0' \
    'const/4 p0, 0x1'

# Show real device model number
MODEL_NAME_GETTER="$(find "$SECSETTINGS_APK" -type f \
    -path '*/com/samsung/android/settings/deviceinfo/aboutphone/ModelNameGetter.smali' \
    -printf '%P\n' -quit)"
[ "$MODEL_NAME_GETTER" ] || ABORT "ModelNameGetter.smali not found"
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "$MODEL_NAME_GETTER" "replace" \
    'getModelName()Ljava/lang/String;' \
    'ro.product.model' \
    'ro.boot.em.model'

LOG_STEP_IN "- Adding UN1CA Settings"

# Dynamically patch SecSettings
# - Add missing/non-xml files in place
# - Patch existing files
#   - Use the first line of the file to tell sed how to apply the rest of the content
#   - Exception made for files under *res/values* where the "resources" tag gets nuked
while IFS= read -r f; do
    f="${f//$MODPATH\/SecSettings.apk\//}"

    if [ ! -f "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f" ] || \
            [[ "$f" != *".xml" ]]; then
        LOG "- Adding \"$f\" to /system/system/priv-app/SecSettings.apk"
        EVAL "mkdir -p \"$(dirname "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f")\""
        EVAL "cp -a \"$MODPATH/SecSettings.apk/${f//\$/\\$}\" \"$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/${f//\$/\\$}\""
    else
        LOG "- Patching \"$f\" in /system/system/priv-app/SecSettings.apk"
        if [[ "$f" == *"res/values"* ]]; then
            PATCH_INST="/<\/resources>/i"
            CONTENT="$(sed -e "/?xml/d" -e "/resources>/d" "$MODPATH/SecSettings.apk/$f")"
        else
            PATCH_INST="$(head -n 1 "$MODPATH/SecSettings.apk/$f")"
            CONTENT="$(tail -n +2 "$MODPATH/SecSettings.apk/$f")"
        fi
        CONTENT="$(sed -e "s/\"/\\\\\"/g" -e "s/\\$/\\\\$/g" -e "s/ /\\\ /g" -e "s/\\\\n/\\\\\\\\\n/g" <<< "$CONTENT")"
        CONTENT="$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' <<< "$CONTENT")"
        EVAL "sed -i \"$PATCH_INST $CONTENT\" \"$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f\""
    fi
done < <(find "$MODPATH/SecSettings.apk" -type f)

DECODE_APK "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
LOG "- Patching \"smali_classes2/com/samsung/android/settings/intelligence/search/categorizing/TopLevelKeysCollector.smali\" in /system/system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
SMALI_PATCH "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" \
    "smali_classes2/com/samsung/android/settings/intelligence/search/categorizing/TopLevelKeysCollector.smali" "replace" \
    '<init>(Landroid/content/Context;)V' \
    '.locals 37' \
    '.locals 38' \
    > /dev/null
SMALI_PATCH "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" \
    "smali_classes2/com/samsung/android/settings/intelligence/search/categorizing/TopLevelKeysCollector.smali" "replace" \
    '<init>(Landroid/content/Context;)V' \
    'filled-new-array/range {v1 .. v36}, [Ljava/lang/String;' \
    '    const-string v37, "top_level_unica"\n\n    filled-new-array/range {v1 .. v37}, [Ljava/lang/String;' \
    > /dev/null

# Show Vulkan renderer toggle if required
if [[ "$(GET_PROP "ro.hwui.use_vulkan")" != "true" ]]; then
    SET_PROP "system" "persist.sys.unica.vulkan" "false"
fi

unset PATCH_INST CONTENT SECSETTINGS_APK
unset PATCH_INST CONTENT

LOG_STEP_OUT
