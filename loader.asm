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
	
	jmp $

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

