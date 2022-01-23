!   boot.s
!
! It then loads the system at 0x10000, using BIOS interrupts. Thereafter
! it disables all interrupts, changes to protected mode, and calls the 

BOOTSEG = 0x07c0            ! BOOT 将会被加载到内存的绝对地址 0x7C00 处
SYSSEG  = 0x1000            ! system loaded at 0x10000 (65536).
SYSLEN  = 17                ! sectors occupied.

entry start
start:
    jmpi    go,#BOOTSEG     ! （段间）长跳转到 0x7c00 + go(偏移量) 处
go: mov ax,cs
    mov ds,ax
    mov ss,ax
    mov sp,#0x400           ! arbitrary value >>512

! ok, we've written the message, now
load_system:
    mov dx,#0x0000
    mov cx,#0x0002
    mov ax,#SYSSEG
    mov es,ax
    xor bx,bx
    mov ax,#0x200+SYSLEN
    int     0x13
    jnc ok_load
die:    jmp die

! now we want to move to protected mode ...
ok_load:
    cli         ! no interrupts allowed ! 关中断
    mov ax, #SYSSEG
    mov ds, ax          ! ds = 0x10000
    xor ax, ax
    mov es, ax          ! es = 0x0
    mov cx, #0x2000
    sub si,si           ! ds : si = 0x10000 : 0000
    sub di,di           ! es : di = 0x00000 : 0000
    rep                 ! 移动内存，0x10000 => 0x00000
    movw
    mov ax, #BOOTSEG
    mov ds, ax          ! ds = 0x7c00
    lidt    idt_48      ! load idt with 0,0
    lgdt    gdt_48      ! load gdt with whatever appropriate

! absolute address 0x00000, in 32-bit protected mode.
    mov ax,#0x0001  ! protected mode (PE) bit
    lmsw    ax      ! This is it ! lmsw是加载机器状态字指令，后接16位寄存器或者内存地址。
    ! 其功能是用源操作数的低4位加载CR0，也就是说仅会影响CR0的低4位——PE, MP, EM, TS。
    jmpi    0,8     ! jmp offset 0 of segment 8 (cs)


! 定义了三个段描述符，其中第一个段不可用
gdt:    .word   0,0,0,0     ! dummy

    ! 第1个描述符定义了一个代码段，其基地址为0，界限值是0x7FF（10进制2047），
    ! 粒度4KB，DPL=0，非一致性，可读可执行。因为粒度是4KB，所以段长度是（2047+1）*4KB=8MB。
    .word   0x07FF      ! 8Mb - limit=2047 (2048*4096=8Mb)
    .word   0x0000      ! base address=0x00000
    .word   0x9A00      ! code read/exec
    .word   0x00C0      ! granularity=4096, 386

    ! 第2个描述符定义了一个数据段，其基地址为0，
    ! 界限值是0x7FF（10进制2047），粒度4KB，DPL=0，向上扩展，可读可写。同上，段长度是8MB。
    .word   0x07FF      ! 8Mb - limit=2047 (2048*4096=8Mb)
    .word   0x0000      ! base address=0x00000
    .word   0x9200      ! data read/write
    .word   0x00C0      ! granularity=4096, 386

idt_48: .word   0           ! idt limit=0
    .word   0,0             ! idt base=0L
gdt_48: .word   0x7ff       ! gdt limit=2048, 256 GDT entries
    .word   0x7c00+gdt,0    ! gdt base = 07xxx
.org 510
    .word   0xAA55

