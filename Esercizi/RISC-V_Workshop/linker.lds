OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
	ram (wxa) : ORIGIN = 0x80000000, LENGTH = 1M
}

SECTIONS
{
	.init : { *(.init) } >ram
	.text : { *(.text) } >ram
	.data : { *(.data) } >ram
	.sdata : { *(.sdata) } >ram
	.bss : { *(.bss) } >ram
	.sbss : { *(.sbss) } >ram
	.stack :
	{
		. = ALIGN(16);
		. += 800;
		_stack_top = .;
	} >ram
}
