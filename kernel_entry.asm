bits 32
extern main
global _start
global bootcall

_start:
    call main
    jmp $

bootcall:
    mov eax, [esp+4]
    mov ebx, [esp+8]
    mov ecx, [esp+12]
    mov edx, [esp+16]
    int 0
    ret
