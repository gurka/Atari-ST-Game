	section text

	; Run game
	; Reserved registers:
	; d6 = player_y
	; d7 = counter
game:
	move.w	#90,d6
	clr.l	d7

	; Clear both screens
	jsr	clear_screen
	jsr	swap_screen
	jsr	clear_screen

	; Set new palette according to SPRITES.PI1
	move.w	#$0000,$ffff8240	; 0 (background color)
	move.w	#$0400,$ffff8242	; 1
	move.w	#$0444,$ffff8244	; 2
	move.w	#$0477,$ffff8246	; 3
	move.w	#$0666,$ffff8248	; 4
	move.w	#$0700,$ffff824a	; 5
	move.w	#$0777,$ffff824c	; 6
	move.w	#$0200,$ffff824e	; 7
	move.w	#$0760,$ffff8250	; 8
	move.w	#$0000,$ffff8252	; 9
	move.w	#$0000,$ffff8254	; a
	move.w	#$0000,$ffff8256	; b
	move.w	#$0000,$ffff8258	; c
	move.w	#$0000,$ffff825a	; d
	move.w	#$0000,$ffff825c	; e
	move.w	#$0000,$ffff825e	; f

	; Game loop
.loop:
	jsr	wait_vbl
	jsr	swap_screen
	jsr	clear_screen

	; Increase counter
	addq.w	#1,d7

	; Draw ship at 64,80
	lea	sprite_image,a0
	add.l	#34,a0
	move.l	screen_next,a1
	clr.w	d0		; Ship starts at 0,0
	clr.w	d1
	move.w	#64,d2		; Draw at 64,player_y
	move.w	d6,d3
	move.w	#32,d4		; Size of ship is 32,23
	move.w	#23,d5
	jsr	copy_image

	; Draw fire (one of three based on counter)
	; TODO: Shouldn't we be able to calculate this
	;       simply with some shifts or mulu?
	;         source_x = (counter % 4) * 16
	;                  = (counter % 4) << 4
	;       would yield:
	;         0, 16, 32, 48
	;       Just need to make a 4th fire sprite...
	move.b	d7,d0
	lsr	#1,d0
	and.b	#3,d0		; counter % 4

	beq.s	.fire_0
	cmp	#1,d0
	beq.s	.fire_1
	cmp	#2,d0
	beq.s	.fire_2
	bra.s	.fire_1

.fire_0:
	clr.w	d0
	bra.s	.fire_draw
	
.fire_1:
	move.w	#16,d0
	bra.s	.fire_draw

.fire_2:
	move.w	#32,d0
	;bra.s	fire_draw

.fire_draw:
				; Fire starts at x,23
	move.w	#23,d1
	move.w	#48,d2		; Draw at 48,player_y+12
	move.w	d6,d3
	add.w	#13,d3
	move.w	#16,d4		; Size of fire is 16,7
	move.w	#7,d5
	jsr	copy_image

	; Run until enter is pressed
	cmp.b	#28,$fffc02
	bne	.loop

	rts

	section data

sprite_image	incbin SPRITES.PI1

	;section bss
