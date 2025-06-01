	LIST	p=PIC12C509

ind0    equ     00h             ; index register
rtcc	equ	01h		; real time clock counter
pcl     equ     02h             ; program counter low byte
status  equ     03h             ; status register
fsr     equ     04h             ; file select register
osccal	equ     05h             ; port A
portb   equ     06h             ; port B

SNDDATA	equ	0ch		; space for sent data
lstcntr	equ	10h		; last rtcc value
bitcnt	equ	11h		; bit counter for sent data
bytecnt	equ	12h		; byte counter for sent data
hidel	equ	13h		; delay counters
lodel	equ	14h
tmp	equ	15h
flags	equ	16h		; flags register

done	equ	0		; "count finished" flag in flags register

C	equ	0		; status register CARRY bit
Z	equ	2		; ZERO bit

W       equ     0               ; W is destination
F       equ     1               ; F is destination

HISYNC	equ	0f4h		; 9 ms
LOSYNC	equ	82h		; 4.8 ms
HIPULS	equ	9h		; 330 us
ZERO	equ	15h		; 800 us
ONE	equ	36h		; 2 ms
LONGDEL	equ	06h
LODELV	equ	0bh

MY_ID	equ	80h		; remote address

	org	0
start	movwf	osccal
	clrw
	movwf	portb		; reset port a outputs
	movlw	b'00011111'	; configure I/O directions
	tris	portb
	movlw	b'10000101'	; configure option register
	option

loop	movlw	LONGDEL		; delay between transmissions and
	movwf	tmp		; to initially debounce buttons
lngdel	movlw	HISYNC
	call	delay
	decfsz	tmp,F
	goto	lngdel

	movlw	MY_ID		; set up data to be sent
	movwf	SNDDATA
	comf	SNDDATA,W
	movwf	SNDDATA+1
key	btfss	portb,0		; read state of port b
	goto	xmit0		; transmit code "0"
	btfsc	portb,1
	goto	key		; wait for the button
xmit3	movlw	3
	goto	xmit
xmit0	movlw	0
xmit	movwf	SNDDATA+2
	swapf	SNDDATA+2,F
	comf	SNDDATA+2,W
	movwf	SNDDATA+3

	movlw	SNDDATA
	movwf	fsr
	bsf	portb,5		; start hi sync pulse
	movlw	HISYNC
	call	delay
	bcf	portb,5
	movlw	LOSYNC
	call	delay
snd	movlw	4
	movwf	bytecnt
sndbyt	movlw	8
	movwf	bitcnt
sndbit	bsf	portb,5
	movlw	HIPULS
	call	delay
	bcf	portb,5
	btfsc	ind0,7
	goto	isone
	movlw	ZERO
	goto	snddel
isone	movlw	ONE
snddel	call	delay
	rlf	ind0,F
	decf	bitcnt,F
	btfss	status,Z
	goto	sndbit
sentbyt	incf	fsr,F
	decf	bytecnt,F
	btfss	status,Z
	goto	sndbyt
final	bsf	portb,5
	movlw	HIPULS
	call	delay
	bcf	portb,5

endprog	goto	loop

; (lodel + 5) * hidel + 6
delay	movwf	hidel		; 1
hdel	movlw	LODELV		; 1				}
	movwf	lodel		; 1				}
ldel	decfsz	lodel,F		; 1/2	lodel+1	}		}
	goto	ldel		; 2		}3lodel-1	}
	decfsz	hidel,F		; 1/2				}(3lodel-1+5)hidel+1
	goto	hdel		; 2				}
ret	return			; 2

	END
