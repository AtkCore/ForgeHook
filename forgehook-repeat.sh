#!/bin/bash

# Receive VMID and PHASE from arguments
VMID="$1"
PHASE="$2"

# Path VMID config
CONF="/etc/pve/qemu-server/${VMID}.conf"

# Path preset
HWID_PATH="/var/lib/vz/snippets/log-hook/hwid-spoofer/hwid-${VMID}"

# Function Random
randstr() { tr -dc A-Za-z0-9 </dev/urandom | head -c "$1"; }  # สุ่มตัวอักษร a-z A-Z 0-9
randnum() { tr -dc 0-9 </dev/urandom | head -c "$1"; }        # สุ่มตัวเลข
randuuid() { cat /proc/sys/kernel/random/uuid; }              # สุ่ม UUID

# Function Random MAC Address Intel E1000
rand_mac_e1000() {
    OUI_LIST=(
        "00:13:20"  # Intel PRO/1000 MT
        "00:1B:21"  # Intel PRO/1000 GT
        "00:1C:C0"  # Intel PRO/1000 MT PCIe
        "00:0E:0C"  # Intel PRO/1000 PT
    )

    OUI=${OUI_LIST[$RANDOM % ${#OUI_LIST[@]}]}

    # สุ่ม 3 byte ท้าย
    B1=$(printf '%02X' $((RANDOM % 256)))
    B2=$(printf '%02X' $((RANDOM % 256)))
    B3=$(printf '%02X' $((RANDOM % 256)))

    echo "$OUI:$B1:$B2:$B3"
}

# Random Serial SSD/M.2
rand_ssd_serial() {
    case $((RANDOM % 6)) in
        0) echo "S$(randstr 19 | tr '[:lower:]' '[:upper:]')" ;;  # Samsung
        1) echo "BT$(randstr 18 | tr '[:lower:]' '[:upper:]')" ;;  # Kingston
        2) echo "WCC$(randstr 17 | tr '[:lower:]' '[:upper:]')" ;;  # Western Digital
        3) echo "5002$(randnum 16)" ;;  # Crucial
        4) echo "ZHB$(randstr 17 | tr '[:lower:]' '[:upper:]')" ;;  # Intel
        5) echo "0025B5$(randnum 14)" ;;  # SanDisk
    esac
}

