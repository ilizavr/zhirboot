mkdir build
nasm mbr.asm -o build/mbr.bin
gcc -m32 -ffreestanding -fno-pie -nostdlib -c kernel.c -o build/kernel.o
nasm kernel_entry.asm -o build/entry.o -f elf32
ld -m elf_i386 -Ttext 0x8000 --oformat binary build/entry.o build/kernel.o -o build/kernel.bin

dd if=/dev/zero of=disk.img bs=1M count=10
dd if=build/mbr.bin of=disk.img bs=512 count=1
dd if=build/kernel.bin of=disk.img bs=512 seek=1 count=64

qemu-system-i386 -hda disk.img
