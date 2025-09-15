#!/bin/bash
VMID="$1"

sleep 3

if qm status "$VMID" | grep -q "status: running"; then
    qm stop "$VMID"
    sleep 3
    qm start "$VMID"
fi