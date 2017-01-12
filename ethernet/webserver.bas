' Applesoft BASIC Webserver
' by Vince Weaver <vince@deater.net>
' additions from Ricardo Contieri <ricardo.contieri@gmail.com>
'
1 REM *** Setup UTHERNET II - W5100
' SLOT0=$C080	49280	SLOT4=$C0C0	49344
' SLOT1=$C090	49296	SLOT5=$C0D0	49360
' SLOT2=$C0A0	49312	SLOT6=$C0E0	49376
' SLOT3=$C0B0	49328	SLOT7=$C0F0	49392
'
' Set up the memory addresses to use
'
2 GOSUB 10000: REM *** SENDING TO SLOT SETUP *** OURS IS IN SLOT3 ($C0B0)
4 MR = SLOT + 4: REM  *** MODE REGISTER C0x4
5 HA=SLOT+5:LA=SLOT+6: REM *** HIGH/LOW ADDR $C0x5,$C0x6
7 DP=SLOT+7: REM *** DATA PORT $C0B7
'
' Init the W5100
'
 10  REM  *** Init W5100
 12  POKE MR,128: REM  RESET W5100
 14  POKE MR,3: REM  AUTOINCREMENT
 20  REM  *** Setup MAC Address 41:50:50:4c:45:32
 22  POKE HA,0: POKE LA,9
 23  POKE DP,65: POKE DP,80: POKE DP,80: POKE DP,76: POKE DP,69: POKE DP,50
 30  REM  *** Setup IP Address 192.168.8.15
 31  PRINT "Setup IP Address:" IA"."IB"."IC"."ID
 32  POKE LA,15
 33  POKE DP,IA: POKE DP,IB: POKE DP,IC: POKE DP,ID
 40  PRINT "UTHERNET II READY:" IA"."IB"."IC"."ID
