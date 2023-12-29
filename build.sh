#!/bin/sh

set -eu

NAME=landscapeos
VERSION=0.1.0

SUITE=bookworm

KERNEL_VERSION=6.1.0-15
ARCH=amd64

CHROOT_PREINST_DIR=chroot.preinst
CHROOT_POSTINST_DIR=chroot.postinst

CHROOT_LIVE_PREINST_DIR=chroot.live.preinst
CHROOT_LIVE_POSTINST_DIR=chroot.live.postinst

LIVE_USERNAME=land
LIVE_PASSWORD=land

EFI_BASE_DIR=efi.base

TMP_DIR=tmp

CHROOT_1_DIR="$TMP_DIR"/chroot.1
CHROOT_2_DIR="$TMP_DIR"/chroot.2
CHROOT_3_DIR="$TMP_DIR"/chroot.3
CHROOT_4_DIR="$TMP_DIR"/chroot.4

CHROOT_LIVE_1_DIR="$TMP_DIR"/chroot.live.1
CHROOT_LIVE_2_DIR="$TMP_DIR"/chroot.live.2
CHROOT_LIVE_3_DIR="$TMP_DIR"/chroot.live.3

FILESYSTEM_SQUASHFS="$TMP_DIR"/filesystem.squashfs
FILESYSTEM_LIVE_SQUASHFS="$TMP_DIR"/filesystem.live.squashfs

EFI_IMG="$TMP_DIR"/efi.img

ISO="$TMP_DIR"/"$NAME"-"$VERSION"-"$ARCH".iso

SUDO_CMD=sudo

main() {
  mkdir -p "$TMP_DIR"
  if [ "$(id -u)" != 0 ]; then
    exec "$SUDO_CMD" "$0"
  fi
  if [ ! -d "$CHROOT_1_DIR" ]; then
    create_chroot_1_dir
  fi
  if [ ! -d "$CHROOT_2_DIR" ]; then
    create_chroot_2_dir
  fi
  if [ ! -d "$CHROOT_3_DIR" ]; then
    create_chroot_3_dir
  fi
  if [ ! -d "$CHROOT_4_DIR" ]; then
    create_chroot_4_dir
  fi
  if [ ! -d "$CHROOT_LIVE_1_DIR" ]; then
    create_chroot_live_1_dir
  fi
  if [ ! -d "$CHROOT_LIVE_2_DIR" ]; then
    create_chroot_live_2_dir
  fi
  if [ ! -d "$CHROOT_LIVE_3_DIR" ]; then
    create_chroot_live_3_dir
  fi
  if [ ! -f "$FILESYSTEM_SQUASHFS" ]; then
    create_filesystem_squashfs
  fi
  if [ ! -f "$FILESYSTEM_LIVE_SQUASHFS" ]; then
    create_filesystem_live_squashfs
  fi
  if [ ! -f "$EFI_IMG" ]; then
    create_efi_img
  fi
  if [ ! -f "$ISO" ]; then
    create_iso
  fi
}

create_chroot_1_dir() {
  mmdebstrap --variant=minbase "$SUITE" "$CHROOT_1_DIR"
  rm -fr "$CHROOT_2_DIR"
}

create_chroot_2_dir() {
  clone "$CHROOT_1_DIR"/ "$CHROOT_2_DIR"
  if [ -d "$CHROOT_PREINST_DIR" ]; then
    clone "$CHROOT_PREINST_DIR"/ "$CHROOT_2_DIR" --no-g --no-o
  fi
  chroot_sync "$CHROOT_2_DIR" passwd -l root
  rm -fr "$CHROOT_3_DIR"
}

create_chroot_3_dir() {
  clone "$CHROOT_2_DIR"/ "$CHROOT_3_DIR"
  install_packages "$CHROOT_3_DIR" apt-utils
  install_packages "$CHROOT_3_DIR" linux-image-"$KERNEL_VERSION"-"$ARCH" \
    systemd systemd-boot systemd-sysv
  rm -fr "$CHROOT_4_DIR"
}

create_chroot_4_dir() {
  clone "$CHROOT_3_DIR"/ "$CHROOT_4_DIR"
  if [ -d "$CHROOT_POSTINST_DIR" ]; then
    clone "$CHROOT_POSTINST_DIR"/ "$CHROOT_4_DIR" --no-g --no-o
  fi

  rm "$CHROOT_4_DIR"/vmlinuz "$CHROOT_4_DIR"/vmlinuz.old \
    "$CHROOT_4_DIR"/initrd.img "$CHROOT_4_DIR"/initrd.img.old

  local kernel_ref=vmlinuz-"$KERNEL_VERSION"-"$ARCH"
  local kernel_link="$CHROOT_4_DIR"/boot/vmlinuz
  ln -s "$kernel_ref" "$kernel_link"

  local initrd_ref=initrd.img-"$KERNEL_VERSION"-"$ARCH"
  local initrd_link="$CHROOT_4_DIR"/boot/initrd.img
  ln -s "$initrd_ref" "$initrd_link"

  rm -fr "$CHROOT_LIVE_1_DIR" "$FILESYSTEM_SQUASHFS" "$ISO"
}

create_chroot_live_1_dir() {
  if [ -d "$CHROOT_LIVE_PREINST_DIR" ]; then
    clone "$CHROOT_LIVE_PREINST_DIR"/ "$CHROOT_LIVE_1_DIR" --no-g --no-o
  fi
  rm -fr "$CHROOT_LIVE_2_DIR"
}

