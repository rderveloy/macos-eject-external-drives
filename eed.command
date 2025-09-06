#! /bin/bash

# Have user authenticate if needed:
sudo echo ""


# First, make sure there are no running backup processes:
echo -n "Stopping any currently running time machine backups..."
sudo tmutil stopbackup
echo "Done!"

# Next, eject external physical drives:
echo ""
echo "Ejecting external drives.  Please wait..."
diskutil list external physical | grep -E '^/dev/' | grep -Eo 'disk\d+' | while read i; do diskutil eject "$i"; done
echo "Done!"

# Ask the user to verify before completing script:
echo""
echo "Please verify external disks have been ejected before disconnecting."
echo "Goodbye!"
exit