'
' Setup Machine Language Memcpy routine
'   NOTE! This code assumes the Uthernet is in slot 3
'   FIXME: patch on the fly once it works
'   See Appendix 1 at the end of this for more details
'
51 DATA 169,0,133,6,169,64,133,7,162,11,240,36,160,0,177,6
52 DATA 141,183,192,213,9,208,15,217,8,0,208,10,169,64,141,181
53 DATA 192,169,0,141,182,192,200,208,229,230,7,202,208,224,162,10
54 DATA 177,6,141,183,192,217,8,0,208,10,169,64,141,181,192,169
55 DATA 0,141,182,192,200,202,208,232,96
60 FOR I=0 TO 72: READ X: POKE 768+I,X:NEXT I
'
'Still not sure how to adapt this part of the code to properly read the Slot variables, although could find where they would fit.
'51 DATA 169,0,133,6,169,64,133,7,162,11,240,36,160,0,177,6
'52 DATA 141,DD,192,213,9,208,15,217,8,0,208,10,169,64,141,DH
'56 DATA 192,169,0,141,DL,192,200,208,229,230,7,202,208,224,162,10
'57 DATA 177,6,141,DP,192,217,8,0,208,10,169,64,141,DH,192,169
'58 DATA 0,141,DL,192,200,202,208,232,96
'
'
'
'
' Setup Socket 0
'
100 REM *** Setup Socket 0
102 PRINT "** Setting up Socket 0"
105 POKE HA,0:POKE LA,26: REM RX MEMSIZE
110 POKE DP,3: REM 8kB RX buffer
115 POKE DP,3: REM 8kB TX buffer
200 REM *** Setup TCP MODE on SOCKET 0
205 POKE HA,4: POKE LA,0: REM *** 0x400 mode
210 POKE DP,65 : REM *** 0x41 MAC FILTER (non-promisc) TCP
300 REM ** Setup Source PORT
303 PRINT "** Setting up to use TCP port 80"
305 POKE HA,4: POKE LA,4: REM *** 0x404 port
310 POKE DP,0:POKE DP, 80: REM *** http port 80
'
' OPEN the socket
'
400 REM *** OPEN socket
404 PRINT "** OPENing socket"
405 POKE HA,4: POKE LA,1: REM *** 0x401 command register
410 POKE DP, 1: REM *** OPEN
'
' Check return value
'
500 REM *** Check if opened
505 POKE HA,4: POKE LA,3: REM *** 0x403 status register
510 RE=PEEK(DP)
515 PRINT "** STATUS IS ";RE;
520 IF RE=19 THEN PRINT " OPENED":GOTO 600
530 IF RE=0 THEN PRINT " CLOSED, ERROR": GOTO 5000
540 PRINT "UNKNOWN ERROR ";RE
550 GOTO 5000
'
' LISTEN on the socket
'
600 REM *** Connection opened, Listen
605 POKE HA,4: POKE LA,1: REM *** 0x401 command register
610 POKE DP, 2: REM *** LISTEN
'
' Check return value
'
620 REM *** Check if successful
625 POKE HA,4: POKE LA,3: REM *** 0x403 status register
630 RE=PEEK(DP)
635 PRINT "** STATUS IS ";RE;
640 IF RE=20 THEN PRINT " LISTENING":GOTO 700
650 IF RE=0 THEN PRINT " CLOSED, ERROR":GOTO 5000
655 PRINT "UNKNOWN ERROR ";RE
675 GOTO 5000
'
' Wait for incoming connection
'
700 REM *** Wait for incoming connection
705 POKE HA,4: POKE LA,1: REM *** 0x401 command register
710 POKE DP, 2: REM *** LISTEN
'
' Check for result
'
720 REM *** Check if successful
725 POKE HA,4: POKE LA,3: REM *** 0x403 status register
730 RE=PEEK(DP)
740 IF RE=23 THEN GOTO 800: REM ESTABLISHED
745 IF RE<>20 THEN PRINT "WAITING: UNEXPECTED STATUS=";RE
750 GOTO 700: REM *** Repeat until connected
'
' Established, repeat waiting for incoming data
'
800 PRINT "ESTABLISHED"
802 POKE HA,4: POKE LA,38: REM *** 0x426 Received Size
805 SH=PEEK(DP):SL=PEEK(DP)
810 SI=(SH*256)+SL
820 IF SI<>0 THEN GOTO 900
'
' Should we delay? busy polling seems wasteful
'
830 REM DELAY?
840 GOTO 802
'
' We have some data, let's read it
'
900 POKE HA,4: POKE LA,40: REM *** 0x428 Received ptr
905 OH=PEEK(DP):OL=PEEK(DP)
910 RF=(OH*256)+OL
920 REM *** MASK WITH 0x1ff
925 R%=RF/8192:RM=RF-(8192*R%)
930 RA=RM+24576:REM $6000
940 PRINT "READ OFFSET=";RM;" READ ADDRESS=";RA;" READ SIZE=";SI
'
' Check for buffer wraparound
'
942 BW=0
945 IF (SI+TA>=32768) THEN BW=1:BO=32768-TA:PRINT "RX BUFFER WRAPAROUND IN ";BO
'
' Print received packet
'
1000 REM *** PRINT PACKET
1001 FL=1:FL$=""
1003 R%=RA/256
1005 POKE HA,R%: POKE LA,RA-(R%*256)
1010 FOR I=1 TO SI
1020 C=PEEK(DP):C$=CHR$(C)
1025 IF FL=1 THEN FL$=FL$+C$
1027 IF C=10 THEN FL=0
1030 IF C<>10 THEN PRINT C$;
1032 IF BW=0 THEN GOTO 1040
1033 BO=BO-1: IF BO=0 THEN POKE HA,96:POKE LA,0:BW=0
1040 NEXT I
'
' Deal with first line
'
1050 PRINT "FIRST LINE=";FL$
1060 IF LEFT$(FL$,3)<>"GET" GOTO 7000
1065 N$=""
1070 FOR I=6 TO LEN(FL$)
1075 M$=MID$(FL$,I,1)
1080 IF M$=" " GOTO 1090
1085 N$=N$+M$
1087 NEXT I
1090 IF N$="" THEN N$="index.html"
1095 PRINT "SENDING FILE: ";N$
'
' TODO: handle wraparound of 8kb buffer
'
'
' Update read pointer
'
1100 REM *** Update read pointer
1110 POKE HA,4: POKE LA,40: REM *** 0x428 Received ptr
1120 RA=RF+SI
1130 R%=RA/256
1140 POKE DP,R%: POKE DP,RA-(R%*256)
1150 REM *** RECEIVE
1160 POKE HA,4: POKE LA,1: REM *** 0x401 command register
1170 POKE DP, 64: REM *** RECV
'
' Load file from disk
'
1200 REM *** LOAD FILE
1202 X$=RIGHT$(N$,3):M$="text/html"
1203 IF X$="txt" THEN M$="text/plain"
1204 IF X$="png" THEN M$="image/png"
1205 IF X$="jpg" THEN M$="image/jpg"
1206 IF X$="ico" THEN M$="image/x-icon"
1207 IF N$="teapot.html" GOTO 9000
1208 ONERR GOTO 8000
1209 PRINT "LOADING ";N$
1210 PRINT CHR$(4)+"BLOAD ";N$
1215 POKE 216,0: REM CANCEL ONERR
1220 FS=PEEK(43616)+256*PEEK(43617): REM FILESIZE
1225 PRINT "DONE LOADING"
' assume loaded at 0x4000, text page 2
' and that max size is 8kb
1240 A$="HTTP/1.1 200 OK"+CHR$(13)+CHR$(10)
1250 A$=A$+"Server: VMW-web"+CHR$(13)+CHR$(10)
1260 A$=A$+"Content-Length: "+STR$(FS)+CHR$(13)+CHR$(10)
1280 A$=A$+"Content-Type: "+M$+CHR$(13)+CHR$(10)+CHR$(13)+CHR$(10)
'
1380 PRINT "SENDING:":PRINT A$
1385 C=0
'
' read TX free size reg (0x420)
'
1700 SI=LEN(A$)+FS
1710 IF (SI>8192) THEN PRINT "FILE TOO BIG!": REM GOTO 403?
1800 POKE HA,4: POKE LA,32: REM *** 0x420 FREESIZE
1810 OH=PEEK(DP):OL=PEEK(DP)
1815 FR=(OH*256)+OL
1820 PRINT "FREE: ";FR
1830 IF SI>FR GOTO 1800: REM REPEAT UNTIL FREE
'
' Read tx offset
'
1900 POKE HA,4: POKE LA,36: REM *** 0x424 TX write ptr
1905 OH=PEEK(DP):OL=PEEK(DP)
1910 TF=(OH*256)+OL
1920 REM *** MASK WITH 0x1ff
1925 T%=TF/8192:TM=TF-(8192*T%)
1930 TA=TM+16384:REM $4000
1940 PRINT "OH/OL=";OH;"/";OL;" TX OFFSET=";TM;" TX ADDRESS=";TA;" TX SIZE=";SI
'
' Check for buffer wraparound
'
1942 BW=0:BO=0
1945 IF (SI+TA>=24576) THEN BW=1:BO=24576-TA:PRINT "TX BUFFER WRAPAROUND IN ";BO
'
' Write data to TX buffer
' First write header
'
2000 T%=TA/256
2005 POKE HA,T%: POKE LA,TA-(T%*256)
2010 FOR I=1 TO LEN(A$)
2015 POKE DP,ASC(MID$(A$,I,1))
2017 IF BW=0 THEN GOTO 2020
2018 BO=BO-1: IF BO=0 THEN POKE HA,64:POKE LA,0:BW=0
2020 NEXT I
'
' Write disk part
'
2025 FOR I=1 TO FS
2026 C=C+1: IF C=50 THEN PRINT ".";:C=0
2030 POKE DP,PEEK(16383+I)
2032 IF BW=0 THEN GOTO 2035
2033 BO=BO-1: IF BO=0 THEN POKE HA,64:POKE LA,0:BW=0
2035 NEXT I
2040 PRINT
'
' The above is slow
' Intead use our machine language routine
'
'2025 B%=BO/256:POKE 9,B%:POKE 8,BO-(B%*256)
'2027 B%=FS/256:POKE 11,B%:POKE 10,FS-(B%*256)
'2030 CALL 768
'
' Update TX write ptr
'
2050 REM ** UPDATE TX WRITE PTR
2060 POKE HA,4: POKE LA,36: REM *** 0x424 TX write ptr
2075 TA=TF+SI
2080 T%=TA/256
2085 POKE DP,T%: POKE DP,TA-(T%*256)
2090 PRINT "UPDATE TX TO ";T%;"/";TA-(T%*256)
'
' SEND packet
'
2100 REM *** SEND
2102 PRINT "SENDING"
2105 POKE HA,4: POKE LA,1: REM *** 0x401 command register
2110 POKE DP, 32: REM *** SEND
'
' Return to reading
'
4000 REM *** Check if successful
4010 POKE HA,4: POKE LA,3: REM *** 0x403 status register
4020 RE=PEEK(DP)
4030 PRINT "STATUS AFTER SEND ";RE
4035 IF RE=28 THEN GOTO 6000: REM CLOSE_WAIT
4040 IF RE=0 THEN GOTO 400: REM CLOSED
4060 REM *** RECEIVE
4075 POKE HA,4: POKE LA,1: REM *** 0x401 command register
4080 POKE DP, 64: REM *** RECV
4090 GOTO 800
'
' Close the socket
'
5000 REM *** CLOSE AND EXIT
5010 POKE HA,4: POKE LA,1: REM *** 0x401 command register
5020 POKE DP, 16: REM *** CLOSE
5030 END
6000 REM *** CLOSE AND RELISTEN
6010 POKE HA,4: POKE LA,1: REM *** 0x401 command register
6020 POKE DP, 16: REM *** CLOSE
' Check status?
6030 GOTO 400
'
'
' ERROR MESSAGES
'
'
7000 REM 400 BAD REQUEST
7005 S$="400 Bad Request"
7010 M$="<html><head><title>400 Bad Request</title></head><body><h1>Bad Request</h1><p>Your browser sent a request that this server could not understand.<br /></p></body></html>"+CHR$(13)+CHR$(10)
7020 GOTO 9100
8000 REM 404 NOT FOUND
8003 POKE 216,0: REM CANCEL ONERR
8004 PRINT "DISK ERROR: ";PEEK(222)
8005 S$="404 Not Found"
8010 M$="<html><head><title>404 Not Found</title></head><body><h1>Not Found</h1><p>File not found.<br /></p></body></html>"+CHR$(13)+CHR$(10)
8020 GOTO 9100
9000 REM 418 TEAPOT
9005 S$="418 I'm a Teapot"
9010 M$="<html><head><title>418 I'm a Teapot</title></head><body><h1>I'm a Teapot</h1><p>Short *and* stout.<br /></p></body></html>"+CHR$(13)+CHR$(10)
'
' Make header
'
9100 A$="HTTP/1.1 "+S$+CHR$(13)+CHR$(10)+"Server: VMW-web"+CHR$(13)+CHR$(10)
9105 A$=A$+"Content-Length: "+STR$(LEN(M$))+CHR$(13)+CHR$(10)
9110 A$=A$+"Connection: close"+CHR$(13)+CHR$(10)+"Content-Type: text/html; charset=iso-8859-1"+CHR$(13)+CHR$(10)+CHR$(13)+CHR$(10)
' Poke as if we had loaded from disk
9200 FS=LEN(M$)
9210 FOR I=1 TO FS
9220 POKE 16383+I,ASC(MID$(M$,I,1))
9300 NEXT I
9310 GOTO 1380
'                                                      
'Slot selection
 10000 ? "Welcome to the WEBSERVER for the Uthernet II"
