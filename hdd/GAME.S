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

	; Setup screen buffers
	move.l	#screen_buffer,d0
	clr.b	d0
	move.l	d0,screen_curr
	add.l	#32000,d0
	move.l	d0,screen_next

	; Run intro
	jsr	intro

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

	; Run intro
	; Reserved registers:
	; d7 = counter
intro:
	; Clear the screen
	jsr	clear_screen

	; Set palette
	move.w	#$0000,$ffff8240	; 0 (background color)
	move.w	#$0003,$ffff8242	; 1 (1 to 7 and 0 is font color)
	move.w	#$0004,$ffff8244	; 2
	move.w	#$0005,$ffff8246	; 3
	move.w	#$0017,$ffff8248	; 4
	move.w	#$0067,$ffff824a	; 5
	move.w	#$0027,$ffff824c	; 6
	move.w	#$0047,$ffff824e	; 7
	move.w	#$0777,$ffff8250	; 8 (star color)
	move.w	#$0000,$ffff8252	; 9
	move.w	#$0000,$ffff8254	; a
	move.w	#$0000,$ffff8256	; b
	move.w	#$0000,$ffff8258	; c
	move.w	#$0000,$ffff825a	; d
	move.w	#$0000,$ffff825c	; e
	move.w	#$0000,$ffff825e	; f

	; Setup stars
	lea	random_200,a0
	lea	random_320,a1
	lea	stars,a2
	move.w	#31,d1
.star_init:
	clr.b	(a2)+
	move.b	(a0)+,(a2)+
	move.w	(a1)+,(a2)+
	dbra	d1,.star_init	

	; Adjust random indices
	move.w	#32,random_200_i
	move.w	#32,random_320_i

	; Counter
	clr.l	d7

	; Main loop
.loop:
	; Wait for VBL
	move.w	#37,-(sp)
	trap	#14
	addq.l	#2,sp

	; Increase counter
	addq.w	#1,d7

	IFD	DEBUG_SLOW
	; Only render each 16th VBL
	move.b	d7,d0
	and.b	#15,d0
	bne	.demo_loop
	ENDC
	
	; Swap screens
	move.l	screen_curr,d0
	move.l	screen_next,screen_curr
	move.l	d0,screen_next
	lsr.l	#8,d0
	move.b	d0,$ffff8203
	lsr.w	#8,d0
	move.b	d0,$ffff8201

	IFD	DEBUG_TIME
	; Time test
	move.w	#$707,$ffff8240
	ENDC
	
	; Clear screen
	jsr	clear_screen

	; Draw stars
	lea	stars,a0
	move.w	#31,d0
.draw_stars:
	move.w	0(a0),d1	; y position
	move.w	2(a0),d2	; x position
	move.l	screen_next,a1

	; Find correct line
	mulu	#160,d1		; 160 bytes per line
	add.w	d1,a1

	; Find correct group
	move.w	d2,d3
	lsr	#1,d3
	and.w	#$fff8,d3
	add.w	d3,a1

	; Fetch mask
	; mask index = group index = x % 16
	; offset in pixel_mask = (x % 16) << 1
	;                      = (x & 15) << 1
	; (each mask is 2 bytes)
	move.w	d2,d3
	and.w	#15,d3
	lsl	#1,d3
	lea	pixel_mask,a2
	add.w	d3,a2
	move.w	(a2),d3

	; Write mask to bitplane 4, which will make the
	; final color %1000 = 8
	add.w	#6,a1
	or.w	d3,(a1)

	; Move star
	add.w	#-1,d2
	move.w	d2,2(a0)
	tst.w	d2
	bpl	.star_alive
	
	; Star is outside the screen, pick a new y position
	lea	random_200,a1
	add.w	random_200_i,a1
	add.w	#1,random_200_i
	and.w	#511,random_200_i	; cap index to 512
	clr.w	d1
	move.b	(a1),d1
	
	; Set new x and y
	move.w	d1,0(a0)
	move.w	#319,2(a0)

