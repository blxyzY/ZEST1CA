LOG_STEP_IN "- Allowing mremap in vendor Codec2 seccomp policies"
C2_POLICY_FIRST=""
C2_POLICY_PATCHED=false
while IFS= read -r f; do
    [ -z "$C2_POLICY_FIRST" ] && C2_POLICY_FIRST="$f"
    if grep -q "^mremap:" "$f"; then
        sed -i 's/^mremap:.*/mremap: 1/' "$f"
        C2_POLICY_PATCHED=true
        LOG "- Relaxed mremap rule in $(basename "$f")"
    fi
done < <(find "$WORK_DIR/vendor/etc/seccomp_policy" -type f \( -iname "*c2*" -o -iname "*codec2*" \) 2> /dev/null)
if ! $C2_POLICY_PATCHED; then
    if [ -n "$C2_POLICY_FIRST" ]; then
        [ -n "$(tail -c1 "$C2_POLICY_FIRST")" ] && echo >> "$C2_POLICY_FIRST"
        echo "mremap: 1" >> "$C2_POLICY_FIRST"
        LOG "- Added mremap to $(basename "$C2_POLICY_FIRST")"
    else
        LOGW "No Codec2 seccomp policy found in vendor/etc/seccomp_policy"
    fi
fi
unset C2_POLICY_FIRST C2_POLICY_PATCHED
LOG_STEP_OUT

LOG_STEP_IN "- Removing 24-bit deep_buffer output (fixes no media sound on speaker)"
sed -i '/<mixPort name="deep_buffer"/,/<\/mixPort>/d' "$WORK_DIR/vendor/etc/audio_policy_configuration_base.xml"
sed -i 's/deep_buffer,//g' "$WORK_DIR/vendor/etc/audio_policy_configuration_base.xml"
LOG_STEP_OUT

# Multi-resolution SurfaceFlinger builds take the native panel density from
# ro.sf.init.lcd_density and fall back to 213 (tvdpi) when it is unset.
# FHD-only targets such as r8q never set it, so they report a 213 dpi
# (tablet-sized) display. Mirror ro.sf.lcd_density when it is missing.
LOG_STEP_IN "- Setting ro.sf.init.lcd_density"
LCD_DENSITY="$(GET_PROP "vendor" "ro.sf.lcd_density")"
[ "$LCD_DENSITY" ] || LCD_DENSITY="$(GET_PROP "odm" "ro.sf.lcd_density")"
if [ "$(GET_PROP "vendor" "ro.sf.init.lcd_density")" ] || [ "$(GET_PROP "odm" "ro.sf.init.lcd_density")" ]; then
    LOG "- ro.sf.init.lcd_density already set, skipping"
elif [ "$LCD_DENSITY" ]; then
    SET_PROP "vendor" "ro.sf.init.lcd_density" "$LCD_DENSITY"
else
    LOGW "- ro.sf.lcd_density not found, SurfaceFlinger will fall back to 213 dpi"
fi
unset LCD_DENSITY
LOG_STEP_OUT