10050 ? "Which SLOT is your board? (0-7) - Press 8 for detection tool (may need to restart computer)": INPUT S 
 10060 IF S > = 9 THEN ? "Error, please select value from 0 to 7": GOTO 10050
 10070 IF S = 8 THEN GOTO 11000
 10110 IF S = 0 THEN SLOT = 49280: DM = 132: REM DMR, DHA, DLA and DDP are conversions used in the DATA routine.
 10120 IF S = 1 THEN SLOT = 49296: DM = 148
 10130 IF S = 2 THEN SLOT = 49312: DM = 164
 10140 IF S = 3 THEN SLOT = 49328: DM = 180
 10150 IF S = 4 THEN SLOT = 49344: DM = 196
 10160 IF S = 5 THEN SLOT = 49360: DM = 212
 10170 IF S = 6 THEN SLOT = 49376: DM = 228
 10180 IF S = 7 THEN SLOT = 49392: DM = 244
 10200 DH = DM + 1
 10210 DL = DM + 2
 10220 DD = DM + 3
 
'IP Change tool                                                                         
 10300 ? "Would you like to change current IP Address?"
 10310 IA = 192
 10320 IB = 168
 10330 IC = 1
 10340 ID = 20
 10350 ? "Current IP is:"IA"."IB"."IC"."ID" Continue with this? (Yes/No)": INPUT IP$
 10400 IF IP$ = "Y" THEN RETURN
 10500 ? "What value for 1st segment? Current: "IA" :": INPUT IA
 10510 ? "What value for 2nd segment? Current: "IB" :": INPUT IB
 10520 ? "What value for 3rd segment? Current: "IC" :": INPUT IC
 10530 ? "What value for 4th segment? Current: "ID" :": INPUT ID
 10540 GOTO 10350
