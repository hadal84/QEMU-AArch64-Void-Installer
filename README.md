*this script is still in alpha and is ONLY intended for use on QEMU virtual machines.*

a simple script that automates the installation of void linux by unpacking the main system tarball and installing base packages via xbps. it's main development goal was to make aarch64 vm installations easier since void-install is only supported on x64.

the script partitons your selected drive into a 512MB EFI partition and gives the rest to a linux file system formatted as ext4.

it should be ran under a live environment and you need to keep in mind that all of the data will be wiped from your selected virtual hard drive.
