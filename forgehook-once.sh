#!/bin/bash

# Receive VMID and PHASE from arguments
VMID="$1"
PHASE="$2"

# Path VMID config
CONF="/etc/pve/qemu-server/${VMID}.conf"

# Path preset
HWID_PATH="/var/lib/vz/snippets/log-hook/hwid-spoofer/hwid-${VMID}"

# Function Random
randstr() { tr -dc A-Za-z0-9 </dev/urandom | head -c "$1"; }
randnum() { tr -dc 0-9 </dev/urandom | head -c "$1"; }
randuuid() { cat /proc/sys/kernel/random/uuid; }

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
    if grep 'ssd=1' "$CONF" | grep -vqv 'serial='; then
        :
    else
        exit 0
    fi

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
    RAM_SPEEDS=(2133 2400 2666 3200)
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
    BIOS_DATE=$(date +'%m/%d/%Y')

    # Get manufacturer and version from dmidecode (type 4) because you are using host passthrough.
    DMIDECODE_MANUFACTURER=$(dmidecode -t 4 | grep 'Manufacturer:' | head -n1 | awk -F': ' '{print $2}')
    DMIDECODE_VERSION=$(dmidecode -t 4 | grep 'Version:' | head -n1 | awk -F': ' '{print $2}')
    DMIDECODE_SOCKET=$(dmidecode -t 4 | grep 'Upgrade: Socket ' | head -n1 | sed 's/Upgrade: Socket //' | xargs)
    DMIDECODE_MAX_SPEED=$(dmidecode -t 4 | grep 'Max Speed:' | head -n1 | awk -F': ' '{print $2}' | awk '{print $1}')
    DMIDECODE_CUR_SPEED=$(dmidecode -t 4 | grep 'Current Speed:' | head -n1 | awk -F': ' '{print $2}' | awk '{print $1}')
    DMIDECODE_ASSET=$(dmidecode -t 4 | grep 'Asset Tag:' | head -n1 | awk -F': ' '{print $2}' | xargs)
    DMIDECODE_PART=$(dmidecode -t 4 | grep 'Part Number:' | head -n1 | awk -F': ' '{print $2}' | xargs)

    # Add args in VMID.conf
    sed -i '/^args:/d' "$CONF"
    ARGS="-acpitable file=/root/ssdt.aml -acpitable file=/root/ssdt-ec.aml -acpitable file=/root/hpet.aml -cpu host,hypervisor=off,vmware-cpuid-freq=false,enforce=false,host-phys-bits=true"
    ARGS+=" -smbios type=0,vendor=\"$BIOS_VENDOR\",version=1.0,date='$BIOS_DATE'"
    ARGS+=" -smbios type=1,manufacturer=\"${MBD_NAME%% *}\",product=\"$MBD_NAME\",version=$BIOS_VERSION,serial=\"$SERIAL_SYS\",sku=\"Default string\",family=\"Default string\""
    ARGS+=" -smbios type=2,manufacturer=\"${MBD_NAME%% *}\",product=\"$MBD_NAME\",version=$BIOS_VERSION,serial=\"$SERIAL_MB\",asset=\"Default string\",location=\"Slot0\""
    ARGS+=" -smbios type=3,manufacturer=\"${MBD_NAME%% *}\",version=$BIOS_VERSION,serial=\"$SERIAL_MB\",asset=\"Default string\",sku=\"Default string\""
    ARGS+=" -smbios type=4,sock_pfx=\"$DMIDECODE_SOCKET\",manufacturer=\"$DMIDECODE_MANUFACTURER\",version=\"$DMIDECODE_VERSION\",max-speed=$DMIDECODE_MAX_SPEED,current-speed=$DMIDECODE_CUR_SPEED,serial=\"$SERIAL_CPU\",asset=\"$DMIDECODE_ASSET\",part=\"$DMIDECODE_PART\""
    ARGS+=" -smbios type=17,loc_pfx=\"DIMM_C1\",manufacturer=\"$RAM_BRAND\",speed=$RAM_SPEED,serial=$RAM_SERIAL,part=\"$RAM_PART\",bank=\"NODE1\",asset=\"$ASSET_RAM\""
    ARGS+=" -smbios type=9 -smbios type=8"
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
            if [[ "$line" == *"ssd=1"* && "$line" != *"serial="* ]]; then
                SERIAL_SSD=$(rand_ssd_serial)
                ESCAPED_SERIAL_SSD=$(printf '%s\n' "$SERIAL_SSD" | sed -e 's/[&#]/\\&/g')
                line=$(echo "$line" | sed -E "s#(ssd=1)(,|$)#\1,serial=$ESCAPED_SERIAL_SSD\2#")
                PATCHED=1
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

    # This code will help the VM to get the latest changes by stopping the VM and starting the VM automatically (because the Hook Script is running when the VM is started, the VM will not get the latest random values, so this code helps the VM to get the latest changed values).
    setsid /var/lib/vz/snippets/vm-restart.sh "$VMID" > /dev/null 2>&1 < /dev/null &
fi