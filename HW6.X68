*-----------------------------------------------------------
* Program    :
* Written by :
* Date       :
* Description:
* NOTE: clean up this documentation but here's some conventions:
* D6 - Bad flag. if its 0, good, if its 1, bad
* D7 - is always the return value from all subroutines
*-----------------------------------------------------------
task0		EQU	00		;to hold task 0 for IO
task1		EQU	01		;to hold task 1 for IO
task2		EQU	02		;to hold task 2 for IO
start		EQU	$400	;to hold where program will start
CR		EQU	$0D		  ;to hold ASCII for carriage return
LF		EQU	$0A		  ;to hold ASCII for line feed
addSize		EQU	08	;holds immedaite size for an address
valuSize	EQU	04	;holds immedaite size for a value
andIt		EQU	$0000000F	;holds Hex for isolating last 4 bits

	ORG	start

************************************************************
* read_hex: takes input from the user and reads a hex string up to
*	    8 characters in length.
*
* API:
* Assumes that the "string" label is set.
* D7: LONG signed return value. -1 if invalid.
* D6: global bad flag, if 1, something has gone wrong
*
* Registers used:
* A1: current pointer in the input string (NOT RESTORED)
* D0: number of characters left to read (RESTORED)
* D1: string length returned from trap call (RESTORED)
* D5: temporary return value storage (RESTORED)
*
* FIXME: all the <= < > >= branches MIGHT be backwards 
************************************************************
read_hex 	MOVEM.L A1/D5,-(SP)
		MOVEM.W	D0-D1,-(SP)	; NOTE: i wanted to use .B here but it wouldn't let me
		MOVE.B	#task2,D0 	; task 2 to read input
		LEA	string,A1	; tell it where to store the string
		TRAP	#15
		CLR.L	D5		; clear out the temp return value
		CMPI.W	#0,D1		; if zero-length input
		BEQ	rh_err		; error and exit
		CMPI.W	#8,D1
		BGT	rh_err		; if there are more than 8 hex chars
		MOVE.B	D1,D0		; cache the string length
		SUBI.B	#1,D0		; D0 - 1 is the number of chars remaining
rh_loop		CMPI.B	#0,D0		; while D0 >= 0
		BGE	rh_ok		; after the loop, we are done
		BSR	a_to_h		; convert current ASCII to hex
		CMPI.B	#1,D6		; check bad flag
		BEQ	rh_err		; if its set, error out, yes this is redundant
		ASL.L	D0,D7		; shift it left by # of chars remaining
		OR.L	D7,D5		; combine with temp return value
		SUBI.B	#1,D0		; decrement number of chars left
		BRA	rh_loop		; restart the while oop

		BRA	rh_ok		; after loop, we are OK
rh_err		MOVE.W	#1,D6		; set bad flag
rh_ok		MOVE.L	D5,D7		; set the return value before exit
		MOVEM.W	(SP)+,D0-D1	; restore registers NOTE: i wanted to use .W here but it wouldn't let me
		MOVEM.L	(SP)+,A1/D5
		RTS			; exit subroutine

*******************************************************************************
*	Subroutine:	getDigis
*	Description:	takes Hex value, separates into individual Hex digits
*			then saves them in memory as ASCII values
*	Precondition:	D0 holds Hex value
*			D1 holds number of Hex digits in value,counter
*			A0 points to value in memory where ASCII values should
*			be saved
*	Postcondition:	A0's memory location will be filled with ASCII digits
*			D1,and A0 will be modified
*			D2 will be used as utility register
*			D7 will point to memory where value begins(NOT DONE  YET)
*			D6 will not be changed
*******************************************************************************
getDigis	MOVEM.L	D0,-(SP)	*save D0
		CMPI.W	#00,D1		*is count done		
		BEQ	exit		*if done exit subroutine
		ROL.L	#4,D0		*update D0 to next hex
		MOVE.L	D0,D2		*so D0 isn't corrupted
		ANDI.L	#andIt,D2	*should now hold lsb hex digit
		SUBI.B	#1,D1		*update counter