create_chroot_live_2_dir() {
  local lower_dir="$CHROOT_4_DIR"
  local upper_dir="$(mktemp -dp "$TMP_DIR")"
  local work_dir="$(mktemp -dp "$TMP_DIR")"
  local merged_dir="$(mktemp -dp "$TMP_DIR")"
  {
    mount -o lowerdir="$lower_dir",upperdir="$upper_dir",workdir="$work_dir" \
      -t overlay overlay "$merged_dir"
    install_packages "$merged_dir" fzf live-boot
    clone "$upper_dir"/ "$CHROOT_LIVE_2_DIR"
  } || :
  umount "$merged_dir"
  rm -fr "$upper_dir" "$work_dir" "$merged_dir"
  rm -fr "$CHROOT_LIVE_3_DIR"
}

create_chroot_live_3_dir() {
  local lower_dir="$CHROOT_4_DIR"
  local upper_dir="$(mktemp -dp "$TMP_DIR")"
  local work_dir="$(mktemp -dp "$TMP_DIR")"
  local merged_dir="$(mktemp -dp "$TMP_DIR")"
  {
    mount -o lowerdir="$lower_dir",upperdir="$upper_dir",workdir="$work_dir" \
      -t overlay overlay "$merged_dir"
    clone "$CHROOT_LIVE_2_DIR"/ "$merged_dir"
    if [ -d "$CHROOT_LIVE_POSTINST_DIR" ]; then
      clone "$CHROOT_LIVE_POSTINST_DIR"/ "$merged_dir" --no-g --no-o
    fi
    chroot_sync "$merged_dir" adduser --comment '' --disabled-password \
      "$LIVE_USERNAME"
    chroot_sync "$merged_dir" sh -c \
      "echo $LIVE_USERNAME:$LIVE_PASSWORD | chpasswd"
    clone "$upper_dir"/ "$CHROOT_LIVE_3_DIR"
  } || :
  umount "$merged_dir"
  rm -fr "$upper_dir" "$work_dir" "$merged_dir"
  rm -f "$FILESYSTEM_LIVE_SQUASHFS" "$ISO"
}

create_filesystem_squashfs() {
  mksquashfs "$CHROOT_4_DIR" "$FILESYSTEM_SQUASHFS" -comp zstd
  rm -f "$ISO"
}

create_filesystem_live_squashfs() {
  mksquashfs "$CHROOT_LIVE_3_DIR" "$FILESYSTEM_LIVE_SQUASHFS" -comp zstd
  rm -f "$ISO"
}

create_efi_img() {
  truncate -s 300M "$EFI_IMG"
  mkfs.fat -F 32 "$EFI_IMG"
  local mountpoint="$(mktemp -dp "$TMP_DIR")"
  {
    mount "$EFI_IMG" "$mountpoint"
    if [ -d "$EFI_BASE_DIR" ]; then
      clone "$EFI_BASE_DIR"/ "$mountpoint" --no-g --no-o
    fi

    local boot_efi_from="$CHROOT_4_DIR"/usr/lib/systemd/boot/efi/systemd-bootx64.efi
    local boot_efi_to="$mountpoint"/EFI/boot/bootx64.efi
    clone "$boot_efi_from" "$boot_efi_to"

    local kernel_from="$CHROOT_4_DIR"/boot/vmlinuz-"$KERNEL_VERSION"-"$ARCH"
    local kernel_to="$mountpoint"/vmlinuz
    clone "$kernel_from" "$kernel_to"

    local initrd_from="$CHROOT_LIVE_3_DIR"/boot/initrd.img-"$KERNEL_VERSION"-"$ARCH"
    local initrd_to="$mountpoint"/initrd.img
    clone "$initrd_from" "$initrd_to"
    rm -f "$ISO"
  } || :
  umount "$mountpoint"
  rmdir "$mountpoint"
}

chroot_sync() {
  local mountpoint="$1"
  shift
  echo 'sleep 1 && "$@"' | arch-chroot "$mountpoint" sh -s -- "$@"
}

clone() {
  local path_from="$1"
  local path_to="$2"
  shift; shift
  mkdir -p "${path_to%/*}"
  rsync --info=progress2 -a "$@" "$path_from" "$path_to"
}

create_iso() {
  local iso_dir="$(mktemp -dp "$TMP_DIR")"
  {
    mkdir -p "$iso_dir"/live

    local filesystem_squashfs_to="$iso_dir"/live/filesystem.1.squashfs
    clone "$FILESYSTEM_SQUASHFS" "$filesystem_squashfs_to"

    local filesystem_live_squashfs_to="$iso_dir"/live/filesystem.2.squashfs
    clone "$FILESYSTEM_LIVE_SQUASHFS" "$filesystem_live_squashfs_to"

    xorriso -as mkisofs -append_partition 2 0xef "$EFI_IMG" -o "$ISO" \
      "$iso_dir"
  } || :
  rm -fr "$iso_dir"
}

install_packages() {
  local chroot="$1"
  shift
  {
    mount -B "$chroot" "$chroot"
    chroot_sync "$chroot" apt-get update
    chroot_sync "$chroot" env DEBIAN_FRONTEND=noninteractive apt-get -y \
      install "$@"
    rm -fr "$chroot"/var/lib/apt/lists/*
  }
  umount "$chroot"
}

main
