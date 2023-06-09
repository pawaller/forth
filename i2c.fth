\ *********************************************************************
\ I2C interface management for FlashForth                             *
\    Filename:      i2c-new.txt                                       *
\    Date:          04.11.2020                                        *
\    Updated:       04.11.2020                                        *
\    File Version:  1.0                                               *
\    MCU:           ARDUINO all models                                *
\    GNU General Public License                                       *
\    FF Version:    5.0                                               *
\    Peter J.  2014-10-27                                             *
\    modified Marc PETREMANN 04 nov 2020                              *
\ *********************************************************************

\ standardisation suggered by Matthias Trute
\ source: https://theforth.net/package/i2c
\ i2c.restart ( -- ) send the restart condition ------------------- OK
\ i2c.start ( -- ) send start condition --------------------------- OK
\ i2c.stop ( -- ) send stop condition ----------------------------- OK
\ i2c.rx ( -- c ) receive 1 byte, send ACK
\ i2c.rxn ( -- c ) receive 1 byte, send NACK
\ i2c.tx ( c -- ) send 1 byte ------------------------------------- OK
\ i2c.wait ( -- ) wait for the bus -------------------------------- OK

\ The following two words are not essential but are useful
\ for tools and checks.

\ i2c.ping? ( addr -- f ) detect the presence of -------------------- OK
\    a device on the bus, f is true if a device at addr responds
\ i2c.status ( -- n ) get i2c status in a system specific way

\ Other sources:
\ i2c amForth: https://theforth.net/package/i2c/current-view/i2c.frt
\   http://amforth.sourceforge.net/TG/recipes/I2C-Slave.html

\ *** essential code from i2c-base-avr-v2.txt ***********
-i2c-new
marker -i2c-new

\ reg: is an alias for CONSTANT
\ use to define registers - for more readability
: reg: ( comp: n --- <name> | exec: --- n)
    create
        ,
    does>
        @
  ;
\ alias for CONSTANT, use to define bits
: bit:  ( c --- <name>)
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


\ use i2c.detect for test and find peripherials connected
\ to i2c bus

-i2c-detect
marker -i2c-detect

: device.detect ( n ---)
    i2c.ping? \ does device respond?
    if      dup 2 u.r
    else    ." -- "
    then
  ;


\ not all bitpatterns are valid 7bit i2c addresses
: i2c.7bitaddr? ( a --)
    $07 $78 within
    if      dup device.detect
    else    ."    "
    then
  ;

\ display header line
: disp.0line ( ---)
    cr
    ."      00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f"
  ;

: start.line? ( n ---)
    $0f and 0=
    if      cr dup 2 u.r ." : "
    then
  ;

: i2c.detect   ( -- )
    i2c.init
    base @ hex
    disp.0line  \ header line
    0 $80
    for
        dup start.line?
        dup i2c.7bitaddr?
        1+
    next
    drop
    cr base !
    i2c.stop
  ;
