	LIST	p=PIC16C84

ind0    equ     00h             ; index register
rtcc	equ	01h		; real time clock counter
pcl     equ     02h             ; program counter low byte
status  equ     03h             ; status register
fsr     equ     04h             ; file select register
porta   equ     05h             ; port A
portb   equ     06h             ; port B
intcon	equ	0bh		; interrupt control

SNDDATA	equ	0ch		; space for sent data
lstcntr	equ	10h		; last rtcc value
bitcnt	equ	11h		; bit counter for sent data
bytecnt	equ	12h		; byte counter for sent data
flags	equ	13h		; flags register
hidel	equ	14h		; delay counters
lodel	equ	15h
tmp	equ	16h

done	equ	0		; "count finished" flag in flags register

C	equ	0		; status register CARRY bit
Z	equ	2		; ZERO bit

W       equ     0               ; W is destination
F       equ     1               ; F is destination

OPTVAL	equ	85h		; option register
INTVAL	equ	0h		; interrupt enable register

HISYNC	equ	0f4h		; 9 ms
LOSYNC	equ	82h		; 4.8 ms
HIPULS	equ	9h		; 330 us
ZERO	equ	15h		; 800 us
ONE	equ	36h		; 2 ms
LONGDEL	equ	64h
LODELV	equ	0bh

	org	0
start	clrw
	movwf	porta		; reset port a outputs
	tris	porta		; port a all outputs
	movlw	0ffh
	tris	portb		; port b all inputs
	movlw	OPTVAL		; configure option register
	option
	movlw	INTVAL		; disable interrupts
	movwf	intcon

loop	movlw	80h		; set up data to be sent
	movwf	SNDDATA
	comf	SNDDATA,W
	movwf	SNDDATA+1
key	comf	portb,W		; read state of port b
	andlw	03h		; keep lower 2 bits
	btfsc	status,Z
	goto	key		; wait for a button
	;movlw	1		; FOR TESTING ONLY
	movwf	SNDDATA+2
	decf	SNDDATA+2,F
	swapf	SNDDATA+2,F
	comf	SNDDATA+2,W
	movwf	SNDDATA+3

	movlw	SNDDATA
	movwf	fsr
	bsf	porta,0		; start hi sync pulse
	movlw	HISYNC
	call	delay
	bcf	porta,0
	movlw	LOSYNC
	call	delay
snd	movlw	4
	movwf	bytecnt
sndbyt	movlw	8
	movwf	bitcnt
sndbit	bsf	porta,0
	movlw	HIPULS
	call	delay
	bcf	porta,0
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
final	bsf	porta,0
	movlw	HIPULS
	call	delay
	bcf	porta,0

sentall	movlw	LONGDEL
	movwf	tmp
lngdel	movlw	HISYNC
	call	delay
	decfsz	tmp,F
	goto	lngdel
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
