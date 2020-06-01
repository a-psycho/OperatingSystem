org 0x07c00

;栈顶地址为0x0000:7c00
BaseOfStack equ 0x7c00
;loader的装载地址
BaseOfLoader equ 0x1000
OffsetOfLoader equ 0x00

;FAT12引导扇区结构
jmp boot_begin
nop
BS_OEMName db 'MINEBOOT'
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
BS_FileSysType db 'FAT12   '

;boot用到的变量
SectorNo dw 19
LoaderName db "LOADER  BIN"
CurrentLoaderBinOffset dw 0
BootMsg db "Start boot"
ErrorMsg db "ERROR:No Loader Found"
;boot开始代码
boot_begin:
	mov ax,cs
	mov ds,ax
	mov ss,ax
	mov es,ax
	mov sp,BaseOfStack

	;clear screen
	mov ax,0600h
	mov bx,0700h
	mov cx,0
	mov dx,0ffffh
	int 10h

	mov cx,10
	mov dx,0
	mov bp,BootMsg
	mov bx,7
	mov ax,1301h
	int 10h	
	
	;计算根目录占用扇区数
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
	jz NoLoaderBin
	mov ax,[SectorNo]
	mov cl,1
	mov bx,8000h
	call Func_ReadSector
	inc word [SectorNo]
	dec dx
	mov ch,10h	;一个扇区有512/32=16个文件结构体	
	mov di,8000h
loop_SearchInSector:
	mov si,LoaderName
	cmp ch,0
	jz loop_SearchInRootDir
	dec ch
	mov cl,11
	push di
cmp_FileName:
	cmp cl,0
	jz LoaderBinFounded
	lodsb
	cmp al,[di]
	jz cmp_go_on
	pop di
	add di,32
	jmp loop_SearchInSector
cmp_go_on:
	inc di
	dec cl
	jmp cmp_FileName
NoLoaderBin:
	mov cx,21
	mov dh,1
	mov dl,0
	mov bp,ErrorMsg
	mov bh,0
	mov bl,10000100b
	mov ax,1301h
	int 10h	
	jmp $
LoaderBinFounded:
	pop di
	add di,0x1A
	mov ax,[di]
	mov word [CurrentLoaderBinOffset],OffsetOfLoader
loadNextClus:
	push ax
	sub ax,2
	mov ch,0
	mov cl,[BPB_SecPerClus]
	mul cx
	add ax,33
	mov bx,BaseOfLoader
	mov es,bx
	mov bx,[CurrentLoaderBinOffset]
	call Func_ReadSector
	add word [CurrentLoaderBinOffset],512
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
	jc loadNextClus
	jmp BaseOfLoader:OffsetOfLoader

;用相对扇区格式从软盘中读取多个扇区
;参数格式为 ax:相对扇区号 cl:读入扇区个数 es:bx：数据缓冲区
Func_ReadSector:
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
	ret
	
;获取下一个簇号
;参数格式为 ax:当前簇号
;输出为： ax:下一个簇号
;当前加载到内存的扇区号
SectorInMemory dw 0
;奇偶标志
IsOdd db 0
Func_GetNextClus:
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
	mov ax,[di]
	cmp byte [IsOdd],1
	jz lab1
	and ax,0fffh
	jmp fun_exit
lab1:
	and ax,0fff0h
	shr ax,4
fun_exit:
	pop bp
	ret

times 510-($-$$) db 0
dw 0xaa55
