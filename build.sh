mkdir build
nasm mbr.asm -o build/mbr.bin
nasm second_stage.asm -o build/second_stage.bin

dd if=/dev/zero of=disk.img bs=1M count=10
dd if=build/mbr.bin of=disk.img bs=512 count=1
dd if=build/second_stage.bin of=disk.img bs=512 seek=1 count=8
dd if=test.txt of=disk.img bs=512 seek=9 count=1

qemu-system-i386 -hda disk.img
