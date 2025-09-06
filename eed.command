#! /bin/bash

echo ""
echo -n "Stopping any currently running backup processes..."
sudo tmutil stopbackup
echo "Done!"

echo ""
echo "Ejecting external drives.  Please wait..."
diskutil list external physical | grep -E '^/dev/' | grep -Eo 'disk\d+' | while read i; do diskutil eject "$i"; done
echo "Done!"

echo""
echo "Please verify external disks have been ejected before disconnecting."
echo "Goodbye!"
exit
