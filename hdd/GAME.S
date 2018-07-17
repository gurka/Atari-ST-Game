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
	move.w	#$0200,$ffff8242	; 1
	move.w	#$0400,$ffff8244	; 2
	move.w	#$0700,$ffff8246	; 3
	move.w	#$0555,$ffff8248	; 4
	move.w	#$0666,$ffff824a	; 5
	move.w	#$0777,$ffff824c	; 6
	move.w	#$0770,$ffff824e	; 7
	move.w	#$0477,$ffff8250	; 8
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

	; Move ship up/down if joy up/down is pressed
	move.b	joy_data+1,d0
	btst	#0,d0
	bne.s	.move_up
	btst	#1,d0
	bne.s	.move_down
	bra.s	.move_done

.move_up:
	; Move player up unless already at top (y = 0)
	cmp	#0,d6
	beq	.move_done
	add.w	#-1,d6
	bra.s	.move_done

.move_down:
	; Move player down unless already at bottom (y = 200-23)
	cmp	#177,d6
	beq	.move_done
	add.w	#1,d6
	;bra.s	.move_done

.move_done:
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

	; Draw fire
	; There are four fire sprites at
	; (0, 23), (16, 23), (32, 23) and (48, 23)
	move.b	d7,d0		; Draw at ((counter << 3) & 0x30), 23
	lsl.b	#3,d0
	and.w	#%110000,d0
	move.w	#23,d1
	move.w	#48,d2		; Draw at 48,player_y+12
	move.w	d6,d3
	add.w	#12,d3
	move.w	#16,d4		; Size of fire is 16,7
	move.w	#7,d5
	jsr	copy_image

	; Run until fire is pressed
	move.b	joy_data+1,d0
	btst	#7,d0
	beq	.loop

	rts

	section data

sprite_image	incbin SPRITES.PI1

	;section bss
