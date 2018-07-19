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

	; Setup IKBD handler
	move.w	#34,-(sp)		; Retrieve IKBD vector table
	trap	#14
	addq.l	#2,sp

	move.l	d0,ikbd_vec		; Store IKBD vector addr
	move.l	d0,a0
	move.l	24(a0),old_joy		; Backup old joystick vector
	move.l	#read_joy,24(a0)	; Install new joystick vector

	move.l	#joy_on,-(sp)		; Configure IKBD with joystick on
	move.w	#0,-(sp)
	move.w	#25,-(sp)
	trap	#14
	addq.l	#8,sp

	; Setup screen buffers
	move.l	#screen_buffer,d0
	clr.b	d0
	move.l	d0,screen_curr
	add.l	#32000,d0
	move.l	d0,screen_next

	; Run intro
	jsr	clear_regs
	jsr	intro

	; Run game
	jsr	clear_regs
	jsr	game

	; Restore IKBD handler
	move.l	#mouse_on,-(sp)		; Configure IKBD with mouse on
	move.w	#0,-(sp)
	move.w	#25,-(sp)
	trap	#14
	addq.l	#8,sp

	move.l	ikbd_vec,a0		; Restore joystick vector
	move.l	old_joy,24(a0)

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
	move.l	#old_palette,a0
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

clear_regs:
	clr.l	d0
	clr.l	d1
	clr.l	d2
	clr.l	d3
	clr.l	d4
	clr.l	d5
	clr.l	d6
	clr.l	d7
	move.l	#0,a0
	move.l	#0,a1
	move.l	#0,a2
	move.l	#0,a3
	move.l	#0,a4
	move.l	#0,a5
	move.l	#0,a6
	rts	

read_joy:
	move.b	1(a0),joy_data
	move.b	2(a0),joy_data+1
	rts

swap_screen:
	move.l	d0,-(sp)
	move.l	screen_curr,d0
	move.l	screen_next,screen_curr
	move.l	d0,screen_next
	lsr.l	#8,d0
	move.b	d0,$ffff8203
	lsr.w	#8,d0
	move.b	d0,$ffff8201
	move.l	(sp)+,d0
	rts

wait_vbl:
	; Time test
	IFD	DEBUG_TIME
	move.w	#$0,$ffff8240
	ENDC

	; Wait for VBL
	move.w	#37,-(sp)
	trap	#14
	addq.l	#2,sp

	; Time test
	IFD	DEBUG_TIME
	move.w	#$707,$ffff8240
	ENDC

	rts

	; Copies a chunk from the source buffer to the
	; destination buffer
	;
	; a0 = source buffer (must be 320x200)
	; a1 = dest buffer   (must be 320x200)
	; d0 = source x      (must be multiple of 16)
	; d1 = source y
	; d2 = dest x        (must be multiple of 16)
	; d3 = dest y
	; d4 = width	     (must be multiple of 16)
	; d5 = height
copy_image:
	; Save registers
	movem.l	d0-d5/a0-a1,-(sp)

	; Remove junk in high registers
	and.l	#$ffff,d0
	and.l	#$ffff,d1
	and.l	#$ffff,d2
	and.l	#$ffff,d3
	and.l	#$ffff,d4
	and.l	#$ffff,d5

	; Make sure that source x, dest x and width are multiple of 16
	and.b	#$f0,d0
	and.b	#$f0,d2
	and.b	#$f0,d4

	; Adjust a0 with source y
	mulu	#160,d1		; 160 bytes per line
	add.l	d1,a0

	; Adjust a0 with source x
	lsr.w	#1,d0		; 4bpp
	add.l	d0,a0

	; Adjust a1 with dest y
	mulu	#160,d3		; 160 bytes per line
	add.l	d3,a1

	; Adjust a0 with dest x
	lsr.w	#1,d2		; 4bpp
	add.l	d2,a1

	; Prepare for copy
	; We need:
	; d0 = number of groups to copy each line minus one (1 group = 8 bytes)
	; d1 = number of bytes to skip after each line (160 - (width / 2)), or
	;                                              (160 - (num_groups * 8))
	; d5 = number of lines to copy (height)

	; Set d1 to number of bytes to skip after each line
	move.w	#160,d1		; d1 = 160
	lsr.w	#1,d4		; d4 = width / 2
	sub.w	d4,d1		; d1 = 160 - (width / 2)

	; Set d0 to number of groups to copy each line
	lsr.w	#3,d4		; (width / 2) / 8 = width / 16
	add.w	#-1,d4
	move.l	d4,d0

	; d5 - 1 due to dbra
	add.w	#-1,d5

.loop:
	; d2 = number of groups to copy each line minus one
	move.w	d0,d2

.loop_group:
	; Copy one group
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+

	; Repeat until all groups have been copied
	dbra	d2,.loop_group

	; Go to next line in both buffers
	add.l	d1,a0
	add.l	d1,a1

	; Repeat until all lines have been copied
	dbra	d5,.loop

	; Restore registers
	movem.l	(sp)+,d0-d5/a0-a1
	rts

clear_screen:
	; Screen buffer to a0
	move.l	screen_next,a0

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
.loop:
	; Clear 4 * 10 * 4 bytes = 160 bytes = 320 pixels = 1 line
	movem.l	d0-d6/a1-a3,-(a0)
	movem.l	d0-d6/a1-a3,-(a0)
	movem.l	d0-d6/a1-a3,-(a0)
	movem.l	d0-d6/a1-a3,-(a0)

	; Jump to end of next line (320 bytes = 640 pixels = 2 lines)
	lea	320(a0),a0
	dbra	d7,.loop

	; Restore registers
	movem.l	(sp)+,d2-d7/a2-a3
	rts

	section data

old_stack	dc.l	0
old_resolution	dc.w	0
old_screen	dc.l	0
screen_curr	dc.l	0
screen_next	dc.l	0

joy_on		dc.b	$14
mouse_on	dc.b	$08
ikbd_vec	dc.l	0
old_joy		dc.l	0

	; 512 bytes of random bytes 0..199
random_200	incbin R200.BIN
random_200_i	dc.l	0

	; 1024 bytes of random words 0..319
random_320	incbin R320.BIN
random_320_i	dc.l	0

pixel_mask	dc.w	%1000000000000000
		dc.w	%0100000000000000
		dc.w	%0010000000000000
		dc.w	%0001000000000000
		dc.w	%0000100000000000
		dc.w	%0000010000000000
		dc.w	%0000001000000000
		dc.w	%0000000100000000
		dc.w	%0000000010000000
		dc.w	%0000000001000000
		dc.w	%0000000000100000
		dc.w	%0000000000010000
		dc.w	%0000000000001000
		dc.w	%0000000000000100
		dc.w	%0000000000000010
		dc.w	%0000000000000001

	section bss

old_palette	ds.l	8
		ds.b	255
screen_buffer	ds.b	64000
joy_data	ds.b	2

	include	INTRO.S
	include	GAME.S
