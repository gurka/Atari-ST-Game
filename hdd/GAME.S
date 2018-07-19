	section text

	; Run game
	; Reserved registers:
	; d6 = player_y
	; d7 = counter
game:
	jsr	setup

	; Game loop
.loop:
	jsr	wait_vbl
	jsr	swap_screen
	jsr	clear_screen
	jsr	logic
	jsr	draw

	; Run for 10 seconds (500 VBLs)
	cmp.w	#500,d7
	bne	.loop

	rts


setup:
	; Clear random indices
	clr.w	random_200_i
	clr.w	random_320_i

	; Setup stars
	lea	random_200,a0
	lea	random_320,a1
	lea	stars_game,a2
	move.w	#31,d1
.star_setup_loop:
	clr.b	(a2)+
	move.b	(a0)+,(a2)+
	move.w	(a1)+,(a2)+
	dbra	d1,.star_setup_loop	

	; Adjust random indices
	move.w	#32,random_200_i
	move.w	#32,random_320_i

	; Init player_y
	move.w	#90,d6

	; Clear counter
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

	rts


logic:
	; Increase counter
	addq.w	#1,d7

	; Move stars
	lea	stars_game,a0
	move.w	#31,d0
.move_stars:
	move.w	0(a0),d1	; y position
	move.w	2(a0),d2	; x position
	move.l	screen_next,a1

	add.w	#-1,d2		; Move one pixel to the left
	move.w	d2,2(a0)
	tst.w	d2
	bpl	.star_alive	; Check if outside screen

	lea	random_200,a1		; Find new y position
	add.w	random_200_i,a1
	add.w	#1,random_200_i
	and.w	#511,random_200_i	; cap index to 512
	clr.w	d1
	move.b	(a1),d1

	move.w	d1,0(a0)	; Set new position
	move.w	#319,2(a0)

.star_alive:
	add.w	#4,a0		; Next star
	dbra	d0,.move_stars

	; Handle missile
	cmp.w	#-1,missile_x	; Check if missile is alive
	bne.s	.move_missile	; Skip checking fire button if missile is alive

	move.b	joy_data+1,d0	; Check if fire is pressed
	btst	#7,d0
	beq.s	.missile_done	; Missile dead and fire not pressed, continue...

	move.w	#49,missile_x	; Spawn new missile
	move.w	d6,missile_y
	add.w	#21,missile_y

.move_missile:
	add.w	#1,missile_x	; Move missile one pixel to the right
	
	cmp.w	#320,missile_x	; Check if missile is out of bounds
	blt.s	.missile_done
	move.w	#-1,missile_x	; Set the missile as dead
.missile_done:

	; Move ship up/down if joy up/down is pressed
	; Also decide ship sprite to draw based on movement
	; Ship sprites are (in sprite image):
	; No movement: 0,0
	; Up movement: 32,0
	; Down movement: 64,0
	; So set d0 to correct source_x here
	move.b	joy_data+1,d1
	btst	#0,d1
	bne.s	.move_up
	btst	#1,d1
	bne.s	.move_down
	clr.w	ship_sprite_x		; set ship sprite x to no movement sprite x
	bra.s	.move_done

.move_up:
	; Move player up unless already at top (y = 0)
	cmp	#0,d6
	beq	.move_done
	add.w	#-1,d6
	move.w	#32,ship_sprite_x	; set ship sprite x to up sprite x
	bra.s	.move_done

.move_down:
	; Move player down unless already at bottom (y = 200-23)
	cmp	#177,d6
	beq	.move_done
	add.w	#1,d6
	move.w	#64,ship_sprite_x	; set ship sprite x to down sprite x
	;bra.s	.move_done

.move_done:
	rts


draw:
	; Draw stars
	lea	stars_game,a0
	move.w	#31,d0
.draw_stars:
	move.w	0(a0),d1	; y position
	move.w	2(a0),d2	; x position
	move.l	screen_next,a1

	mulu	#160,d1		; Go to correct line
	add.l	d1,a1		; 160 bytes per line

	move.w	d2,d3		; Find correct group
	lsr	#1,d3
	and.w	#$fff8,d3
	add.l	d3,a1

	move.w	d2,d3		; Fetch mask
	and.w	#15,d3		; mask index = group index = x % 16
	lsl	#1,d3		; offset in pixel mask = (x % 16) << 1
	lea	pixel_mask,a2	;                      = (x & 15) << 1
	add.l	d3,a2		; (each mask is 2 bytes)
	move.w	(a2),d3

	add.l	#6,a1		; Write mask to bitplane 4, which will make the
	or.w	d3,(a1)		; final color %1000 = 8

	add.l	#4,a0
	dbra	d0,.draw_stars

	; Draw ship
	lea	sprite_image,a0
	add.l	#34,a0
	move.l	screen_next,a1
	move.w	ship_sprite_x,d0; Ship starts at x,0
	clr.w	d1
	move.w	#16,d2		; Draw at 16,player_y
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
	clr.w	d2		; Draw at 0,player_y+12
	move.w	d6,d3
	add.w	#12,d3
	move.w	#16,d4		; Size of fire is 16,7
	move.w	#7,d5
	jsr	copy_image

	; Draw missile if alive
	cmp.w	#-1,missile_x
	beq.s	.missile_dead

	move.w	missile_y,d1	; Prepare to draw the missile
	move.w	missile_x,d2
	move.l	screen_next,a1

	mulu	#160,d1		; Find correct line
	add.w	d1,a1		; 160 bytes per line

	move.w	d2,d3		; Find correct group
	lsr	#1,d3
	and.w	#$fff8,d3
	add.w	d3,a1

	move.w	d2,d3		; Fetch mask
	and.w	#15,d3
	lsl	#1,d3
	lea	pixel_mask,a2
	add.w	d3,a2
	move.w	(a2),d3

	or.w	d3,(a1)		; Write mask to bitplane 1 and 2
	add.l	#2,a1		; Final color %0011 = 3
	or.w	d3,(a1)

.missile_dead:
	rts

	section data

sprite_image	incbin SPRITES.PI1
missile_x	dc.w	-1
missile_y	dc.w	-1
ship_sprite_x	dc.w	0	; ship sprite source x (set by logic, used by draw)

	section bss

	; 32 stars: 2b y pos, 2b x pos
stars_game	ds.w	32*2
