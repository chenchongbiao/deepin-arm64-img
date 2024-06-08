#!/bin/bash

# 何命令失败（退出状态非0），则脚本会终止执行
set -o errexit
# 尝试使用未设置值的变量，脚本将停止执行
set -o nounset

# 不进行交互安装
export DEBIAN_FRONTEND=noninteractive

ROOTFS=`mktemp -d`
TARGET_ARCH=arm64
COMPONENTS="main,commercial,community"
DISKSIZE="2048"
DISKIMG="deepin-arm64.raw"
DISTRO_NAME="beige"
readarray -t REPOS < ./profiles/sources.list
PACKAGES=`cat ./profiles/packages.list | grep -v "^-" | xargs | sed -e 's/ /,/g'`
EFI_UUID="D77D4BBF"
ROOT_UUID="9e8ff63f-443a-4886-97fe-2d46e36a6270"

# 需要安装以下环境
# sudo apt install -y curl git mmdebstrap qemu-user-static usrmerge usr-is-merged binfmt-support systemd-container
# 开启异架构支持
# sudo systemctl start systemd-binfmt

# 生成 img
# 创建一个空白的镜像文件。
dd if=/dev/zero of=$DISKIMG bs=1M count=$DISKSIZE
# 分区
(echo n; echo 15; echo ""; echo +127M;  echo ef00; echo n; echo 1; echo ""; echo ""; echo ""; echo w; echo y) | gdisk $DISKIMG

# 找一个未被使用的循环（loop）设备，并绑定到 img 镜像，同时扫描并处理镜像所有分区
DEV=$(sudo losetup --partscan --find --show $DISKIMG)

# 设置这些文件系统的标签。dosfslabel 是用来设置vfat（FAT）文件系统的标签，e2label 是用来设置ext2/ext3/ext4文件系统的标签
sudo mkfs.vfat "${DEV}p15" -i $EFI_UUID
sudo mmd -i "${DEV}p15" ::/EFI
sudo mmd -i "${DEV}p15" ::/EFI/BOOT
sudo mcopy -i "${DEV}p15" profiles/EFI/BOOTAA64.EFI ::/EFI/BOOT
# 将img文件格式化为ext4文件系统
sudo mkfs.ext4 "${DEV}p1" -U $ROOT_UUID
sudo e2label "${DEV}p1" root
# 挂载 deepin.img 镜像
sudo mount "${DEV}p1" $ROOTFS

# 创建根文件系统
sudo mmdebstrap \
    --hook-dir=/usr/share/mmdebstrap/hooks/merged-usr \
    --skip=check/empty \
    --include=$PACKAGES \
    --components=$COMPONENTS \
    --architectures=$TARGET_ARCH \
    $DISTRO_NAME \
    $ROOTFS \
    "${REPOS[@]}"

sudo mkdir $ROOTFS/boot/efi
# 拷贝 grub
sudo cp -r profiles/grub/* $ROOTFS/boot/grub

# 拷贝内核
sudo cp profiles/kernel/boot/* $ROOTFS/boot
sudo mkdir $ROOTFS/lib/modules
sudo cp -r profiles/kernel/lib/* $ROOTFS/lib/modules

# 自动加载 vfat 模块
sudo tee $ROOTFS/etc/modules << EOF
fat
vfat
EOF

# 配置 /etc/fstab
sudo tee $ROOTFS/etc/fstab << EOF
UUID=$ROOT_UUID / ext4 rw,discard,errors=remount-ro,x-systemd.growfs 0 1
UUID=D77D-4BBF /boot/efi vfat defaults 0 0
EOF

# 删除 root 的密码
sudo sed -i 's/^root:[^:]*:/root::/' $ROOTFS/etc/shadow

sudo echo "deepin-$TARGET_ARCH" | sudo tee $ROOTFS/etc/hostname > /dev/null
sudo echo "Asia/Shanghai" | sudo tee $ROOTFS/etc/timezone > /dev/null
sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai $ROOTFS/etc/localtime

# -l 懒卸载，避免有程序使用 ROOTFS 还没退出
sudo umount -l $ROOTFS
sudo losetup -D ${DEV}

sudo rm -rf $ROOTFS