'
'                                                                            
' Uthernet II Slotfinder - Based on code from Uthernet Manual
11000 HOME 
11010  PRINT "Uthernet II Slotfinder"
11020  VTAB 4
11030  PRINT "This test is memory disruptive. A clean reboot is recommended after using it."
11050 ADD = 49392
11060 SLOT = 7
11070  VTAB 7
11080  PRINT "Slot:  Result   :Address:Data Found"
11100  POKE ADD,128
11120  POKE ADD,3
11140 CHECK =  PEEK (ADD)
11190 R$ = "Not found"
11200  IF CHECK = 3 THEN R$ = "Possible!"
11400  PRINT "  "SLOT" : "R$" : "ADD" : "CHECK
11450  IF SLOT = 0 GOTO 12000
11500 SLOT = SLOT - 1
11510 ADD = ADD - 16
11600  IF SLOT = 0 GOTO 11900
11700  GOTO 11100
11900  VTAB 16
12000  PRINT "Would you like to test slot Zero? May crash! (Yes / No)": INPUT Z$
12010  IF Z$ = "Y" THEN  GOTO 11100
12100  GOTO 10050

20000 RETURN
 
' STATUSES
'	p28 of W5100 manual
'	0x0	0	SOCK_CLOSED
'	0x13		SOCK_INIT
'	0x14		SOCK_LISTEN
'	0x17	23	SOCK_ESTABLISHED
'	0x1C	28	SOCK_CLOSE_WAIT
'	0x22		SOCK_UDP
'	0x32		SOCK_IPRAW
'	0x42		SOCK_MACRAW
'	0x5f		SOCK_PPOE

