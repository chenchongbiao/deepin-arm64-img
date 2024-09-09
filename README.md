# 介绍

deepin arm64 系统制作。

# 启动

qemu

```
qemu-system-aarch64 \
    -machine virt \
    -m 4G \
    -smp 2,cores=2,threads=1,sockets=1 \
    -cpu cortex-a57 \
    -drive file=AAVMF_CODE.ms.fd,if=pflash,format=raw,readonly=on \
    -drive file=deepin-arm64.img,if=none,id=hd0,format=raw \
    -device virtio-blk-pci,drive=hd0 \
    -device qemu-xhci \
    -netdev user,id=mynet \
    -device virtio-net-pci,netdev=mynet \
    -vnc 0.0.0.0:1 \
    -device virtio-balloon-pci \
    -device virtio-gpu-pci \
    -serial mon:stdio 
```
