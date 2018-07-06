	section text

	; Enter super mode
	clr.l	-(sp)
	move.w	#32,-(sp)
	trap	#1
	addq.l	#6,sp
	move.l	d0,old_stack

	; Save old palette
	move.l	#old_palette,a0
	movem.l	$ffff8240,d0-d7
	movem.l	d0-d7,(a0)

	; Save old screen address
	move.w	#2,-(sp)
	trap	#14
	addq.l	#2,sp
	move.l	d0,old_screen

	; Save old resolution
	move.w	#4,-(sp)
	trap	#14
	addq.l	#2,sp
	move.w	d0,old_resolution

	; Change to low resolution
	move.w	#0,-(sp)
	move.l	#-1,-(sp)
	move.l	#-1,-(sp)
	move.w	#5,-(sp)
	trap	#14
	add.l	#12,sp

	; Run demo
	jsr	demo

	; Restore old resolution
	move.w	old_resolution,d0
	move.w	d0,-(sp)
	move.l	old_screen,d0
	move.l	d0,-(sp)
	move.l	d0,-(sp)
	move.w	#5,-(sp)
	trap	#14
	add.l	#12,sp

	; Restore old palette
	move.l	old_palette,a0
	movem.l	(a0),d0-d7
	movem.l	d0-d7,$ffff8240

	; Enter user mode
	move.l	old_stack,-(sp)
	move.w	#32,-(sp)
	trap	#1
	addq.l	#6,sp

	; Quit
	clr.l	-(a7)
	trap	#1

demo:
	; Setup screen buffers
	move.l	#screen_buffer,d0
	add.l	#255,d0
	clr.b	d0
	move.l	d0,screen_curr
	add.l	#32000,d0
	move.l	d0,screen_next

	; Set palette
	clr.w	$ffff8240
	move.w	#$0070,$ffff825e

	; Counter (0..199)
	clr.l	d7

	; Main loop
.loop:
	; Wait for VBL
	move.w	#37,-(sp)
	trap	#14
	addq.l	#2,sp

	; Swap screens
	move.l	#screen_next,d0
	move.l	#screen_curr,screen_next
	move.l	d0,screen_curr
	lsr.w	#8,d0
	move.l	d0,$ffff8200.w

	; Clear screen
	jsr	clear_screen

	; Go to correct line in screen buffer
	; a6 = screen_next + (y * 160)
	move.l	d7,d6
	move.l	#160,d5
	mulu	d6,d5
	move.l	#screen_next,a6
	lea	(a6,d5),a6

	; Draw line (320 pixels to a6)
	; 320 pixels = 160 bytes = 80 w = 40 l
	; Color = 15
	add.b	#39,d6
.draw_line:
	clr.l	(a6)
	neg.l	(a6)
	adda	#4,a6
	dbra	d6,.draw_line

	; Increase counter,reset if 200
	addq.b	#1,d7
	cmp.b	#200,d7
	bne	.skip_counter
	clr.b	d7
.skip_counter:

	; Loop if spacebar pressed
	cmpi.b	#$39,$fffffc02
	beq	.loop

	rts

clear_screen:
	; Screen buffer to a0
	move.l	4(sp),a0

	; Save registers
	movem.l	d2-d7/a2-a3,-(sp)

	; Jump to end of first line (160 bytes = 320 pixels = 1 line)
	lea	160(a0),a0

	; Use 10 registers set to zero for filling the screen buffer
	moveq.l	#0,d0
	move.l	d0,d1
	move.l	d0,d2
	move.l	d0,d3
	move.l	d0,d4
	move.l	d0,d5
	move.l	d0,d6
	move.l	d0,a1
	move.l	d0,a2
	move.l	d0,a3

	; 200 lines (full screen)
	move.w	#199,d7
.loop2:
	; Clear 4 * 10 * 4 bytes = 160 bytes = 320 pixels = 1 line
	movem.l	d0-d6/a1-a3,-(a0)
	movem.l	d0-d6/a1-a3,-(a0)
	movem.l	d0-d6/a1-a3,-(a0)
	movem.l	d0-d6/a1-a3,-(a0)

	; Jump to end of next line (320 bytes = 640 pixels = 2 lines)
	lea	320(a0),a0
	dbra	d7,.loop2

	; Restore registers
	movem.l	(sp)+,d2-d7/a2-a3
	rts

	section data

old_stack	dc.l	0
old_resolution	dc.w	0
old_screen	dc.l	0
screen_curr	dc.l	0
screen_next	dc.l	0

	section bss

old_palette	ds.l	8
		ds.b	255
screen_buffer	ds.b	32000