'
' Appendix 1: The memcpy machine code
'
'
'PTR	EQU	$06
'PTRH	EQU	$07
'
'WRAPL	EQU	$08
'WRAPH	EQU	$09
'
'SIZEL	EQU	$0A
'SIZEH	EQU	$0B
'
'tx_copy:
'
'	lda	#0		; always copying from 0x4000
'	sta	PTR
'	lda	#$40
'	sta	PTR+1
'
'	ldx	#SIZEH		; number of 256-byte blocks
'	beq	copy_remainder	; if none, skip ahead
'
'	ldy	#0
'copy256:
'	lda	(PTR),y
'	sta	$C0B7		; change based on uthernet slot
'
'	cmp	WRAPH,x
'	bne	nowrap256
'
'	cmp	WRAPL,y
'	bne	nowrap256
'
'	lda	#$40
'	sta	$C0B5
'	lda	#$00
'	sta	$C0B6		; wrap tx buffer address to 0x4000
'
'nowrap256:
'	iny
'	bne	copy256
'
'	inc	PTR+1		; update 16-bit pointer
'	dex			; finish a 256 byte block
'	bne	copy256
'
'	ldx	#SIZEL
'copy_remainder:
'	lda	(PTR),y
'	sta	$C0B7		; change based on uthernet slot
'
'	cmp	WRAPL,y
'	bne	nowrap_r
'
'	lda	#$40
'	sta	$C0B5
'	lda	#$00
'	sta	$C0B6		; wrap tx buffer address to 0x4000
'
'nowrap_r:
'	iny
'	dex
'	bne	copy_remainder
'
'	rts


