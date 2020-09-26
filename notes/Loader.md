# Loader的编写

---

## Loader的任务

1. 检测硬件信息：包括物理地址空间信息，VBE功能（用于配置显示模式），这部分代码还未完善，会在后续更新
2. 处理器模式切换：这是最主要的部分，包括实模式到保护模式的切换，保护模式到IA-32模式的切换。
3. 想内核传递数据：包括控制信息和硬件数据信息，这部分代码也在后续完善。

---

## Loader代码编写流程

1. 初始化数据。数据部分都放在代码的最前面，包含有：

   + FAT12文件系统数据（同boot程序），在寻找kernel.bin文件时用到

   + 保护模式下的GDT数据
   + 保护模式下的IDT数据
   + IA-32模式下的GDT数据

2. 开启A20地址线进入big-read-mode下，找到kernel.bin文件，并加载到0x100000地址处。开启A20地址线，其实是使段寄存器fs达到32位的寻址能力，接着找到kernel.bin文件这部分的代码和boot中找到loader.bin文件的代码一样，只不过这里多了一步把kernel.bin从临时地址转到1MB以上的地址空间。

3. 接着就是进入保护模式，这部分比较死板，按照流程来就行，关键在保护模式下分段机制的理解，这部分内容在[分段机制](https://www.cnblogs.com/apsycho/p/13093080.html)中有详细说明。

4. 之后就是从保护模式跳转的IA-32模式，也是按照标准流程来。这里要重新准备GDT数据，因为64位模式下，分段机制做了简化，加入了分页机制，要创建临时页表项。

5. 处理器模式切换完成后就可以跳转到内核执行了。这里的代码流程还未完善，主要实现了处理器切换工作，对分段和分页也只是简单的设置应用。后续学习后会有补充。

---

## Loader的完整代码

```assembly
org 10000h
jmp loader_begin

;kernel起始地址
BaseOfKernel equ 0x00
OffsetOfKernel equ 0x100000
;临时kernel转存地址
BaseTmpOfKernel equ 0x00
OffsetTmpOfKernel equ 0x7e00
;内存信息缓冲区地址
MemoryStructBuffer equ 0x7e00

;FAT12文件系统数据
BS_OEMName db 'MINEBOOT' ;{{{
BPB_BytesPerSec dw 512
BPB_SecPerClus db 1
BPB_RsvdSecCnt dw 1
BPB_NumFATS db 2
BPB_RootEntCnt dw 224
BPB_TotSec16 dw 2880
BPB_Media db 0f0h
BPB_FATSz dw 9
BPB_SecPerTrk dw 18
BPB_NumHeads dw 2
BPB_HiddSec dd 0
BPB_TotSec32 dd 0
BS_DrvNum db 0
BS_Reservedl db 0
BS_BootSig db 29h
BS_VolID dd 0
BS_VolLab db 'boot loader'
BS_FileSysType db 'FAT12   ' ;}}}

;保护模式下GDT临时数据
GDT_32: ;{{{
	dq 0
DataDescriptor32:
	dq 0x00cf92000000ffff
CodeDescriptor32:
	dq 0x00cf9e000000ffff

GDTlen32 equ $-GDT_32
GDTR_32:
	dw GDTlen32 - 1
	dd GDT_32

SelectorDate32 equ 8
SelectorCode32 equ 8*2 ;}}}

;保护模式下IDT临时数据
IDT:	;{{{
	times 0x50 dq 0
IDTR:
	dw $-IDT-1
	dd IDT		;}}}

;IA-32模式下GDT临时数据
GDT_64: ;{{{
	dq 0
DataDescriptor64:
	dq 0x0000920000000000
CodeDescriptor64:
	dq 0x0020980000000000

GDTlen64 equ $-GDT_64
GDTR_64:
	dw GDTlen64 - 1
	dd GDT_64

SelectorDate64 equ 8
SelectorCode64 equ 8*2 ;}}}
	
;loader代码开始处
[BITS 16]
loader_begin:
	mov ax,cs
	mov ds,ax
	mov es,ax
	
	;打印LoaderMsg
	mov cx,12 ;{{{
	mov dx,0x0100
	mov bp,LoaderMsg
	mov bx,7
	mov ax,1301h
	int 10h	;}}}

	;开启A20地址线进入Big Real Mode	
	in al,92h ;{{{
	or al,2
	out 92h,al
	;禁用外部中断
	cli
	;加载临时页表
	db 0x66
	lgdt [GDTR_32]
	;开启保护模式
	mov eax,cr0
	or eax,1
	mov cr0,eax
	;为fs赋值
	mov ax,SelectorDate32
	mov fs,ax
	;关闭保护模式
	mov eax,cr0
	and al,11111110b
	mov cr0,eax
	;开启外部中断
	sti ;}}}

	;查找kernel.bin并加载到0x100000地址处
	;计算根目录占用扇区数	{{{
	mov ax,[BPB_RootEntCnt]
	mov cx,32
	mul cx
	mov cx,[BPB_BytesPerSec]
	mov dx,0
	mov dx,0
	div cx
	mov dx,ax
	;目标缓冲区为es:0h bx:8000h
	mov ax,0
	cld
loop_SearchInRootDir:
	cmp dx,0
	jz NoKernelBin
	mov ax,0
	mov es,ax
	mov ax,[SectorNo]
	mov cl,1
	mov bx,8000h
	call Func_ReadSector
	inc word [SectorNo]
	dec dx
	mov ch,10h	;一个扇区有512/32=16个文件结构体	
	mov di,8000h
loop_SearchInSector:
	mov si,KernelName
	cmp ch,0
	jz loop_SearchInRootDir
	dec ch
	mov cl,11
	push di
cmp_FileName:
	cmp cl,0
	jz KernelBinFounded
	lodsb
	cmp al,[es:di]
	jz cmp_go_on
	pop di
	add di,32
	jmp loop_SearchInSector
cmp_go_on:
	inc di
	dec cl
	jmp cmp_FileName
NoKernelBin:
	mov ax,cs
	mov es,ax
	mov cx,21
	mov dh,2
	mov dl,0
	mov bp,ErrorMsg
	mov bh,0
	mov bl,10000100b
	mov ax,1301h
	int 10h	
	jmp $
KernelBinFounded:
	pop di
	add di,0x1A
	mov ax,[es:di]
	mov dword [CurrentKernelBinOffset],OffsetOfKernel
loadNextClus:
	push ax
	sub ax,2
	mov ch,0
	mov cl,[BPB_SecPerClus]
	mul cx
	add ax,33
	mov ebx,BaseTmpOfKernel
	mov es,ebx
	mov bx,OffsetTmpOfKernel
	call Func_ReadSector
	;把转存区的512bytes移到0x100000往上的地址空间
	mov ecx,512
	mov ebx,BaseTmpOfKernel
	mov es,ebx
	mov esi,OffsetTmpOfKernel
	mov edi,[CurrentKernelBinOffset]
movKernel:
	mov al,[es:esi]
	mov [fs:edi],al
	inc esi
	inc edi
	loop movKernel
	mov dword [CurrentKernelBinOffset],edi
	pop ax
	call Func_GetNextClus
	push ax
	mov ch,0
	mov cl,[BPB_SecPerClus]
printDot:
	mov ah,0eh
	mov al,'.'
	mov bl,0fh
	int 10h
	loop printDot
	pop ax
	cmp ax,0ff8h
	jc loadNextClus		;}}}
	
	;设置SVGA显示模式
	;mov ax,4f02h	;{{{
	;mov bx,4180h
	;int 10h		;}}}

	;从real mode进入protect mode
	cli		;{{{
	db 0x66
	lgdt [GDTR_32]
	db 0x66
	lidt [IDTR]
	;开启保护模式
	mov eax,cr0
	or eax,1
	mov cr0,eax
	;跳转到保护模式下的临时代码
	jmp dword SelectorCode32:tmp_code_in_protect_mode		;}}}

[BITS 32]
;从protect mode进入IA-32 mode
tmp_code_in_protect_mode:
	
	;初始化段寄存器和栈指针
	mov ax,SelectorDate32	;{{{
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov ss,ax
	mov esp,7e00h	;}}}

	;初始化临时页表
	mov dword [90000h],91007h	;{{{
	mov dword [90800h],91007h

	mov dword [91000h],92007h

	mov dword [92000h],0x000083
	mov dword [92008h],0x200083
	mov dword [92010h],0x400083
	mov dword [92018h],0x600083
	mov dword [92020h],0x800083
	mov dword [92028h],0xa00083		;}}}

	;加载GDTR
	db 0x66		;{{{
	lgdt [GDTR_64]
	mov ax,SelectorDate64
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov ss,ax
	mov gs,ax
	mov esp,7e00h	;}}}

	;开启PAE以及初始化CR3
	mov eax,cr4		;{{{
	bts eax,5
	mov cr4,eax
	mov eax,90000h
	mov cr3,eax		;}}}

	;开启64位模式并开启分页机制
	mov ecx,0xc0000080		;{{{
	rdmsr
	bts eax,8
	wrmsr

	mov eax,cr0
	bts eax,0
	bts eax,31
	mov cr0,eax		;}}}

	;跳转到内核程序
	jmp SelectorCode64:OffsetOfKernel



[BITS 16]
;用相对扇区格式从软盘中读取多个扇区
;参数格式为 ax:相对扇区号 cl:读入扇区个数 es:bx：数据缓冲区
Func_ReadSector:	;{{{
	push bp
	mov bp,sp
	push ax
	push dx
	mov dl,[BPB_SecPerTrk]
	div dl
	inc ah
	mov dh,cl
	mov cl,ah
	mov ah,dh
	mov dh,al
	and dh,1
	shr al,1
	mov ch,al
	mov al,ah
	mov dl,[BS_DrvNum]
GoOnReading:
	mov ah,02h
	int 13h
	jc GoOnReading
	pop dx
	pop ax
	pop bp
	ret	;}}}
	
;获取下一个簇号
;参数格式为 ax:当前簇号
;输出为： ax:下一个簇号
;当前加载到内存的扇区号
SectorInMemory dw 0
;奇偶标志
IsOdd db 0
Func_GetNextClus: ;{{{
	push bp
	mov bp,sp
	mov bx,3
	mul bx
	mov bx,2
	mov dx,0
	div bx
	cmp dx,1
	jz setIsOdd
	mov byte [IsOdd],0
	jmp continue
setIsOdd:
	mov byte [IsOdd],1
continue:
	mov bx,512*3
	mov dx,0
	div bx
	push dx
	mov bx,3
	mul bx
	mov bx,[BPB_RsvdSecCnt]
	add ax,bx
	cmp ax,[SectorInMemory]
	jz getNextClus
	mov [SectorInMemory],ax
	mov cl,3
	mov bx,0
	mov es,bx
	mov bx,8000h
	call Func_ReadSector
getNextClus:
	pop di
	add di,8000h
	mov ax,[es:di]
	cmp byte [IsOdd],1
	jz lab1
	and ax,0fffh
	jmp fun_exit
lab1:
	and ax,0fff0h
	shr ax,4
fun_exit:
	pop bp
	ret ;}}}

;loader用到的变量
SectorNo dw 19
KernelName db "KERNEL  BIN"
CurrentKernelBinOffset dd 0
LoaderMsg db "Start loader"
ErrorMsg db "ERROR:No kernel Found"
```