if [[ "$PHASE" == "pre-start" ]]; then

    # Create Folder hwid-spoofer
    mkdir -p /var/lib/vz/snippets/log-hook/hwid-spoofer/
    OLD_PRESET=""
    [[ -f "$HWID_PATH" ]] && OLD_PRESET=$(cat "$HWID_PATH")

    # Random Mainboard
    PRESETS=(
        "ASUS X99-E WS|American Megatrends Inc.|3501"
        "Supermicro X10SRL-F|Supermicro|3.1"
        "ASRock X99 WS-E/10G|American Megatrends Inc.|P3.40"
        "MSI X99A WORKSTATION|American Megatrends Inc.|7885v18"
        "Gigabyte GA-X99-UD7 WIFI|American Megatrends Inc.|F23"
    )

    while true; do
        NEW_PRESET="${PRESETS[$RANDOM % ${#PRESETS[@]}]}"
        [[ "$NEW_PRESET" != "$OLD_PRESET" ]] && break
    done

    # Random Bios
    MBD_NAME=$(echo "$NEW_PRESET" | cut -d '|' -f 1)
    BIOS_VENDOR=$(echo "$NEW_PRESET" | cut -d '|' -f 2)
    BIOS_VERSION=$(echo "$NEW_PRESET" | cut -d '|' -f 3)

    # Random Memory
    RAM_BRANDS=("Samsung" "Corsair" "Kingston" "Crucial")
    RAM_SPEEDS=(2133 2400 2666)
    RAM_SIZES=(16 32 64)
    RAM_BRAND=${RAM_BRANDS[$RANDOM % ${#RAM_BRANDS[@]}]}
    RAM_SPEED=${RAM_SPEEDS[$RANDOM % ${#RAM_SPEEDS[@]}]}
    RAM_SIZE=${RAM_SIZES[$RANDOM % ${#RAM_SIZES[@]}]}
    RAM_SERIAL=$(randstr 8)
    RAM_PART="M$(randnum 3)A${RAM_SPEED}X$(randnum 4)-${RAM_BRAND^^}"
    ASSET_RAM="ASSET$(randnum 5)"

    # Random BIOS UUID
    UUID=$(randuuid)
    SERIAL_MB=$(randstr 10)
    SERIAL_CPU=$(randstr 10)
    SERIAL_SYS=$(randstr 12)

    # Add args in VMID.conf
    sed -i '/^args:/d' "$CONF"
    ARGS="-acpitable file=/root/ssdt.aml -acpitable file=/root/ssdt-ec.aml -acpitable file=/root/hpet.aml"
    ARGS+=" -cpu host,hypervisor=off,vmware-cpuid-freq=false,enforce=false,host-phys-bits=true"
    ARGS+=" -smbios type=0,vendor=\"$BIOS_VENDOR\",version=2.10,date='03/06/2024'"
    ARGS+=" -smbios type=1,manufacturer=\"${MBD_NAME%% *}\",product=\"$MBD_NAME\",version=$BIOS_VERSION,serial=\"$SERIAL_SYS\",sku=\"X99SKU\",family=\"X99FAMILY\""
    ARGS+=" -smbios type=2,manufacturer=\"${MBD_NAME%% *}\",product=\"$MBD_NAME\",version=$BIOS_VERSION,serial=\"$SERIAL_MB\",asset=\"X99Asset\",location=\"Slot0\""
    ARGS+=" -smbios type=3,manufacturer=\"${MBD_NAME%% *}\",version=$BIOS_VERSION,serial=\"$SERIAL_MB\",asset=\"CHASSIS123\",sku=\"CHSK123\""
    ARGS+=" -smbios type=4,sock_pfx=\"LGA2011-3\",manufacturer=\"Intel(R) Corporation\",version=\"Intel(R) Xeon(R) CPU E5-2697 v4 @ 2.30GHz\",max-speed=3600,current-speed=2300,serial=\"$SERIAL_CPU\",asset=\"CPUASSET\",part=\"E5-2697v4\""
    ARGS+=" -smbios type=17,loc_pfx=\"DIMM_C1\",manufacturer=\"$RAM_BRAND\",speed=$RAM_SPEED,serial=$RAM_SERIAL,part=\"$RAM_PART\",bank=\"NODE1\",asset=\"$ASSET_RAM\""
    ARGS+=" -smbios type=11,value=\"$(randstr 10)\""
    ARGS+=" -smbios type=8"
    ARGS+=" -smbios type=8"
    echo "args: $ARGS" >> "$CONF"

    # Add + Random smbios in VMID.conf
    sed -i '/^smbios1:/d' "$CONF"
    SMBIOS1="base64=1,family=$(echo -n X99FAMILY | base64),manufacturer=$(echo -n ${MBD_NAME%% *} | base64),product=$(echo -n $MBD_NAME | base64),serial=$(echo -n $SERIAL_SYS | base64),sku=$(echo -n X99SKU | base64),uuid=$UUID,version=$(echo -n $BIOS_VERSION | base64)"
    echo "smbios1: $SMBIOS1" >> "$CONF"

    # Add + Random vmgenid Key in VMID.conf
    sed -i '/^vmgenid:/d' "$CONF"
    VMGENID=$(randuuid)
    echo "vmgenid: $VMGENID" >> "$CONF"

    # Check for serial= if not present, randomize HWID again.
    if grep -q 'ssd=1' "$CONF"; then
        TMP_CONF=$(mktemp)
        PATCHED=0

        while IFS= read -r line; do
            if [[ "$line" == *"ssd=1"* ]]; then
                if [[ "$line" == *"serial="* ]]; then
                    # If serial exists → replace with a new value
                    SERIAL_SSD=$(rand_ssd_serial)
                    ESCAPED_SERIAL_SSD=$(printf '%s\n' "$SERIAL_SSD" | sed -e 's/[&#]/\\&/g')
                    line=$(echo "$line" | sed -E "s#(ssd=1,)?serial=[^,]*#ssd=1,serial=$ESCAPED_SERIAL_SSD#")
                    PATCHED=1
                else
                    # If no serial exists → append after ssd=1
                    SERIAL_SSD=$(rand_ssd_serial)
                    ESCAPED_SERIAL_SSD=$(printf '%s\n' "$SERIAL_SSD" | sed -e 's/[&#]/\\&/g')
                    line=$(echo "$line" | sed -E "s#(ssd=1)(,|$)#\1,serial=$ESCAPED_SERIAL_SSD\2#")
                    PATCHED=1
                fi
            fi
            echo "$line" >> "$TMP_CONF"
        done < "$CONF"

        if [[ "$PATCHED" -eq 1 ]]; then
            mv "$TMP_CONF" "$CONF"
        else
            rm "$TMP_CONF"
        fi
    fi

    echo "$NEW_PRESET" > "$HWID_PATH"
fi



# Execute only after the VM has stopped
# This ensures the MAC LAN can truly change every time the VM starts again.
if [[ "$PHASE" == "post-stop" ]]; then
    if grep -q '^net0:' "$CONF"; then
        NETLINE=$(grep -m1 '^net0:' "$CONF")
        NETMODEL=$(echo "$NETLINE" | cut -d '=' -f1 | cut -d ':' -f2 | xargs)
        BRIDGE=$(echo "$NETLINE" | grep -o 'bridge=[^,]*' | cut -d '=' -f2)

        FIREWALL=$(echo "$NETLINE" | grep -o 'firewall=[^,]*' | cut -d '=' -f2)
        [[ -z "$FIREWALL" ]] && FIREWALL=1

        RATE_OPT=$(echo "$NETLINE" | grep -o 'rate=[^,]*')

        NEWMAC=$(rand_mac_e1000)
        sed -i "/^net0:/d" "$CONF"

        echo -n "net0: ${NETMODEL}=${NEWMAC},bridge=${BRIDGE},firewall=${FIREWALL}" >> "$CONF"
        [[ -n "$RATE_OPT" ]] && echo -n ",$RATE_OPT" >> "$CONF"
        echo "" >> "$CONF"
    fi
fi