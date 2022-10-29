.db "NES", $1A, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0

.org $8000

.define PPUCTRL $2000
.define PPUMASK $2001
.define PPUSTATUS $2002
.define PPUSCROLL $2005
.define PPUADDR $2006
.define PPUDATA $2007
.define OAMADDR $2003
.define OAMDATA $2004
.define OAMDMA $4014

.define JOYPAD1 $4016

;Input variables
.define buttons $02

; Logo variables
.define current_drawing_tile $05
.define addr_low_byte $03
.define addr_high_byte $04
.define logo_starting_tile #$40
.define logo_width #$10
.define logo_height #$08

; Creatura variables
.define sprite_page #$02
.define x_pos $0203
.define y_pos $0200
.define sprite_tile $0201
.define sprite_attr $0202

; Creatura sprite index
.define look_horizontal #$00
.define look_down #$01
.define look_up #$02

; Scroll variables
.define x_cam_pos $00
.define y_cam_pos $01
.define current_nametable $07

start:
  ;enable NMI and other stuff
  LDA #%10001000
  STA PPUCTRL

  ;set view to nametable0
  LDA #$00
  STA current_nametable

  ;enable background and sprites
  LDA #%00011110
  STA PPUMASK

  ;set to $3F00 for background palette0
  LDA #$3F
  STA PPUADDR
  LDA #00
  STA PPUADDR

  ;set colors
  LDA #$0D
  STA PPUDATA
  LDA #$0C
  STA PPUDATA
  LDA #$28
  STA PPUDATA
  LDA #$0C
  STA PPUDATA

  ;set to $3F11 for sprite palette0, skipping first
  LDA #$3F
  STA PPUADDR
  LDA #$11
  STA PPUADDR
  ;set sprite colors
  LDA #$0D
  STA PPUDATA
  LDA #$3C
  STA PPUDATA
  LDA #$3C
  STA PPUDATA

  ;load background

  ;load nametable0 address
  LDA #$21
  STA PPUADDR
  STA addr_high_byte
  LDA #$08
  STA PPUADDR
  STA addr_low_byte

  JSR load_background

  ;load nametable1 address
  LDA #$25
  STA PPUADDR
  STA addr_high_byte
  LDA #$08
  STA PPUADDR
  STA addr_low_byte

  JSR load_background

  ;load first sprite
  LDA #$32
  STA x_pos
  STA y_pos
  LDA #$00
  STA sprite_tile
  STA sprite_attr
  LDA #$02
  STA OAMDMA
  loop:
    JMP loop

; At the same time that we strobe bit 0, we initialize the ring counter
; so we're hitting two birds with one stone here
readjoy:
  LDA #$01
  ; While the strobe bit is set, buttons will be continuously reloaded.
  ; This means that reading from JOYPAD1 will only return the state of the
  ; first button: button A.
  STA JOYPAD1
  STA buttons
  LSR a        ; now A is 0
  ; By storing 0 into JOYPAD1, the strobe bit is cleared and the reloading stops.
  ; This allows all 8 buttons (newly reloaded) to be read from JOYPAD1.
  STA JOYPAD1
joyloop:
  LDA JOYPAD1
  LSR a           ; bit 0 -> Carry
  ROL buttons  ; Carry -> bit 0; bit 7 -> Carry
  BCC joyloop
RTS

nmi:
  PHA
  JSR readjoy
  PLA
    
  ;Control background scrolling on A and B
  ;Check right with A
  LDA buttons
  AND #%10000000
  BEQ skip_scroll_forward
    ;Check if x is overflowing
    LDA x_cam_pos
    CMP #$FF
    BNE not_overflowing
      LDA current_nametable
      CMP #$00 ;If nametable0, go to nametable1, else stop
      BNE not_nametable0
        LDA #$04
        STA current_nametable
        JMP not_overflowing
      not_nametable0:
      JMP skip_scroll_forward
    not_overflowing:
    INC x_cam_pos
  skip_scroll_forward:
  
  ;Check left with B
  LDA buttons
  AND #%01000000
  BEQ skip_scroll_backwards
    ;Check if x is overflowing
    LDA x_cam_pos
    CMP #$00
    BNE not_underflowing
      LDA current_nametable
      CMP #$04 ;If nametable1, go to nametable0, else stop
      BNE not_nametable1
        LDA #$00
        STA current_nametable
        JMP not_underflowing
      not_nametable1:
      JMP skip_scroll_backwards
    not_underflowing:
    DEC x_cam_pos
  skip_scroll_backwards:

  ;Control Creatura
  ;Go right
  LDA buttons
  AND #%00000001
  BEQ skip_right
    LDA look_horizontal
    STA sprite_tile
    LDA sprite_attr
    AND #%00111111
    STA sprite_attr
    INC x_pos
  skip_right:
  ;Go left
  LDA buttons
  AND #%00000010
  BEQ skip_left
    LDA look_horizontal
    STA sprite_tile
    LDA sprite_attr
    ORA #%01000000
    STA sprite_attr
    DEC x_pos
  skip_left:
  ;Go down
  LDA buttons
  AND #%00000100
  BEQ skip_down
    LDA look_down
    STA sprite_tile
    INC y_pos
  skip_down:
  ;Go up
  LDA buttons
  AND #%00001000
  BEQ skip_up
    LDA look_up
    STA sprite_tile
    DEC y_pos
  skip_up:
  LDA sprite_page
  STA OAMDMA 

  ;Scroll background
  LDA #%10001000
  STA PPUCTRL

  ;Choose nametable, high byte in ppuaddr
  LDA current_nametable
  STA PPUADDR

  ;Get scroll, inverted because write flag
  LDA y_cam_pos
  STA PPUSCROLL
  LDA x_cam_pos
  STA PPUSCROLL

  ;Low byte in ppuaddr, which is position based on x and y
  ; ((x_cam_pos & %11111000) >> 3) | ((y_cam_pos & %00111000) << 2) 
  LDA x_cam_pos
  AND #%11111000
  LSR A
  LSR A
  LSR A
  STA $10 ; temp cell will be cleared
  LDA y_cam_pos
  AND #%00111000
  ASL A
  ASL A
  ORA $10
  STA PPUADDR

RTI

irq:
  RTI

load_background:
  LDX #$00
  LDY #$00
  LDA #$40 ;first tile logo
  STA current_drawing_tile
  background_loop:
        LDA current_drawing_tile
        STA PPUDATA
        INC current_drawing_tile
        INC addr_low_byte
        INX
        CPX logo_width
        BNE background_loop
      LDX #$00
      INY
      LDA addr_low_byte
      ASL A ;Check if last bit
      BCS last_bit
      LDA addr_low_byte
      ADC #$10
      set_address:
      STA addr_low_byte 
      LDA addr_high_byte
      STA PPUADDR
      LDA addr_low_byte
      STA PPUADDR
      CPY logo_height
      BNE background_loop
  RTS

  last_bit:
    LDA addr_low_byte
    ADC #$0F
    BCC no_overflow
        INC addr_high_byte
    no_overflow:
    JMP set_address

.goto $FFFA

.dw nmi
.dw start
.dw irq

.incbin "chr/aiv256.chr"
.incbin "chr/creatura.chr"
