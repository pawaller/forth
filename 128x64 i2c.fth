\ ********************************************************************* 
\ Display text on OLED SCREEN SSD1306 128x64                         * 
\    Filename:      SSD1306textDisplay.txt                            * 
\    Date:          25.11.2020                                        * 
\    Updated:       10.03.2023                                        * 
\    File Version:  1.0                                               * 
\    MCU:           ARDUINO all models                                * 
\    GNU General Public License                                       * 
\    FF Version:    5.0                                               *                                            * 
\    Copyright      Marc PETREMANN                                    *
\    Modified by Phil Waller                                          * 
\ ********************************************************************* 
 
\ *** essential code for I2C transmission *********** 
-i2c-new 
marker -i2c-new 
 
\ reg: is an alias for CONSTANT 
\ use to define registers - for more readability 
: reg: ( comp: n ---  | exec: --- n) 
    create 
        , 
    does> 
        @ 
  ; 
\ alias for CONSTANT, use to define bits 
: bit:  ( c --- ) 
    reg: 
  ; 
 
flash 
\ i2c Two-Wire-Interface Registers 
184 reg: TWBR   \ TWI Bit Rate register 
185 reg: TWSR   \ TWI Status Register 
\ 186 reg: TWAR	\ TWI (Slave) Address register - unused 
187 reg: TWDR   \ TWI Data register 
188 reg: TWCR   \ TWI Control Register 
 
\ Bits in the Address register TWAR 
%11111110 bit: TWAR_TWA     \ (Slave) Address register Bits 
%00000001 bit: TWAR_TWGCE   \ General Call Recognition Enable Bit 
 
\ Bits in the Control Register TWCR 
%10000000 bit: TWCR_TWINT   \ Interrupt Flag 
%01000000 bit: TWCR_TWEA    \ Enable Acknowledge Bit 
%00100000 bit: TWCR_TWSTA   \ Start Condition Bit 
%00010000 bit: TWCR_TWSTO   \ Stop Condition Bit 
%00001000 bit: TWCR_TWWC    \ Write Collition Flag 
%00000100 bit: TWCR_TWEN    \ Enable Bit 
%00000001 bit: TWCR_TWIE    \ Interrupt Enable 
 
\ bits in the Status Register TWI 
%11111000 bit: TWSR_TWS     \ TWI Status 
%00000011 bit: TWSR_TWPS    \ TWI Prescaler 
ram 
 
\ Set clock frequency to 100kHz 
: i2c.init ( -- ) 
    TWSR_TWPS TWSR mclr         \ prescale value = 1 
    [ Fcy 100 / 16 - 2/ ] literal TWBR c! 
    %00000011 TWCR mset 
  ; 
 
\ Wait for operation to complete 
: i2c.wait ( -- )  
    \ When TWI operations are done, the hardware sets 
    \ the TWINT interrupt flag, which we will poll. 
    begin 
        TWCR c@ TWCR_TWINT and 
    until 
  ; 
 
\ Send start condition 
: i2c.start ( -- )  
    [ TWCR_TWINT TWCR_TWEN or TWCR_TWSTA or ] literal TWCR c! 
    i2c.wait 
  ; 
 
\ Send repeated start condition 
: i2c.rsen ( -- )  
    i2c.start     \ AVR doesn't distinguish 
  ; 
 
: i2c.restart 
    i2c.start     \ AVR doesn't distinguish 
  ; 
 
\ Send stop condition 
: i2c.stop ( -- )  
    [ TWCR_TWINT TWCR_TWEN or TWCR_TWSTO or ] literal TWCR c! 
  ; 
 
\ Write one byte to bus, returning 0 if ACK was received, -1 otherwise. 
: i2c.c! ( c -- f ) 
    i2c.wait \ Must have TWINT high to write data 
    TWDR c! 
    [ TWCR_TWINT TWCR_TWEN or ] literal TWCR c! 
    i2c.wait 
    \ Test for arrival of an ACK depending on what was sent. 
    TWSR c@ $f8 and $18 xor 0= if   0 exit  then \ SLA+W 
    TWSR c@ $f8 and $28 xor 0= if   0 exit  then \ data byte 
    TWSR c@ $f8 and $40 xor 0= if   0 exit  then \ SLA+R 
    -1  \ Something other than an ACK resulted 
