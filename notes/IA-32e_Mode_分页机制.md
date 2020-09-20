# IA-32e模式下的分页机制

## Notice

* 开启IA-32e模式必须伴随分页机制的开启，而且对IA-32模式下的分段机制进行了简化
* 寄存器CR3指向顶层页表PML4的物理基地址
* PML4支持4KB、2MB和１GB的物理页

## 总结

通过四级页表可寻址4KB的物理页；通过三级页表可寻址2MB的物理页；通过二级页表可以寻址１GB的物理页；

![Paging](C:\Users\cao\Desktop\os\notes\pictures\IA-32e_mode_Paging.png)

## 各级页表的页表项说明

![PML4/PDPT/PDT/PT](C:\Users\cao\Desktop\os\notes\pictures\PML4_PDPT_PDT_PT.png)