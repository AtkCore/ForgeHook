# ⚒️ ForgeHook 🎣  
A hook script for randomizing hardware values in `VMID.conf`.  
Easy to use, flexible to customize, and simple to extend.  

It’s a straightforward idea that makes use of the existing Hook feature in PVE to provide more value.  
You’re welcome to adapt, modify, or integrate it into your own projects as you like.  

If this helps make the PVE community better, I’ll be more than happy. 🙏

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 
# 🔧 Flexible Hook Script for Random HWID

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This project provides a **flexible hook script** to randomize HWID-related values in `VMID.conf`.  
It builds on PVE existing hook mechanism so you can extend or customize randomization independently.

> **Friendly note to patch authors 🙏**  
> In some patches (e.g., Spoofer for `pve-qemu-kvm`), certain values may be fixed (like `serial=0123456789ABCDEF0123`) to avoid constant re-randomization.  
> **That’s not a bad approach** — it’s reasonable given patch complexity.  
> This hook simply offers another path for users who need more flexibility (e.g., when certain apps/games are sensitive to fixed HDD serials).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## ⚠️ Compatibility Notes

- Tested on **pve-qemu-kvm 7 & 8**.  
  For **9 & 10**, some Spoofer patches may not expose randomization through `VMID.conf`, or may still do their own internal randomization.  
  For now, please prefer versions **7–8** when evaluating this hook.

- If you’ve built an **open, freely-randomizable Spoofer** for **9 or 10**, please let me know 🙏  
  I’m happy to publish an updated version to support it.

- You’re free to **modify** this code to suit your VM setup and the patch you use.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 💡 Why this helps

- Some patches require fixed values (e.g., `serial=0123456789ABCDEF0123`) to prevent infinite randomization loops.  
  But fixed HDD serials can be problematic in certain software/games (e.g., ban based on unchanged HDD serial).  
- With this **external hook**, you can randomize HDD serials (and other IDs) without hard-coding them in the patch, giving you **greater control**.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 🎛️ What gets randomized (examples)

> You can extend these; the lists below are included as **examples**.

- **HDD** — sample pool of 6 vendors  
- **Mainboard** — sample pool of 5 vendors  
- **RAM** — sample pool of 4 vendors (configurable `SPEED`, `Size`, `SERIAL`)  
- **BIOS UUID** (via `smbios1`)  
- **BIOS Serial** (`-smbios type=3` and `type=4`)  
- **vmgenid`

📝 **Note:** CPU spoofing is intentionally **not** included.  
If needed, set a CPU type to match the host for consistency.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 🚀 Getting Started

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 1. Enable Snippets for Hook Scripts

Proxmox already provides a Hook Script mechanism.  
It’s not complicated — you just need to know where to place the file.

Official documentation:  
https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_hookscripts

Example from the manual (for reference only — in this project we’ll edit `VMID.conf` directly, which is easier to understand):

qm set 100 --hookscript local:snippets/hookscript.pl

The keyword `local:snippets` means you must first enable **Snippets** in your storage:

Datacenter → Storage → local → Content → enable Snippets

Once Snippets is enabled, you can use Hook Scripts.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 2. Place the Files

Put the script files from this project into:

/var/lib/vz/snippets

This project currently includes 4 key components:

1. forgehook-once.sh  
2. forgehook-repeat.sh  
3. vm-restart.sh  
4. Folder log-hook

Make sure all 4 are executable:

cd /var/lib/vz/snippets  
chmod +x *.*

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 3. File Overview

### 🔹 forgehook-once.sh
- Runs only **once**.  
- On VM start, if no `serial=` is found in `VMID.conf`, the script will insert one and randomize values.  
- Tested with **a single HDD** (not yet with multiple). Future updates may expand this.

### 🔹 forgehook-repeat.sh
- Similar to `forgehook-once.sh`, but randomizes on **every VM start**.  
- Use this if you want new HWIDs each time.

### 🔹 vm-restart.sh
- Works **together with the above hooks**.  
- Ensures new values in `VMID.conf` are properly applied by stopping & restarting the VM automatically.  
- Allows you to configure a delay for stop/start.  
- Skips redundant actions if `serial=` already exists.

### 🔹 log-hook (folder)
- Stores logs of generated HWIDs.  
- Files are named `hwid-<VMID>`.  
- Ensures **no duplicate randomization** across VMs (e.g., if 5 mainboards exist, it won’t pick the same one twice until all have been used).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 4. Configure `VMID.conf`

Location:  
/etc/pve/qemu-server/${VMID}.conf

Example snippet:

args: -cpu host,....(your custom values)....  
hookscript: local:snippets/forgehook-once.sh  
hostpci0: 0000:02:00.0,mdev=nvidia-54  
machine: pc-q35-7.2  
scsi0: nvme0:141/vm-141-disk-1.qcow2,cache=writeback,discard=on,iothread=1,size=120G,ssd=1

👉 Note: the hook will automatically append `,serial=<HWID>` to your disk line.  
Make sure `,ssd=1` is present, as the script looks for this flag.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 🔄 Re-randomizing with `forgehook-once.sh`

1. Stop the VM.  
2. Edit `/etc/pve/qemu-server/${VMID}.conf`.  
3. Remove the current serial, e.g.:

scsi0: ... ,ssd=1,serial=0025B5674421A2D8F6W3

→ becomes:

scsi0: ... ,ssd=1

4. Save the file.  
5. Start the VM. The script will stop & restart it once more, applying a new HWID.

💡 **Note (Future improvement):**  
In the future, I plan to add a function that references existing configuration points already available in the PVE web interface.  
This will allow adjustments without directly editing the `VMID.conf` file,  
making the workflow easier and more convenient than manually opening and modifying the file.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 🙏 Acknowledgements

I’d like to take a moment to thank the people whose work and ideas inspired ForgeHook:

- **zhaodice**  
  One of the earliest developers I came across in the PVE community.  
  Your work lit the spark for me to pursue a childhood dream — making a single computer powerful enough to be shared with my family.  

- **Li Xiaoliu & DadaShuai666**  
  Both of you have been a huge source of motivation.  
  Your QEMU spoofers opened doors for me and many others, letting us enjoy games that once struggled with anti-cheat systems.  
  I remain a big fan and continue to follow your projects. Thank you for everything you’ve given to this community.  

- **Scrut1ny**  
  A talented creator in the Linux virtualization scene.  
  Many of your adaptations and ideas inspired my own.  
  Even though my main focus is on PVE, your work has broadened what’s possible and brought valuable variety to this space.  

---

✨ And to everyone I haven’t mentioned by name:  
your contributions have been just as valuable.  
Each idea, patch, and shared insight has helped this community grow stronger together —  
and made it a place where learning and creativity can also be fun. 🙌

---

💡 This is my very first GitHub project.  
If anything looks unusual, please forgive me — I’m still learning, and I used Google Translate to help with the English wording.  

Thank you all for your hard work and for making this community stronger. 🙌
