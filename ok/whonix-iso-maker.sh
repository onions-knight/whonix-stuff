#!/bin/bash

CHROOT_FOLDER="/home/user/whonix-iso"
RAW_FOLDER="/home/user/whonix-iso"
WHONIX_RAW="Whonix-Workstation-XFCE-15.0.0.0.9.raw"
ISO_FILE="Whonix-Workstation-XFCE-15.0.0.0.9.iso"

set -x

mount_raw(){
	kpartx -a -s -v $RAW_FOLDER/$WHONIX_RAW
	mkdir -p $RAW_FOLDER/chroot

	# very primitive command, will only work if previous kpartx command
	# allocates loop0p1 to $WHONIX_RAW
	mount /dev/mapper/loop0p1 $RAW_FOLDER/chroot
}

create_environment(){

	mkdir -p $RAW_FOLDER/image/{live,isolinux}
	mkdir -p $RAW_FOLDER/image/{boot/isolinux,EFI/boot}
	mkdir -p $RAW_FOLDER/image/boot/grub

	cp /usr/lib/ISOLINUX/isolinux.bin $RAW_FOLDER/image/boot/isolinux/
	cp /usr/lib/syslinux/modules/bios/* $RAW_FOLDER/image/boot/isolinux/

}

function create_squashfs_ok(){

	cd $RAW_FOLDER/ && \
		sudo mksquashfs \
		    chroot \
		    image/live/filesystem.squashfs \
		    -e boot
	
}

copy_files(){

	# probably better to replace * by exact kernel version

	(cd $RAW_FOLDER/ && \
		cp chroot/boot/vmlinuz-* image/live/vmlinuz
		cp chroot/boot/initrd.img-* image/live/initrd
	)
	(cd $RAW_FOLDER/image/ && \

		cp /usr/lib/ISOLINUX/isolinux.bin isolinux/ && \
		cp /usr/lib/syslinux/modules/bios/menu.c32 isolinux/ && \
		cp /usr/lib/syslinux/modules/bios/hdt.c32 isolinux/ && \
		cp /usr/lib/syslinux/modules/bios/ldlinux.c32 isolinux/ && \
		cp /usr/lib/syslinux/modules/bios/libutil.c32 isolinux/ && \
		cp /usr/lib/syslinux/modules/bios/libmenu.c32 isolinux/ && \
		cp /usr/lib/syslinux/modules/bios/libcom32.c32 isolinux/ && \
		cp /usr/lib/syslinux/modules/bios/libgpl.c32 isolinux/ && \
		cp /usr/share/misc/pci.ids isolinux/ && \
		cp /boot/memtest86+.bin live/memtest
	)

	cat <<'EOF' > $RAW_FOLDER/grub-embedded.cfg
	search --no-floppy --set=root --file /boot/grub/grub.cfg
	set prefix=($root)/boot/grub
EOF

		(cd /usr/lib/grub && \
			grub-mkimage \
				--config $RAW_FOLDER/grub-embedded.cfg \
				--format=x86_64-efi \
				--prefix "" \
				--output=$RAW_FOLDER/image/EFI/boot/bootx64.efi \
				--compression=xz \
				linux \
				normal \
				iso9660 \
				efi_uga \
				efi_gop \
				fat \
				chain \
				disk \
				exfat \
				usb \
				multiboot \
				msdospart \
				part_msdos \
				part_gpt \
				search \
				part_gpt \
				configfile \
				ext2 \
				boot
		)


		(cd $RAW_FOLDER/image/EFI && \
			dd if=/dev/zero of=efiboot.img bs=1M count=100 && \
			mkfs.vfat efiboot.img && \
			mmd -i efiboot.img efi efi/boot efi/boot/grub && \
			mcopy -i efiboot.img boot/bootx64.efi ::efi/boot/
		)

		cat <<'EOF' >$RAW_FOLDER/image/boot/isolinux/isolinux.cfg
		UI menu.c32

		prompt 0
		menu title Boot Menu

		timeout 30

		label Debian Live
		menu label ^Debian Live
		menu default
		kernel /live/vmlinuz
		append initrd=/live/initrd boot=live apparmor=1 security=apparmor ip=frommedia
		text help
			Boot Debian Live image
		endtext

		label Debian Live Quiet
		menu label ^Debian Live (Quiet / Silent Boot)
		kernel /live/vmlinuz
		append initrd=/live/initrd boot=live quiet ip=frommedia
		text help
			Boot Debian Live image with the quiet flag to hide kernel messages
		endtext

		label hdt
		menu label ^Hardware Detection Tool (HDT)
		kernel hdt.c32
		text help
			HDT displays low-level information about the systems hardware
		endtext

		label memtest86+
		menu label ^Memory Failure Detection (memtest86+)
		kernel /live/memtest
		text help
			Test system memory
		endtext
EOF


		cat <<'EOF' >$RAW_FOLDER/image/boot/grub/grub.cfg
		insmod all_video

		set default="0"
		set timeout=10

		menuentry "Debian Live" {
			linux /live/vmlinuz boot=live quiet nomodeset apparmor=1 security=apparmor ip=frommedia
			initrd /live/initrd
		}
EOF

}

create_iso(){

	xorriso \
		-as mkisofs \
		-iso-level 3 \
		-full-iso9660-filenames \
		-volid "DEBIAN_CUSTOM" \
		-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
		-eltorito-boot \
		    boot/isolinux/isolinux.bin \
		    -no-emul-boot -boot-load-size 4 -boot-info-table \
		    --eltorito-catalog boot/isolinux/isolinux.cat \
		-eltorito-alt-boot \
		    -e EFI/efiboot.img \
		    -no-emul-boot -isohybrid-gpt-basdat \
		-output "$RAW_FOLDER/$ISO_FILE" \
		"$RAW_FOLDER/image"

}

main(){
#mount_raw
#create_environment
#create_squashfs_ok
#copy_files
create_iso
}

main "$@"