.star_alive:
	; Next star
	add.w	#4,a0

	dbra	d0,.draw_stars

	; Draw text
	;
	; From 0s to 2s we draw nothing
	; From 2s       we draw GAMENAME
	; From 4s to 5s we draw    AWFUL
	; From 5s to 6s we draw   SUMMER
	; From 6s to 7s we draw      JAM
	; From 7s       we draw     2018

	cmp.w	#100,d7		; Time to draw GAMENAME?
	blt	.text_end	; Not yet
	
	lea	gamename_str,a0
	move.w	#32,d1
	move.w	#32,d2
	jsr	draw_text

	cmp.w	#350,d7		; Time to draw 2018?
	bge	.text_2018

	cmp.w	#300,d7		; Time to draw JAM?
	bge	.text_jam

	cmp.w	#250,d7		; Time to draw SUMMER?
	bge	.text_summer

	cmp.w	#200,d7		; Time to draw AWFUL?
	bge	.text_awful

	bra.s	.text_end

.text_2018:
	lea	year_str,a0
	move.w	#160,d1
	move.w	#128,d2
	jsr	draw_text
	bra.s	.text_end

.text_jam:
	lea	jam_str,a0
	move.w	#192,d1
	move.w	#128,d2
	jsr	draw_text
	bra.s	.text_end

.text_summer:
	lea	summer_str,a0
	move.w	#96,d1
	move.w	#128,d2
	jsr	draw_text
	bra.s	.text_end

.text_awful:
	lea	awful_str,a0
	move.w	#128,d1
	move.w	#128,d2
	jsr	draw_text
	;bra.s	.text_end

.text_end:
	IFD	DEBUG_TIME
	; Time test
	move.w	#$0,$ffff8240
	ENDC

	; Loop if spacebar not pressed
	cmp.b	#$39,$fffc02
	bne	.loop

	rts

	; Draw ASCII text pointer to in a0 to screen at d1=x, d2=y
	; NOTE: x must be a multiple of 16 (for now)
	; NOTE: make sure that the text will fit (each character is 32x32 pixels)
draw_text:
	move.b	(a0)+,d0
	beq	.end		; Stop at null terminator
	jsr	draw_char
	add.w	#32,d1
	bra.s	draw_text
.end:
	rts

	; Draw ASCII character in d0 to screen at d1=x, d2=y
	; NOTE: x must be a multiple of 16 (for now)
	; Basically just a sprite blit with a bit of special handling for locating
	; the correct character in the font image buffer
draw_char:
	; Save registers
	movem.l	d0-d4/a0-a1,-(sp)

	; Make a0 point to start of the given character in the font image buffer
	and.l	#$ff,d0		; Make sure that there are no junk in the higher bytes of d0
	add.b	#-$20,d0	; Align ASCII with font number
	divu	#10,d0		; 10 letters per row

	move.w	d0,d3		; d3 contains font y value
	swap	d0
	move.w	d0,d4		; d4 contains font x value

	lsl	#4,d4		; x * 16 (16 bytes per letter)
	lsl	#5,d3		; y * 32 (32 lines per row)
	mulu	#160,d3		; 160 bytes per row

	lea	font,a0		; font image buffer start in a0
	add.w	#34,a0
	add.w	d3,a0		; adjust with font y value
	add.w	d4,a0		; adjust with font x value

	; Now make a1 point to the correct location in the screen buffer
	and.w	#$fff0,d1	; Make sure that x is a multiple of 16
	
	move.l	screen_next,a1	; a1 points to start of screen buffer

	; Find correct line
	mulu.w	#160,d2		; 160 bytes per line
	add.w	d2,a1

	; Find correct group
	lsr.w	#1,d1
	and.w	#$fff8,d1
	add.w	d1,a1

	; Now we just want to copy 32 * 32 pixels
	; e.g. copy 16 bytes then skip (160 - 16) 144 bytes and repeat 32 times
	move.w	#31,d0
.loop:
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	add.l	#144,a0
	add.l	#144,a1
	dbf	d0,.loop

	; Restore registers
	movem.l	(sp)+,d0-d4/a0-a1
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

	; 512 bytes of random bytes 0..199
random_200	incbin R200.BIN
random_200_i	dc.w	0

	; 1024 bytes of random words 0..319
random_320	incbin R320.BIN
random_320_i	dc.w	0

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

font		incbin FONT.PI1

gamename_str	dc.b	"GAMENAME", 0
awful_str	dc.b	"AWFUL", 0
summer_str	dc.b	"SUMMER", 0
jam_str		dc.b	"JAM", 0
year_str	dc.b	"2018", 0

	section bss

old_palette	ds.l	8
		ds.b	255
screen_buffer	ds.b	64000

	; 32 stars: 2b y pos, 2b x pos
stars		ds.w	32*2
