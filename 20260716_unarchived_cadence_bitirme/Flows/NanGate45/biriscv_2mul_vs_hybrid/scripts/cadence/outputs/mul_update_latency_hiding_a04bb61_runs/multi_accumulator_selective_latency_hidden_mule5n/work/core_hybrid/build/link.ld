ENTRY(_start)

SECTIONS
{
    . = 0x80000000;

    .text : {
        *(.text*)
        *(.rodata*)
    }

    . = ALIGN(4);
    .data : {
        *(.data*)
        *(.sdata*)
        *(.bss*)
        *(.sbss*)
        *(COMMON)
    }

    /DISCARD/ : {
        *(.comment)
        *(.riscv.attributes)
        *(.note*)
    }
}