	LIST	p=PIC16C54A

ind0    equ     00h             ; index register
rtcc	equ	01h		; real time clock counter
pcl     equ     02h             ; program counter low byte
status  equ     03h             ; status register
fsr     equ     04h             ; file select register
porta   equ     05h             ; port A
portb   equ     06h             ; port B

C	equ	0		; status register CARRY bit
Z	equ	2		; ZERO bit

W       equ     0               ; W is destination
F       equ     1               ; F is destination

RCVDAT	equ	5		; port b bit that receives rf data

OPTVAL	equ	05h		; OPTION reg.

; Hi sync is 9ms +/- 10%
MINHS	equ	6dh		; minimum length of high sync pulse 7 ms
MAXHS	equ	0abh		; max length of high sync pulse 11 ms
; Lo sync is 4.8 ms +/- 10%
MINLS	equ	3eh		; minimum length of low sync pulse 4 ms
MAXLS	equ	57h		; max length of low sync pulse 5.6 ms
; data pulse length
; minimum .9 ms
; maximum 2.8ms
MINDAT	equ	0eh
MAXDAT	equ	2bh
; treshold of "0"/"1" data = 1.73ms
DAT	equ	1bh

; ERROR PROCEDURE CONSTANTS
HISYNC	equ	0d8h		; 9 ms
LOSYNC	equ	6ch		; 4.8 ms
HIPULS	equ	9h		; 330 us
ZERO	equ	15h		; 800 us
ONE	equ	36h		; 2 ms
LONGDEL	equ	64h
LODELV	equ	04h
EBIT	equ	7		; bit of port b on which to send error data

; REGISTERS
ECODE	equ	0ch
bitcnt	equ	0dh		; bit counter for received data
bytecnt	equ	0eh		; byte counter for received data
lstcntr	equ	0fh		; last rtcc value
MY_ID	equ	10h		; space for unit address
RCVDATA	equ	11h		; space for received data
ecnt	equ	15h		; error transmit procedure bit counter
ebcnt	equ	16h		; error transmit byte counter
hidel	equ	17h		; delay counters
lodel	equ	18h

; prescaller on RTCC, 1:64 -> 64us/cycle

rset	equ	01ffh		; reset vector for PIC16C54A

;	org	rset
;	goto	0

	org	0
	movlw	0ah		; initial state of port A outputs
	movwf	porta
	clrw
	tris	porta		; port a all outputs
	movlw	portb
	movlw	07fh
	tris	portb		; port b all inputs except for bit 7 status output
	movlw	OPTVAL		; configure option register
	option
	movlw	80h
	goto	err

main	swapf	portb,W		; read address jumpers
	iorlw	0fh		; keep only high nybble
	btfss	portb,4		; is jumper for MSB high?
	andlw	0f7h		; yes, set bit 3 in MY_ID
	movwf	MY_ID
	comf	MY_ID,F		; jumpers open ("0") are pulled high, invet them

	call	rcvdata		; try to receive data

err	movwf	ECODE		; store error code there
	movlw	ECODE		; point to first byte to be sent
	movwf	fsr
	bsf	portb,EBIT	; start hi sync pulse
	clrwdt
	movlw	HISYNC
	call	delay
	bcf	portb,EBIT
	clrwdt
	movlw	LOSYNC
	call	delay
snd	movlw	1		; number of registers to be sent
	btfss	ECODE,7
	movlw	9
	movwf	ebcnt
sndbyt	movlw	8		; 8 bits each
	movwf	ecnt
sndbit	clrwdt
	bsf	portb,EBIT
	movlw	HIPULS
	call	delay
	bcf	portb,EBIT
	movlw	ZERO
	btfsc	ind0,7
	movlw	ONE
snddel	call	delay
	rlf	ind0,F
	decf	ecnt,F
	btfss	status,Z
	goto	sndbit
sentbyt	incf	fsr,F
	decf	ebcnt,F
	btfss	status,Z
	goto	sndbyt
final	bsf	portb,EBIT
	movlw	HIPULS
	call	delay
	bcf	portb,EBIT
	clrwdt
	goto	main		; back to main loop

delay	movwf	hidel		; 1
hdel	movlw	LODELV		; 1				}
	movwf	lodel		; 1				}
ldel	decfsz	lodel,F		; 1/2	lodel+1	}		}
	goto	ldel		; 2		}3lodel-1	}
	decfsz	hidel,F		; 1/2				}(3lodel-1+5)hidel+1
	goto	hdel		; 2				}
ret	return			; 2