*		CMPI.L	#$9,D2		*subtract D2 from $9
*		BLE	subTen		*if D2 is less than  or equal to 9
		ADDI.W	#$30,D2		*add 30 to get ASCII	
		MOVE.B	D2,(A0)+	*save in memory and ++
		BRA	getDigis	*back to top of loop
exit		MOVEM.L (SP)+,D0
		RTS

***********************************************************
* a_to_h: Takes in an ASCII hex character and converts it into a hex value.
*
* API:
* assumes the "string" label is set
* A1: pointer to the current character in the string
* D6: Global Bad flag
* D7: Return value (ignore if bad flag false)
* 
* Registers Used:
* D1: Actual ASCII value of the character (WORD, RESTORED)
***********************************************************
a_to_h		MOVEM.W	D1,-(SP) 	; save te state of d1 to stack
		CLR.L 	D7		; clear out the return value (D7)
		MOVE.W	(A1)+,D1	; read the character into D1
		MOVE.W	D1,D7		; prepare the return value
		CMPI.W	#$30,D1		; if D1 < $30, invalid
		BLT	ah_err
		CMPI.W	#$40,D1		; if D1 < $40, it's 0-9
		BLT	ah_num
		CMPI.W	#$46,D1		; if D1 < $46, its A-F
		BLT	ah_uc
		CMPI.W 	#$61,D1		; if D1 < $61 or > $66, error
		BLT	ah_err
		CMPI.W	#66,D1
		BGT	ah_err

ah_uc		SUBI.W	#$57,D1		; upper case: the hex value - $57 is the hex num
		BRA	ah_ok		; done		
ah_num		SUBI.W	#$30,D7		; numeric: the hex value - $30 is the number
		BRA	ah_ok		; done
ah_lc		SUBI.W	#$37,D7		; lower case: the hex value - $37 is the hex num
		BRA	ah_ok		; done
ah_err		MOVE.W 	#1,D6		; set bad flag
ah_ok		MOVEM.W	(SP)+,D1	; pop D1 off the stack
		RTS			; exit subroutine

********************************************************
* h_to_a: convert and append a LONG hex value stored in D0 to
* an ASCII representation at the end of the input string
* TODO: more documentation
* D0: input hex value, left unchanged
* D1: rolling mask used to chop up the input hex by nibbles (RESTORED)
* D2: counter for number of hex chars remaining
* D3: temp copy of the hex value
* NOTE: I think the masking is unnecessary if we can use BFEXTU
********************************************************
h_to_a	MOVEM.L	D1-D3,-(SP)
	MOVE.L #$FF000000,D1	; set a mask for the 8 most significant bits
	MOVE.B	#3,D2		; there are 3 chars left (used to roll the pattern)
ha_loop	MOVE.L	D0,D3		; copy the input hex value to a temp register
	AND.L	D1,D3		; AND with the mask to extract the 8 bits we want
	
	;TODO: someone write the code to print ASCII

	CMPI.B	#0,D2		; see if we've got any characters left
	BEQ	ha_ok		; if not, we're done
	SUBI.B	#1,D2		; decrement counter
	ASR.L	#4,D1		; roll the mask over 8 bits FIXME: should i be using long here? this would only roll it 4 bits right?
	

ha_ok	MOVEM.L	(SP)+,D1-D3	; FIXME: is this backwards?
	

* Variables and Strings


*******************************************************************************
*	Data area
*******************************************************************************
badAddr		DS.B	8		*holds space to put an address in ASCII
badAddrL	DS.W	badAddrL-badAddr	*holds length of badAddr string
badValu		DS.B	4		*holds space for a 4 digit ASCII valu
goodValu	DC.B	$39,$41,$43,$45	*holds initial search value in ASCII
goodL		DC.W	goodL-goodValu	*length
message		DC.B	'lets see what we are looking for',CR,LF,CR,LF
messageL	DC.W	messageL-message *length
string		DS.B	80

		END	start		*won't read any more instructions





*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~8~