; 
 
\ Write one byte to bus 
: i2c.tx ( c ---) 
   i2c.c! drop ; 
 
\ Read one byte and ack for another. 
: i2c.c@.ack ( -- c ) 
    [ TWCR_TWINT TWCR_TWEN or TWCR_TWEA or ] literal TWCR c! 
    i2c.wait 
    TWDR c@ 
  ; 
 
\ Read one last byte. 
: i2c.c@.nack ( -- c ) 
    [ TWCR_TWINT TWCR_TWEN or ] literal TWCR c! 
    i2c.wait 
    TWDR c@ 
 ; 
 
\ Address slave for writing, leaving true if slave ready. 
: i2c.addr.write ( 7-bit-addr -- f ) 
    1 lshift 1 invert and \ Build full byte with write-bit as 0 
    i2c.start i2c.c! 
    if      false 
    else    true    then 
  ; 
 
\ Address slave for reading, leaving true if slave ready. 
: i2c.addr.read ( 7-bit-addr -- f ) 
    1 lshift 1 or \ Build full byte with read-bit as 1 
    i2c.start i2c.c! 
    if      false 
    else    true    then 
  ; 
 
\ Detect presence of device, leaving true if slave responded. 
\ If the slave ACKs the read request, fetch one byte only. 
: i2c.ping? ( 7-bit-addr -- f ) 
    1 lshift 1 or     \ Build full byte with read-bit as 1 
    i2c.start i2c.c! 0= 
    if      i2c.c@.nack drop true 
    else    false 
    then 
  ; 
 
 

 
 
\ require part of i2c-new.txt 
 
\ usage of stream: example 
\ eeprom 
\ stream: XX    \ create XX like as array with no datas 
\     2 c,      \ compile one byte (command or data) 
\     3 c,      \ compile other datas or commands 
\     4 c, 
\   ;stream     \ store at XX addr the legth of datas 
\ ram 
 
-stream 
marker -stream 
 
\ do nothing - default action for stream: 
: nothing ( ---) 
  ; 
 
defer stream.action \ default action for stream: 
 
