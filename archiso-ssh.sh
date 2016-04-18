#!/bin/bash

# Remaster arch iso to have the following:
#  - 0s bootloader timeout
#  - ssh server
#  - authorized_keys
#  - wpa_supplicant network info
#  - auto wifi enable
#  - avahi daemon and broadcast IP address as an archiso machine

set -e
basedir=$(cd $(dirname $0); pwd)

exe() { echo "\$ $@" ; "$@" ; }

abs_path() {
    echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
}

print_help() {
    echo "Usage: archiso-ssh -i /path/to/original.arch.iso -o /path/to/remastered.iso /path/to/assets"
}

# get command arguments:
opts=`getopt -o i:o: -n archiso-ssh -- "$@"`
eval set -- "$opts"
while true ; do
    case "$1" in
        -i) input_iso=$2; shift 2;;
        -o) output_iso=$2; shift 2;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

asset_dir=`abs_path $1`

if [ -z "$input_iso" ] || [ -z "$output_iso" ] || [ -z "$asset_dir" ] ; then
    print_help
    exit 1
fi

if (! command -v 7z >/dev/null 2>&1); then
    echo "Could not find 7z command. Please install p7zip package"
fi
if (! command -v unsquashfs >/dev/null 2>&1); then
    echo "Could not find unsquashfs command. Please install squashfs-tools package"
fi
if (! command -v perl >/dev/null 2>&1); then
    echo "Could not find perl command. Please install perl package"
fi

if [ ! -f "$asset_dir/authorized_keys" ]; then
    echo "missing authorized_keys file in $asset_dir"
    exit 1
fi
if [ ! -f "$asset_dir/wpa_supplicant.conf" ]; then
    echo "missing wpa_supplicant.conf file in $asset_dir"
    exit 1
fi

input_iso=`abs_path $input_iso`
output_iso=`abs_path $output_iso`

iso_label=`basename $asset_dir`

workdir=`mktemp -d`
exe cd $workdir
exe 7z x $input_iso

remaster_squashfs() {
    (
	if [ $1 != "x86_64" ] && [ "$1" != "i686" ]; then
	    echo "remaster_squashfs must be called with x86_64 or i686 as it's only paramater"
	    echo $1
	    return 1
	fi
	pushd arch/$1
	exe sudo unsquashfs airootfs.sfs
	cat <<EOF | sudo arch-chroot squashfs-root/ /bin/bash
pacman-key --init
pacman-key --populate archlinux
pacman -Sy

# Install and enable sshd:
pacman --noconfirm -S openssh
ln -s /usr/lib/systemd/system/sshd.service /etc/systemd/system/multi-user.target.wants/sshd.service

# Create root ssh folder (copy authorized_keys here later)
mkdir -p /root/.ssh
chmod 700 /root/.ssh

LANG=C pacman -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > /pkglist.txt
pacman -Scc --noconfirm
EOF
	exe cp squashfs-root/pkglist.txt ../pkglist.$1.txt
	exe sudo cp $asset_dir/authorized_keys squashfs-root/root/.ssh/authorized_keys
	exe sudo chown 600 squashfs-root/root/.ssh/authorized_keys
	exe sudo cp $asset_dir/wpa_supplicant.conf squashfs-root/root/wpa_supplicant.conf
	exe sudo chown 600 squashfs-root/root/wpa_supplicant.conf
	exe rm airootfs.sfs
	exe sudo mksquashfs squashfs-root airootfs.sfs
	exe sudo rm -rf squashfs-root
    )
}

remaster_squashfs x86_64
remaster_squashfs i686

# Modify iso label:
exe perl -pi -e "s/archisolabel=ARCH_[0-9]*/archisolabel=$iso_label/" $workdir/loader/entries/archiso-x86_64.conf $workdir/arch/boot/syslinux/archiso_sys32.cfg $workdir/arch/boot/syslinux/archiso_sys64.cfg
# Auto-timeout for bootloader, original has none:
echo "timeout 1" >> $workdir/arch/boot/syslinux/archiso_head.cfg
echo "default archiso-x86_64" >> $workdir/arch/boot/syslinux/archiso_head.cfg

# Create new iso:
exe genisoimage -l -r -J -V $iso_label -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -c isolinux/boot.cat -o $output_iso .
echo $workdir
