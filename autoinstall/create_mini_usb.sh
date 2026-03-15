#!/bin/bash

# Configuration
ISO_NAME="ubuntu-24.04.4.iso"
OUTPUT_ISO="mini-me-autoinstall.iso"
VOLUME_NAME="CIDATA"

echo "🚀 Starting Project Fifth Element provisioning..."

# 1. Install xorriso if missing
if ! command -v xorriso &> /dev/null; then
    echo "Installing xorriso via Homebrew..."
    brew install xorriso
fi

# 2. Inject user-data into a new ISO
echo "💉 Injecting 'Leeloo' into ISO with CIDATA label..."
xorriso -indev "$ISO_NAME" \
   -outdev "$OUTPUT_ISO" \
   -volid "$VOLUME_NAME" \
   -map user-data /user-data \
   -map meta-data /meta-data \
   -boot_image any next

echo "✅ Remastered ISO created: $OUTPUT_ISO"
echo "---------------------------------------------------"
echo "Next Steps:"
echo "1. Plug in your USB drive."
echo "2. Run 'diskutil list' to find your drive number (N)."
echo "3. Run: sudo dd if=$OUTPUT_ISO of=/dev/rdiskN bs=1m status=progress"
echo "4. Boot the Intel Mini, press 'e' in GRUB, and add: autoinstall ds=nocloud;s=/"