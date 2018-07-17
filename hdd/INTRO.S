	section text

	; Run intro
	; Reserved registers:
	; d7 = counter
intro:
	; Clear the screen
	jsr	clear_screen

	; Set palette
	move.w	#$0000,$ffff8240	; 0 (background color)
	move.w	#$0000,$ffff8242	; 1 (1 to 7 and 0 is font color)
	move.w	#$0000,$ffff8244	; 2
	move.w	#$0000,$ffff8246	; 3
	move.w	#$0000,$ffff8248	; 4
	move.w	#$0000,$ffff824a	; 5
	move.w	#$0000,$ffff824c	; 6
	move.w	#$0000,$ffff824e	; 7
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
	jsr	wait_vbl

	; Increase counter
	addq.w	#1,d7

	IFD	DEBUG_SLOW
	; Only render each 16th VBL
	move.b	d7,d0
	and.b	#15,d0
	bne	.demo_loop
	ENDC

	; Swap screens
	jsr	swap_screen

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
	; From 0.8s     we draw SPACE 2.0 with 1s fade in time
	; From 4s to 6s we draw AWFUL SUMMER JAM 2018
	; From 6s to 8s we draw BY NIKANOR
	; From 8s       we draw PRESS FIRE TO START, blinking 
	cmp.w	#40,d7		; Time to draw SPACE 2.0?
	blt	.loop		; Not yet

	; Draw SPACE 2.0
	lea	text_image,a0
	add.l	#34,a0
	move.l	screen_next,a1
	clr.w	d0		; Texts start at 0,0
	clr.w	d1
	clr.w	d2		; Draw at 0,32
	move.w	#32,d3
	move.w	#272,d4		; Size of text is 272,32
	move.w	#32,d5
	jsr	copy_image

	; Handle fade in
	; at VBL  40 we set palette to: 001, 001, 001, 011, 011, 011, 011
	; at VBL  50 we set palette to: 002, 002, 002, 012, 022, 022, 022
	; at VBL  60 we set palette to: 003, 003, 003, 013, 033, 023, 033
	; at VBL  70 we set palette to: 003, 004, 004, 014, 044, 024, 044
	; at VBL  80 we set palette to: 003, 004, 005, 015, 055, 025, 045
	; at VBL  90 we set palette to: 003, 004, 005, 016, 066, 026, 046
	; at VBL 100 we set palette to: 003, 004, 005, 017, 067, 027, 047
	cmp.w	#40,d7
	beq	.fade_40
	cmp.w	#50,d7
	beq	.fade_50
	cmp.w	#60,d7
	beq	.fade_60
	cmp.w	#70,d7
	beq	.fade_70
	cmp.w	#80,d7
	beq	.fade_80
	cmp.w	#90,d7
	beq	.fade_90
	cmp.w	#100,d7
	beq	.fade_100
	bra	.fade_done

.fade_40:
	add.w	#$0001,$ffff8242
	add.w	#$0001,$ffff8244
	add.w	#$0001,$ffff8246
	add.w	#$0011,$ffff8248
	add.w	#$0011,$ffff824a
	add.w	#$0011,$ffff824c
	add.w	#$0011,$ffff824e
	bra	.fade_done

.fade_50:
	add.w	#$0001,$ffff8242
	add.w	#$0001,$ffff8244
	add.w	#$0001,$ffff8246
	add.w	#$0001,$ffff8248
	add.w	#$0011,$ffff824a
	add.w	#$0011,$ffff824c
	add.w	#$0011,$ffff824e
	bra	.fade_done

.fade_60:
	add.w	#$0001,$ffff8242
	add.w	#$0001,$ffff8244
	add.w	#$0001,$ffff8246
	add.w	#$0001,$ffff8248
	add.w	#$0011,$ffff824a
	add.w	#$0001,$ffff824c
	add.w	#$0011,$ffff824e
	bra	.fade_done

.fade_70:
	add.w	#$0001,$ffff8244
	add.w	#$0001,$ffff8246
	add.w	#$0001,$ffff8248
	add.w	#$0011,$ffff824a
	add.w	#$0001,$ffff824c
	add.w	#$0011,$ffff824e
	bra.s	.fade_done

.fade_80:
	add.w	#$0001,$ffff8246
	add.w	#$0001,$ffff8248
	add.w	#$0011,$ffff824a
	add.w	#$0001,$ffff824c
	add.w	#$0001,$ffff824e
	bra.s	.fade_done

.fade_90:
	add.w	#$0001,$ffff8248
	add.w	#$0011,$ffff824a
	add.w	#$0001,$ffff824c
	add.w	#$0001,$ffff824e
	bra.s	.fade_done

.fade_100:
	add.w	#$0001,$ffff8248
	add.w	#$0001,$ffff824a
	add.w	#$0001,$ffff824c
	add.w	#$0001,$ffff824e
	;bra.s	.fade_done

.fade_done:
	cmp.w	#400,d7		; Time to draw PRESS FIRE TO START?
	bge	.text_start

	cmp.w	#300,d7		; Time to draw BY NIKANOR?
	bge	.text_by

	cmp.w	#200,d7		; Time to draw AWFUL SUMMER JAM 2018?
	bge	.text_awful

	bra	.loop

.text_awful:
	; Draw AWFUL SUMMER JAM 2018
	lea	text_image,a0
	add.l	#34,a0
	move.l	screen_next,a1
	clr.w	d0		; Texts start at 0,32
	move.w	#32,d1
	clr.w	d2		; Draw at 0,128
	move.w	#128,d3
	move.w	#320,d4		; Size of text is 320,16
	move.w	#16,d5
	jsr	copy_image
	bra	.loop

.text_by:
	; Draw BY NIKANOR
	lea	text_image,a0
	add.l	#34,a0
	move.l	screen_next,a1
	clr.w	d0		; Texts start at 0,48
	move.w	#48,d1
	move.w	#160,d2		; Draw at 160,128
	move.w	#128,d3
	move.w	#160,d4		; Size of text is 160,16
	move.w	#16,d5
	jsr	copy_image
	bra	.loop

.text_start:
	; Draw PRESS FIRE TO START, but only if (VBL & 100) < 75
	; (so draw for 1.5s and nothing for 0.5s)
	move.w	d7,d0
	and.w	#100,d0
	cmp.w	#75,d0
	bge	.text_start2

	lea	text_image,a0
	add.l	#34,a0
	move.l	screen_next,a1
	clr.w	d0		; Texts start at 0,64
	move.w	#64,d1
	clr.w	d2		; Draw at 0,128
	move.w	#128,d3
	move.w	#304,d4		; Size of text is 304,16
	move.w	#16,d5
	jsr	copy_image
	
.text_start2:
	; Loop if spacebar not pressed
	cmp.b	#$39,$fffc02
	bne	.loop
	rts

	section data

text_image	incbin TEXT.PI1

	section bss

	; 32 stars: 2b y pos, 2b x pos
stars		ds.w	32*2
