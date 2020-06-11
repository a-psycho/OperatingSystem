# 保护模式之分段机制

## Notice

* 开启保护模式时分段机制是自动开启的，分页机制是可选的
* 段寄存器不再保存基地址，而是保存段选择子（Selector）
* GDTR和LDTR均为48bytes

## 简略表示保护模式下的分段机制

段寄存器中保持的段选择子在GDTR/LDTR指向的地址空间中的GDT/LDT中找到段描述符，段描述符中有保存有段基地址、段长度、权限管理相关数据。( Selector -> GDTR/LDTR -> GDT/LDT -> Segment_Descriptor)

<img src="C:\Users\cao\Desktop\os\notes\pictures\Protect_Mode_Conclusion.png" alt="总结" style="zoom:80%;" />

## 段选择子（Selector）

![Selecor](C:\Users\cao\Desktop\os\notes\pictures\Selector.png)

|         T         |                T 为1时指向LDT，为0时指向GDT                 |
| :---------------: | :---------------------------------------------------------: |
|        RPL        |                         请求特权级                          |
| 描述符索引(index) | 在GDT/LDT中选择段描述符，index * 8 即可找到段描述符的offset |

段寄存器加入了隐藏的缓冲区域，加载后的段描述符缓存在该区域，避免每条指令都访问GDT。

## GDTR寄存器

![GDTR](C:\Users\cao\Desktop\os\notes\pictures\GDTR.png)

保存GDT的基地址，GDT的第0项为空段选择子（NULL Segment Selector），处理器的CS/SS不能加载NULL段选择子，其他段寄存器可以用空段选择子进行初始化。

## 段描述符

![Segment Descriptor](C:\Users\cao\Desktop\os\notes\pictures\Segment_Descriptor.png)

|  段长度  |                   20位，与G标志位一起使用                    |
| :------: | :----------------------------------------------------------: |
| 段基地址 |         32位，可指向保护模式支持最大空间4GB任意位置          |
|    S     |               复位为系统段，置位为code/data段                |
|   DPL    |                         描述符特权级                         |
|    P     |              表示该段是否在内存中，1为在内存中               |
|   AVL    |                          设为0即可                           |
|    L     |                     保留使用，设为0即可                      |
|   D/B    |               代码段数据位宽，1为32位，0为16位               |
|    G     | 指定段长度的颗粒度，1为4kb为颗粒度（段长为4GB），0为字节颗粒度（段长为1MB） |
|   TYPE   |                  占4位，对S标志位进一步解释                  |

这里只对code/data段描述符进行TYPE讲解  

* 当S为0，TYPE[3]为1时，该段为代码段
  * TYPE为 1110b 表示一致性、可读、未访问
* 当S为0，TYPE[3]为0时，该段为数据段
  * TYPE为 0010b 表示向上扩展、可读写、未访问

