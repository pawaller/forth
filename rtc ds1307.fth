\ RTC DS1307 i2c module

-rtc 
marker -rtc

\ i2c device address 
$68 constant addr-ds1307 

: i2c! ( c ---) 
    i2c.c! drop
; 

: ds1307.addr! ( c -- )  \ Set ds1307 register address 
    i2c.init  
    addr-ds1307  i2c.addr.write drop 
    i2c! i2c.stop 
; 

: time! ( Y M D d HH MM SS  -- ) 
    i2c.init addr-ds1307  i2c.addr.write drop 
    0 i2c!  
    i2c! i2c! i2c!  
    i2c! i2c! i2c! i2c! 
    i2c.stop 
; 

: time@ ( -- S M H d D M Y ) 
    0 ds1307.addr! 
    addr-ds1307 i2c.addr.read drop 
    i2c.c@.ack i2c.c@.ack i2c.c@.ack 
    i2c.c@.ack i2c.c@.ack i2c.c@.ack i2c.c@.nack 
    i2c.stop 
; 

: bin>bcd ( c -- c ) 
    #10 u/mod #4 lshift or 
;

: set-time ( year month date day hour min sec -- ) 
    >r >r >r >r >r >r 
\    $00 swap     \ 11 = 4.096 KHz output 00 = no output 
    bin>bcd      \ Year 0-99 
    r> bin>bcd   \ Month 
    r> bin>bcd   \ Date 
    r>           \ Day 1-7 
    r> bin>bcd   \ Hours 
    r> bin>bcd   \ Minutes 
    r> bin>bcd   \ Seconds 
    time! 
;

\ set-time example
\ i2c.init 
\ 19 11 12 2 18 06 0 set-time

: bcd>bin ( c --- c) 
    #16 u/mod 10 * +
;

: :## ( d1 --- d2 ) 
    decimal # 
    6 base ! #  decimal  
    [char] : hold   
  ; 
: HMS ( s m h --- adr len) 
    bcd>bin 3600 um* rot  bcd>bin 60 um* d+  rot bcd>bin 0 d+ 
    <#  :##  :## #s #> 
  ; 
: DMY ( d m y --- adr len) 
    bcd>bin 0 <# # # [char] 0 hold [char] 2 hold 
    2drop bcd>bin 0  [char] / hold # #  
    2drop bcd>bin 0  [char] / hold # #   
    #> 
;

: .date ( ---) 
    time@ DMY type space  
    drop  HMS type  
;