\ define a command or data stream for SSD1306 
: stream: 
    \ set nothing as execute action by default 
    \ ['] nothing is stream.action 
    create 
        here    \ leave current dictionnary pointer on stack 
        0 c,    \ initial length of data is 0 
    does> 
        stream.action 
  ; 
 
\ store at  addr length of datas compiled beetween 
\  and here 
: ;stream ( addr-var len ---) 
    dup 1+ here 
    swap -      \ calculate cdata length 
    \ store c in first byte of word defined by stream: 
    swap c! 
  ; 
 
-streamDebug 
marker -streamDebug 
 
\ get real addr2 and u length form addr1 
: count ( addr1 --- addr2 u) 
    dup c@          \ push real length 
    swap 1+ swap    \ push start address of datas 
  ; 
 
\ used for debugging streams 
\ for use: 
\  ' disp.stream is stream.action 
: disp.stream ( stream-addr ---) 
    count 
    for 
        c@+ . 
    next 
    drop 
  ; 
 
 
\ *** Manage OLED display 128x64 ******** 
 
-ssd1306 
marker -ssd1306 
 
$3c constant addrSSD1306    \ i2c device address 
 
\  control: $00 for commands 
\           $40 for datas 
$00 constant CTRL_COMMANDS 
$40 constant CTRL_DATAS 
 
\ send stream of datas or commands to SSD1306 
: i2c.stream.tx ( stream-addr ---) 
    addrSSD1306  i2c.addr.write drop \ send SSD1306 address 
    count  \ fetch real addr and length of datas to send 
    for 
        c@+ i2c.tx  \ send commands or datas 
    next 
    drop 
    i2c.stop 
  ; 
 
\ usage: 
\ ' i2c.stream.tx is stream.action 
 
-commands 
marker -commands 
 
\ define SSD1306 128x64 ram size 
128 constant DISPLAY_WIDTH 
64 constant DISPLAY_HEIGHT  
DISPLAY_WIDTH DISPLAY_HEIGHT * 8 / constant SSDramSize 
 
 
flash 
stream: disp.setup 
    CTRL_COMMANDS c, 
    $ae c, ( DISP_SLEEP ) 
    $d5 c, ( SET_DISP_CLOCK ) 
    $80 c, 
    $a8 c, ( SET_MULTIPLEX_RATIO ) 
    $3f c, 
    $d3 c, ( SET_VERTICAL_OFFSET ) 
    $00 c, 
    $40 c, ( SET_DISP_START_LINE ) 
    $8d c, ( CHARGE_PUMP_REGULATOR ) 
    $14 c, ( CHARGE_PUMP_ON ) 
    $20 c, ( MEM_ADDRESSING ) 
    $00 c, 
    $a0 c, ( SET_SEG_REMAP_0 ) 
    $c0 c, ( SET_COM_SCAN_NORMAL ) 
    $da c, ( SETCOMPINS ) 
    $12 c, \ $02 or $12 ??? 
    $db c, ( SET_VCOM_DESELECT_LEVEL ) 
    $40 c, 
    $a4 c, ( RESUME_TO_RAM_CONTENT ) 
    $a6 c, ( NORMALDISPLAY ) 
    $af c, ( DISP_ON ) 
  ;stream 
 
stream: disp.reset 
    CTRL_COMMANDS c, 
    $21 c,  \ COL START_END 
    $00 c,  \ start 
    $7f c,  \ end 
    $22 c,  \ PAGE START_END 
    $00 c,  \ start 
    $07 c,  \ end 
  ;stream 
ram 
 
: disp.init ( -- ) 
    disp.setup 
    disp.reset 
  ; 
 
: disp.clear ( ---) 
    disp.reset 
    addrSSD1306  i2c.addr.write drop \ send SSD1306 address 
    CTRL_DATAS i2c.tx 
    SSDramSize 
    for 
        $00 i2c.tx  \ send commands or datas 
    next 
    i2c.stop 
    disp.reset 
  ; 
 
 
: init ( ---) 
    i2c.init 
    ['] i2c.stream.tx is stream.action 
    disp.init ; 
 
 
-dispUtil 
marker -dispUtil 
 
0 value currentPage 
 
: set.line 
    addrSSD1306  i2c.addr.write drop \ send SSD1306 address 
    CTRL_COMMANDS i2c.tx 
    $21 i2c.tx  \ COL START_END 
    $00 i2c.tx  \ start 
    $7f i2c.tx  \ end 
    $22 i2c.tx  \ PAGE START_END 
    currentPage i2c.tx  \ start 
    currentPage i2c.tx  \ end 
    i2c.stop 
  ; 
 
: line.clear ( ---) 
    addrSSD1306  i2c.addr.write drop \ send SSD1306 address 
    CTRL_DATAS i2c.tx 
    DISPLAY_WIDTH 
    for 
        $00 i2c.tx  \ send commands or datas 
    next 
    i2c.stop 
  ; 
 
: crLine ( ---) 
    currentPage 1+ 7 and to currentPage 
    set.line 
    line.clear 
  ; 
 
 
 
-fonts 
marker -fonts 
 
flash 
hex 
create FONTS   \ 5x8 
  00 c, 00 c, 00 c, 00 c, 00 c, \ 
  00 c, 00 c, 4f c, 00 c, 00 c, \ ! 
  00 c, 03 c, 00 c, 03 c, 00 c, \ " 
  14 c, 3e c, 14 c, 3e c, 14 c, \ # 
  24 c, 2a c, 7f c, 2a c, 12 c, \ $ 
  63 c, 13 c, 08 c, 64 c, 63 c, \ % 
  36 c, 49 c, 55 c, 22 c, 50 c, \ & 
  00 c, 00 c, 07 c, 00 c, 00 c, \ ' 
  00 c, 1c c, 22 c, 41 c, 00 c, \ ( 
  00 c, 41 c, 22 c, 1c c, 00 c, \ ) 
  0a c, 04 c, 1f c, 04 c, 0a c, \ * 
  04 c, 04 c, 1f c, 04 c, 04 c, \ + 
  50 c, 30 c, 00 c, 00 c, 00 c, \ , 
  08 c, 08 c, 08 c, 08 c, 08 c, \ - 
  60 c, 60 c, 00 c, 00 c, 00 c, \ . 
  00 c, 60 c, 1c c, 03 c, 00 c, \ / 
  3e c, 41 c, 49 c, 41 c, 3e c, \ 0 
  00 c, 02 c, 7f c, 00 c, 00 c, \ 1 
  46 c, 61 c, 51 c, 49 c, 46 c, \ 2 
  21 c, 49 c, 4d c, 4b c, 31 c, \ 3 
  18 c, 14 c, 12 c, 7f c, 10 c, \ 4 
  4f c, 49 c, 49 c, 49 c, 31 c, \ 5 
  3e c, 51 c, 49 c, 49 c, 32 c, \ 6 
  01 c, 01 c, 71 c, 0d c, 03 c, \ 7 
  36 c, 49 c, 49 c, 49 c, 36 c, \ 8 
  26 c, 49 c, 49 c, 49 c, 3e c, \ 9 
  00 c, 33 c, 33 c, 00 c, 00 c, \ : 
  00 c, 53 c, 33 c, 00 c, 00 c, \ ; 
  00 c, 08 c, 14 c, 22 c, 41 c, \ < 
  14 c, 14 c, 14 c, 14 c, 14 c, \ = 
  41 c, 22 c, 14 c, 08 c, 00 c, \ > 
  06 c, 01 c, 51 c, 09 c, 06 c, \ ? 
  3e c, 41 c, 49 c, 15 c, 1e c, \ @ 
  78 c, 16 c, 11 c, 16 c, 78 c, \ A 
  7f c, 49 c, 49 c, 49 c, 36 c, \ B 
  3e c, 41 c, 41 c, 41 c, 22 c, \ C 
  7f c, 41 c, 41 c, 41 c, 3e c, \ D 
  7f c, 49 c, 49 c, 49 c, 49 c, \ E 
  7f c, 09 c, 09 c, 09 c, 09 c, \ F 
  3e c, 41 c, 41 c, 49 c, 7b c, \ G 
  7f c, 08 c, 08 c, 08 c, 7f c, \ H 
  00 c, 41 c, 7f c, 41 c, 00 c, \ I 
  38 c, 40 c, 40 c, 41 c, 3f c, \ J 
  7f c, 08 c, 08 c, 14 c, 63 c, \ K 
  7f c, 40 c, 40 c, 40 c, 40 c, \ L 
  7f c, 06 c, 18 c, 06 c, 7f c, \ M 
  7f c, 06 c, 18 c, 60 c, 7f c, \ N 
  3e c, 41 c, 41 c, 41 c, 3e c, \ O 
  7f c, 09 c, 09 c, 09 c, 06 c, \ P 
  3e c, 41 c, 51 c, 21 c, 5e c, \ Q 
  7f c, 09 c, 19 c, 29 c, 46 c, \ R 
  26 c, 49 c, 49 c, 49 c, 32 c, \ S 
  01 c, 01 c, 7f c, 01 c, 01 c, \ T 
  3f c, 40 c, 40 c, 40 c, 7f c, \ U 
  0f c, 30 c, 40 c, 30 c, 0f c, \ V 
  1f c, 60 c, 1c c, 60 c, 1f c, \ W 
  63 c, 14 c, 08 c, 14 c, 63 c, \ X 
  03 c, 04 c, 78 c, 04 c, 03 c, \ Y 
  61 c, 51 c, 49 c, 45 c, 43 c, \ Z 
  00 c, 7f c, 41 c, 00 c, 00 c, \ [ 
  00 c, 03 c, 1c c, 60 c, 00 c, \ \ 
  00 c, 41 c, 7f c, 00 c, 00 c, \ ] 
  0c c, 02 c, 01 c, 02 c, 0c c, \ ^ 
  40 c, 40 c, 40 c, 40 c, 40 c, \ _ 
  00 c, 01 c, 02 c, 04 c, 00 c, \ ` 
  20 c, 54 c, 54 c, 54 c, 78 c, \ a 
  7f c, 48 c, 44 c, 44 c, 38 c, \ b 
  38 c, 44 c, 44 c, 44 c, 44 c, \ c 
  38 c, 44 c, 44 c, 48 c, 7f c, \ d 
  38 c, 54 c, 54 c, 54 c, 18 c, \ e 
  08 c, 7e c, 09 c, 09 c, 00 c, \ f 
  0c c, 52 c, 52 c, 54 c, 3e c, \ g 
  7f c, 08 c, 04 c, 04 c, 78 c, \ h 
  00 c, 00 c, 7d c, 00 c, 00 c, \ i 
  00 c, 40 c, 3d c, 00 c, 00 c, \ j 
  7f c, 10 c, 28 c, 44 c, 00 c, \ k 
  00 c, 00 c, 3f c, 40 c, 00 c, \ l 
  7c c, 04 c, 18 c, 04 c, 78 c, \ m 
  7c c, 08 c, 04 c, 04 c, 78 c, \ n 
  38 c, 44 c, 44 c, 44 c, 38 c, \ o 
  7f c, 12 c, 11 c, 11 c, 0e c, \ p 
  0e c, 11 c, 11 c, 12 c, 7f c, \ q 
  00 c, 7c c, 08 c, 04 c, 04 c, \ r 
  48 c, 54 c, 54 c, 54 c, 24 c, \ s 
  04 c, 3e c, 44 c, 44 c, 00 c, \ t 
  3c c, 40 c, 40 c, 20 c, 7c c, \ u 
  1c c, 20 c, 40 c, 20 c, 1c c, \ v 
  1c c, 60 c, 18 c, 60 c, 1c c, \ w 
  44 c, 28 c, 10 c, 28 c, 44 c, \ x 
  46 c, 28 c, 10 c, 08 c, 06 c, \ y 
  44 c, 64 c, 54 c, 4c c, 44 c, \ z 
  00 c, 08 c, 77 c, 41 c, 00 c, \ { 
  00 c, 00 c, 7f c, 00 c, 00 c, \ | 
  00 c, 41 c, 77 c, 08 c, 00 c, \ } 
  10 c, 08 c, 18 c, 10 c, 08 c, \ ~ 
decimal 
ram 
 
-gestFonts 
marker -gestFonts 
 
\ Translates ASCII to address of bitpatterns: 
: a>bp ( c -- c-adr ) 
    32 max 127 min 
    32 - 5 * FONTS + 
  ; 
 
\ Draw character: 
: char.tx ( c --) 
    \ if 'cr' go to next line 
    dup $0d = 
    if 
        crLine drop 
        exit 
    then 
    \ otherwise, display character 
    addrSSD1306  i2c.addr.write drop \ send SSD1306 address 
    CTRL_DATAS i2c.tx 
    a>bp        \ start addr 
    5 
    for 
        c@+     \ get byte and inc addr 
        i2c.tx  \ transmit byte 
    next 
    drop 
    $00 i2c.tx  \ transmit 'blank' 
    i2c.stop 
  ; 
 
\ display text compiled with s" 
: string.tx ( adr len --) 
    for 
        c@+ char.tx 
    next  
    drop 
  ; 
 
 : disp.test 
 init
 disp.clear
 s" test"
 string.tx
 ;
