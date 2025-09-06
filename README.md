# macos-eject-external-drives
A simple MacOS terminal script to safely eject external drives. Useful for when you need 
to unplug your MacBook and go. 

[![CC BY-SA 4.0][cc-by-sa-shield]][cc-by-sa]

This work is licensed under a
[Creative Commons Attribution-ShareAlike 4.0 International License][cc-by-sa].

[![CC BY-SA 4.0][cc-by-sa-image]][cc-by-sa]

[cc-by-sa]: http://creativecommons.org/licenses/by-sa/4.0/
[cc-by-sa-image]: https://licensebuttons.net/l/by-sa/4.0/88x31.png
[cc-by-sa-shield]: https://img.shields.io/badge/License-CC%20BY--SA%204.0-lightgrey.svg

Have you ever been running late, and you needed to take your MacBook with you, but Time 
Machine is taking its sweet time backing up to an external drive?

Need to disconnect your external physical drives, but don't want accidentially eject 
your iPhone because the eject icons in finder are really small?

Then this simple script is for you!  Just double click the command file or an alias of
your choosing.

Note: While this script will stop a Time Machine backup in progress, it will Will *not* 
automatically cancel file transfers that are in progress to your external drives.
