echo "Fix up /product/etc/build.prop"
sed -i "/# Removed by /d" "$WORK_DIR/product/etc/build.prop" \
    && sed -i "s/#bluetooth./bluetooth./g" "$WORK_DIR/product/etc/build.prop" \
    && sed -i "s/?=/=/g" "$WORK_DIR/product/etc/build.prop" \
    && sed -i "$(sed -n "/provisioning.hostname/=" "$WORK_DIR/product/etc/build.prop" | sed "2p;d")d" "$WORK_DIR/product/etc/build.prop"

LOG_STEP_IN "- Enabling ZRAM Configuration"
SET_PROP "vendor" "ro.config.zram.enabled" "true"
SET_PROP "vendor" "ro.zram.mark_idle_delay_mins" "60"
SET_PROP "vendor" "ro.zram.first_wb_delay_mins" "1440"
LOG_STEP_OUT

LOG_STEP_IN "- Enabling Vulkan"
SET_PROP "vendor" "ro.hwui.use_vulkan" "true"
SET_PROP "vendor" "debug.hwui.use_hint_manager" "true"
LOG_STEP_OUT

LOG_STEP_IN "- Enabling RAM Plus Floating Feature"
# Find floating_feature.xml anywhere in the ROM and patch it
find "$WORK_DIR" -name "floating_feature.xml" -type f | while read xml; do
    LOG "  - Patching: $xml"
    sed -i 's/SEC_FLOATING_FEATURE_COMMON_SUPPORT_RAM_PLUS>FALSE/SEC_FLOATING_FEATURE_COMMON_SUPPORT_RAM_PLUS>TRUE/g' "$xml"
    sed -i 's/SEC_FLOATING_FEATURE_COMMON_SUPPORT_RAM_PLUS>false/SEC_FLOATING_FEATURE_COMMON_SUPPORT_RAM_PLUS>TRUE/g' "$xml"
done
LOG_STEP_OUT

LOG_STEP_IN "- wifi+security Prop"
SET_PROP "vendor" "wlan.wfd.hdcp" "disabled"
SET_PROP "vendor" "wifi.interface" "wlan0"
SET_PROP "vendor" "ro.security.vaultkeeper.native" "0"
SET_PROP "vendor" "ro.security.vaultkeeper.feature" "0"
LOG_STEP_OUT

if [ -f "$WORK_DIR/vendor/ueventd.rc" ]; then
    LOG "- Moving legacy vendor ueventd configuration to vendor/etc"
    mkdir -p "$WORK_DIR/vendor/etc"
    cp -a "$WORK_DIR/vendor/ueventd.rc" "$WORK_DIR/vendor/etc/ueventd.rc" || return 1
    SET_METADATA "vendor" "etc/ueventd.rc" 0 0 644 "u:object_r:vendor_configs_file:s0" || return 1
    DELETE_FROM_WORK_DIR "vendor" "ueventd.rc" || return 1
elif [ ! -f "$WORK_DIR/vendor/etc/ueventd.rc" ]; then
    ABORT "Target vendor has no ueventd.rc to migrate"
    return 1
fi