rcvdata	movlw	RCVDATA		; setup receive data buffer
	movwf	fsr
hsync	btfsc	portb,RCVDAT	; wait for a high pulse
	goto	gothsyn		; got high sync bit or at least think so
	clrwdt			; still waiting, clear watchdog
	goto	hsync		; continue loop
gothsyn	clrf	rtcc		; clear counter
wlosyn	btfss	portb,RCVDAT	; wait for the pulse to end (9 ms)
	goto	gotlsyn		; got low sync bit
	clrwdt
	goto	wlosyn		; continue loop
gotlsyn	movf	rtcc,W		; fetch RTCC
	clrf	rtcc		; and reset it
	movwf	lstcntr		; store for later
	movlw	MINHS		; see if the pulse isn't too short
	subwf	lstcntr,W
	btfss	status,C
	retlw	1		; pulse shorter than minimum high sync
	movlw	MAXHS		; see if it isn't too long
	subwf	lstcntr,W
	btfsc	status,C
	retlw	2		; pulse longer than the max. value
losyne	btfsc	portb,RCVDAT	; wait for the low pulse to end (4.8 ms)
	goto	rddata		; check if lo sync valid and read data if yes
	clrwdt
	goto	losyne		; keep waiting for low sync end
rddata	movf	rtcc,W		; fetch rtcc
	clrf	rtcc		; and reset it
	movwf	lstcntr		; store for later
	movlw	MINLS		; see if the pulse isn't too short
	subwf	lstcntr,W
	btfss	status,C
	retlw	3		; pulse shorter than minimum low sync
	movlw	MAXLS		; see if it isn't too long
	subwf	lstcntr,W
	btfsc	status,C
	retlw	4		; pulse longer than the max. low sync
; valid sync pulses received, read data
rd	movlw	4
	movwf	bytecnt		; setup byte counter
rdbyte	movlw	8
	movwf	bitcnt
rdbit	clrwdt
	rlf	ind0,F		; prepare for next bit
waitlo	btfss	portb,RCVDAT	; wait for high part of the pulse to end
	goto	waithi
	clrwdt
	goto	waitlo
waithi	btfsc	portb,RCVDAT	; wait for the low part of the pulse to end
	goto	gothi
	clrwdt
	goto	waithi
gothi	movf	rtcc,W		; fetch rtcc
	clrf	rtcc		; and reset it
	movwf	lstcntr		; store for later
	movlw	MINDAT		; see if it isn't too short
	subwf	lstcntr,W
	btfss	status,C
	retlw	5
	movlw	MAXDAT		; or too long
	subwf	lstcntr,W
	btfsc	status,C
	retlw	6
	movlw	DAT		; see whether it is a 0 or 1
	subwf	lstcntr,W
	btfsc	status,C
	goto	got1
	bcf	ind0,0
	goto	nextbit
got1	bsf	ind0,0
nextbit	decf	bitcnt,F	; decrement bit counter
	btfss	status,Z	; see if bit counter reached zero
	goto	rdbit		; no
gotbyt	incf	fsr,F		; point to the next byte to be received
	decf	bytecnt,F
	btfss	status,Z	; see if received all 4 bytes
	goto	rdbyte		; no, read next byte
gotall	clrwdt
	movlw	RCVDATA		; point to first byte received
	movwf	fsr
	comf	ind0,W
	incf	fsr,F		; point to the second byte
	xorwf	ind0,W
	btfss	status,Z	; see if correct checksum for first byte
	retlw	7
	incf	fsr,F		; point to the third byte
	comf	ind0,W
	incf	fsr,F		; point to the fourth byte
	xorwf	ind0,W
	btfss	status,Z	; see if correct checksum for third byte
	retlw	8
	movf	RCVDATA,W	; see if the address matches
	xorwf	MY_ID,W
	btfss	status,Z	; see if it is correct address
	retlw	9
switch	swapf	RCVDATA+2,W	; fetch data byte
	andlw	07		; keep lower 3 bits
	addwf	pcl,F
	goto	sw1
	goto	sw2
	goto	sw3
	goto	sw4

sw1	movlw	0ch
	andwf	porta,W
	iorlw	1
	goto	setport

sw2	movlw	03h
	andwf	porta,W
	iorlw	4
	goto	setport

sw3	movlw	0ch
	andwf	porta,W
	iorlw	2
	goto	setport

sw4	movlw	03h
	andwf	porta,W
	iorlw	8
	goto	setport

setport	movwf	porta

done	retlw	81h

	END
