bits 16
org 0x7C00

_start:
    xor ax, ax ; устанавливаем сегменты
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp,0x7BF8 ; устанавливаем стек

    mov [bootdrive], dl ; bios записывает номер диска в dl регистр

    in al, 0x92 ; включаем адресную шину a20
    or al, 2
    out 0x92, al

    ; читаем диск
    mov si, dap ; таблица с данными о том, что читаем
    mov ax, 0x4200 ; операция чтения
    mov dl, [bootdrive] ; номер диска
    int 0x13 ; прерывание биос

    call get_memory_map ; фукнция получения карты памяти

    cli
    mov bx, 0xDEAD; даем знать что мы из загрузчика
    jmp switch_mem_mode


[bits 16]
get_memory_map:
    mov di, 0x5004 ; откуда начнутся записи в карте памяти
    xor bp, bp ; счетчик записей
    xor ebx, ebx ; согласно документации обнуляем ebx перед циклом

.loop:
    mov eax, 0xE820 ; магическое число по документации
    mov edx, 0x534D4150 ; 2ое магическое число по документации
    mov ecx, 24 ; размер записи(тоже по документации)
    int 0x15 ; прерывание биос

    jc .done ; проверяем carry flag, если он установлен, то карта памяти закончена(или произошла ошибка)
    cmp eax, 0x534D4150
    jne .done ; проверяем магическое число, если оно не совпадает, то карта памяти закончена(или произошла ошибка)

    jcxz .skip_entry ; если cx 0(если запись равна 0 байт), то пропускаем прибавление

    add di, 24 ; прибавляем к указателю на текущую запись размер записи
    inc bp ; прибавляем счетчик записей

.skip_entry:
    test ebx, ebx ; если ebx 0, то карта памяти закончена
    jne .loop

.done:
    mov [0x5000], bp ; записываем счетчик в память
    ret



saved_esp:
 dd 0x6ff8 ; указатель на стек
saved_idt:
 dw end_idt-start_idt-1 ; размер idt
 dd start_idt ; начало idt

start_idt:
 dw bootcall_interrupt ; младшие 2 байта адреса обработчика прерывания
 dw 0x08 ; сегмент кода прерывания
 db 0 ; зарезервировано(всегда 0)
 db 0x8E ; флаг доступа(только ring0)
 dw 0 ; старшие 2 байта адреса обработчика. тут 0

end_idt:

real_idt:; таблица прерываний биос
 dw 0x3FF ; размер такой
 dd 0 ; начало в нуле

align 16
dap:
 db 0x10	;размер структуры(всегда 0x10)
 db 0		;всегда 0
count: dw 64      ;количество секторов, которые мы читаем. в байтах 64*512=32k
offset: dw 0;адрес буфера
segm: dw 0x800;и сегмент буфера
lba: dq 1;адрес в диске

bootcall: db 0;номер boot вызова
bootdrive: db 0;номер загрузочного диска

gdt:
 dw gdt_end-gdt -1 ; размер gdt
 dd gdt; начало gdt
 dw 0; padding

 ;32bit code - сегмент 0x8
 dw 0xFFFF ; конец
 dw 0 ; начало младшие 16бит
 db 0 ; начало среднии 8бит
 db 0x9A ; права доступа(читать и исполнять)
 db 0xCF; флаги 32х битного режима
 db 0 ; начало старшие 8бит
 ;32bit data
 dw 0xFFFF; конец
 dw 0; начало младшие 16бит
 db 0; начало среднии 8бит
 db 0x92; права доступа(читать и записывать)
 db 0xCF; флаги 32х битного режима
 db 0; начало старшие 8бит

 ;16 bit code
 dw 0xFFFF
 dw 0
 db 0
 db 0x9A
 db 0; флаги 16ти битного режима
 db 0
 ;16bit data
 dw 0xFFFF
 dw 0
 db 0
 db 0x92
 db 0; флаги 16ти битного режима
 db 0
gdt_end:





[bits 32]
bootcall_interrupt: ; bootcall_diskread al = diskoperation, ebx = lba, ecx = buffer, dx = count
                    ; if al = 0, bx=0 bootcall_writescreen, ecx = buffer, dx = count
                    ; if al = 0, bx!=0 bootcall_selectvideomode, bx=mode
    cli; отключаем прерывания для безопасности

    mov [bootcall], al; сохраняем номер операции
    mov [lba], ebx;сохраняем ebx
    mov [count], dx;сохраняем dx

    mov eax, ecx ; ковертируем адрес буфера в сегмент и оффсет
    shr eax, 4
    and ecx, 0x0F

    mov [offset], cx
    mov word [segm], ax

    pushad ; сохраняем регистры
    mov [saved_esp], esp; сохраняем стек
    sidt [saved_idt];сохраняем таблицу прерываний
    jmp 0x18:.pm16; длинный прыжок в 16ти битный защищенный режим

[bits 16]
.pm16:
    mov bx, 0x20; устанавливаем сегменты данных(16bit data)
    mov ds, bx
    mov es, bx
    mov ss, bx

    mov eax, cr0; переходим в реальный режим
    and eax, ~1
    mov cr0, eax

    jmp 0:.rm16 ; длинный прыжок в реальный режим
.rm16:
    xor bx,bx; устанавливаем сегменты данных
    mov ds, bx
    mov es, bx
    mov fs, bx
    mov gs, bx
    mov ss, bx
    mov sp,0x7BF8; устанавливаем стек
    lidt [real_idt]; загружаем таблицу прерываний реального режима


    mov ah, [bootcall];читаем из памяти код операции
    cmp ah, 0
    jne .disk; если 0, то это чтение. иначе дисковая операция

    mov di, [offset]; записываем в di оффсет, а в es сегмент. во всех операциях с дисплеем они используются
    mov ax, [segm]
    mov es, ax

    mov bx, [lba] ; если второй аргумент 0, то это вывод на экран, иначе переключение режима
    cmp bx, 0
    je .print
    sti
.switch_mode:
    mov ax, 0x4F01 ; получение информации об режиме
    mov cx, [lba]
    int 0x10; прерывание биос

    mov ax, 0x4F02; переключение режима
    mov bx, [lba]
    or bx, 0x4000
    int 0x10
    cli
    jmp .end

.print:
    mov cx, [count]
    jcxz .end
.loop:
    mov ah, 0x0e
    mov al, [es:di]; выводим символ из es*16+di
    xor bx, bx
    sti; временно включаем прерывания
    int 0x10; прерывание биос
    cli; опять отключаем

    inc di
    dec cx
    jnz .loop;повтор
    jmp .end

.disk:
    mov si, dap ; таблица с данными о том, что читаем
    mov ah, [bootcall] ; операция
    mov al, 0
    mov dl, [bootdrive] ; номер диска
    sti; временно включаем прерывания
    int 0x13 ; прерывание биос
    cli; опять отключаем

.end:
switch_mem_mode:
    lgdt [gdt];опять переходим в 32х битный защищенный режим
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x8:.pm32

[bits 32]
.pm32:
    mov ax, 0x10; восстанавливаем сегменты данных
    mov ds, ax
    mov es, ax
    mov gs, ax
    mov ss, ax
    mov fs, ax

    mov esp, [saved_esp]; восстанавливаем стек
    lidt [saved_idt]; и idt

    cmp bx, 0xDEAD; проверяем вызываемся из кода загрузчика или из прерывания
    jne .int
    jmp 0x8000 ; если из кода загрузчика, то прыгаем в начало ядра

.int: ; если из прерывания
    popad; восстанавливаем регистры

    iret; возврат из прерывания

times 510 - ($-$$) db 0
dw 0xAA55
