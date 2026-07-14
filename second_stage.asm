bits 32
org 0x8000

mov eax, 0x42
mov ebx, 9
mov ecx, 0x10000
int 0

mov eax, 0
mov ebx, 8
mov ecx, 0x10000
int 0

jmp $
