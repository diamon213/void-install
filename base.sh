#!/bin/sh

#Void linux minimal install

set -e # if a command return a non zero status, the script will quit.

# Variables

url=https://github.com/void-linux/void-mklive
efi=/dev/nvme0n1p1
root=/dev/nvme0n1p2
hostname=thinkpad-aladin
clock=CEST
timezone=Europe/Zurich
keymap=de_CH-latin1

# Functions

instpkg()
  
  {
  
  xbps-install -Sy make
  xbps-install -Sy tar 
  xbps-install -Sy xz 
  xbps-install -Sy git
  cd /tmp
  git clone $url
  cd void-mklive
  make
 
  }

setpart()
 
  {
  
  mkfs.vfat $efi
  mkfs.ext4 $root
  mkdir -p /mnt/boot/efi
  mkdir -p /mnt/boot/grub
  mount $efi /mnt/boot/efi
  mount $root /mnt
   
   }
  
rootfs()
  
   {
  
  cd /tmp/void-mklive
  ./mkrootfs.sh -b base-minimal x86_64
  file=$(find -- *.xz)
  tar xvf "$file" -C /mnt
  cd /mnt
  
   }
 
setrootfs()
 
   {
 
  mount --rbind /sys /mnt/sys && mount --make-rslave /mnt/sys
  mount --rbind /dev /mnt/dev && mount --make-rslave /mnt/dev
  mount --rbind /proc /mnt/proc && mount --make-rslave /mnt/proc
  
   }
   
set1rootfs()
  
    {
  
  mkdir -p /var/db/xbps/keys /usr/share
  cp -L /etc/resolv.conf /etc
  cp -a /usr/share/xbps.d /usr/share
  cp /var/db/xbps/keys/*.plist /var/db/xbps/keys
  
    }
  
instrootfs()
    
    {
   
    xbps-install -r /mnt -SyU base-minimal
    xbps-reconfigure -r /mnt -f base-files
    chroot /mnt xbps-reconfigure -a
    xbps-install -r /mnt -Sy xbps
    xbps-install -r /mnt -Sy void-repo-nonfree
    chroot /mnt xbps-install -Sy
    xbps-install -r /mnt/voidlinux -Sy linux5.4 kernel-libc-headers \
    iputils dhclient iw doas\
    ncurses kbd man-pages vim 
    
    }
  
  grub()
    
    {
    
    xbps-install -r /mnt -S grub-x86_64-efi
    chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    chroot /mnt grub-install /dev/sda
    
    }
    
  confmnt()
    
    {
    
    echo $hostname > /mnt/etc/hostname
    cat << EOF  > /mnt/etc/rc.local
    HOSTNAME=$hostname
    HARDWARECLOCK=$clock
    TIMEZONE=$timezone
    KEYMAP=$keymap
EOF
    
    cat << EOF > /mnt/etc/locale.conf
    LANG=en_US.UTF-8
    LC_COLLATE=C
    LC_ALL=en_US.UTF-8
EOF
    
    sed -e "/en_US.UTF-8 UTF-8/s/^\#//" -i /mnt/etc/default/libc-locales
    chroot /mnt/ ln -s /usr/share/zoneinfo/"$timezone" /etc/localtime
    
    }
    
fstab()
   
    {
    
    cat << EOF > /mnt/voidlinux/etc/fstab
    UUID=$(blkid -o value -s UUID $root) /boot/efi/ vfat defaults 0 2
    UUID=$(blkid -o value -s UUID $root) / ext4 defaults 0 1
EOF
    
    }
  
  
# The script

instpkg 
setpart 
rootfs 
setrootfs 
set1rootfs 
instrootfs 
grub 
confmnt
fstab 
