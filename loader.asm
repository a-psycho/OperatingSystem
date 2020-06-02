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
BS_OEMName db 'MINEBOOT' ;/*{{{*/
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
BS_FileSysType db 'FAT12   ' ;/*}}}*/

;loader代码开始处
[BITS 16]
loader_begin:
	mov ax,cs
	mov ds,ax
	mov es,ax
	
	;打印LoaderMsg
	mov cx,12 ;/*{{{*/
	mov dx,0
	mov bp,LoaderMsg
	mov bx,7
	mov ax,1301h
	int 10h	;/*}}}*/
	                                                     

	;开启A20地址线进入Big Real Mode	
	in al,92h
	or al,2
	out 92h,al
	;禁用外部中断
	cli
	;加载临时页表
	db 0x66
	lgdt []
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
	sti

	jmp $


;loader用到的变量
LoaderMsg db "Start loader"
ErrorMsg db "ERROR:No kernel Found"

