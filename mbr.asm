bits 16
org 0x7C00

_start:
    mov [bootdrive], dl

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp,0x6ff8

    in al, 0x92 ; enable a20
    or al, 2
    out 0x92, al

    mov si, dap
    mov ax, 0x4200 ; read
    mov dl, [bootdrive] ; boot disk
    int 0x13

    call get_memory_map

    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x8:.init


[bits 32]
.init:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov gs, ax
    mov ss, ax
    mov fs, ax

    mov esp, [saved_esp]
    lidt [saved_idt]

    jmp 0x8000

[bits 16]
get_memory_map:
    mov word [0x5000],0
    mov di, 0x5004
    xor bp, bp ; counter
    xor ebx, ebx

.loop:
    mov eax, 0xE820
    mov edx, 0x534D4150 ; SMAP magic
    mov ecx, 24
    int 0x15

    jc .done
    cmp eax, 0x534D4150
    jne .done

    jcxz .skip_entry

    add di, 24
    inc bp

.skip_entry:
    test ebx, ebx
    jne .loop

.done:
    mov [0x5000], bp
    ret



saved_esp:
 dd 0xFF00
saved_idt: 
 dw end_idt-start_idt-1
 dd start_idt

start_idt:
 dw interrupt_test
 dw 0x08
 db 0
 db 0x8E
 dw 0

end_idt:

real_idt:
 dw 0x3FF
 dd 0

align 16
dap:
 db 0x10	;size
 db 0		;reserved
 dw 8
offset: dw 0
segm: dw 0x800
lba: dq 1	

bootcall: db 0
bootdrive: db 0

gdt:
 dd 0
 dd 0

 ;32bit code
 dw 0xFFFF ; end
 dw 0 ; base low 16bits
 db 0 ; base mid 8 bits
 db 0x9A ; rx
 db 0xCF ; flags
 db 0 ; base high 8 bits
 ;32bit data
 dw 0xFFFF
 dw 0
 db 0
 db 0x92; rw
 db 0xCF
 db 0

 ;16 bit code
 dw 0xFFFF
 dw 0
 db 0
 db 0x9A
 db 0
 db 0
 ;16bit data
 dw 0xFFFF
 dw 0
 db 0
 db 0x92
 db 0
 db 0
gdt_descriptor:
 dw gdt_descriptor-gdt -1
 dd gdt




[bits 32]
interrupt_test: ; bootcall_diskread al = diskoperation, ebx = lba, ecx = buffer
                ; if al = 0, bootcall_writescreen, ebx= symbols, ecx = buffer
    cli

    mov [bootcall], al
    mov [lba], ebx

    mov eax, ecx
    shr eax, 4
    and ecx, 0x0F

    mov [offset], cx
    mov word [segm], ax

    pushad
    mov [saved_esp], esp
    sidt [saved_idt]
    jmp 0x18:.pm16

[bits 16]
.pm16:
    mov bx, 0x20
    mov ds, bx
    mov es, bx
    mov ss, bx


    mov eax, cr0
    and eax, ~1
    mov cr0, eax

    jmp 0:.rm16
.rm16:
    xor bx,bx
    mov ds, bx
    mov es, bx
    mov fs, bx
    mov gs, bx
    mov ss, bx
    mov sp,0x6ff8
    lidt [real_idt]


    mov ah, [bootcall]
    cmp ah, 0
    jne .disk
.print:
    mov si, [offset]
    mov ax, [segm]
    mov gs, ax

    mov cx, [lba]
    jcxz .end
.loop:
    mov ah, 0x0e
    mov al, [gs:si]
    xor bx, bx
    sti
    int 0x10
    cli

    inc si
    dec cx
    jnz .loop
    jmp .end

.disk:
    mov si, dap
    mov al, 0
    mov dl, [bootdrive] ; boot disk
    sti
    int 0x13
    cli

.end:
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x8:.pm32

[bits 32]
.pm32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov gs, ax
    mov ss, ax
    mov fs, ax

    mov esp, [saved_esp]
    lidt [saved_idt]
    popad

    iret

times 510 - ($-$$) db 0
dw 0xAA55
