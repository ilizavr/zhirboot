bits 32
extern main
global _start
global bootcall

_start:
    call main
    jmp $

bootcall:
    push ebx
    mov eax, [esp+8]
    mov ebx, [esp+12]
    mov ecx, [esp+16]
    mov edx, [esp+20]
    int 0
    pop ebx
    ret
