;*******************************************************************************
;* Language  : Motorola/Freescale/NXP 68HC11 Assembly Language (aspisys.com/ASM11)
;*******************************************************************************
; JBug11 supplementary talker file for programming external Atmel EEPROM which
; has to have all bytes for writing at any one time within a single
; 'page' of 64 bytes
;
; Written by John Beatty, March 2009
; Optimized and augmented by Tony Papadimitriou, February 2011
;
; The s19 file produced from this is used to overwrite the standard
; talker (Talk_E.BOO) in page-zero memory when programming EEPROM.
; When the operation is finished, the standard talker is reinstated.
;
; The original overlay file (for the Atmel FLASH part number AT29C256)
; was based on the work of Thomas Morgenstern, to whom many thanks for
; the inspiration
;
; To use this overlay, check that the range of external EEPROM memory
; is specified in Settings>Memory Map under 'External Page-written' and/or
; 'External Byte-written' (page is faster) and the data page size is correctly
; entered (64 bytes for the Atmel AT28C256) and that 'Writes are whole page only'
; is NOT ticked.
;
; Also specify 'at28256.rec' in the 'Ext. Byte-written' and 'Ext. Page-written'
; boxes on Settings>Overlays, and set MCU to expanded mode (HPRIO = E5)
;
; Note that bytes are echoed to the host as soon as they have been added
; to the buffer, so the echo does not confirm that they have been correctly
; programmed in EEPROM. It is therefore advisable to do a verification after
; writing.
;
; Since the internal Bootstrap ROM may overlap the external EEPROM, the first
; must be disabled during the actual programming sequence, or else there may be
; conflict.  No problem doing so, because interrupts are conveniently disabled
; during that period.  This version automatically does this.
;*******************************************************************************
                    #CaseOn
;*******************************************************************************
; Macros
;*******************************************************************************

DisableBootROM      macro
                    bsr       ~0~
                    endm

;-------------------------------------------------------------------------------

EnableBootROM       macro
                    bsr       ~0~
                    endm

;*******************************************************************************
; Various equates:
;*******************************************************************************

                    #Uses     jbug.exp            ;various constant definitions

;******************************************************************************
; Command(s) accepted by this talker overlay for programming page-written

CMD_WRITE_EXTPAGE   def       $22                 ;external page write cmd
CMD_WRITE_EXTBYTE   def       $42                 ;external byte write cmd
NOT                 def       $FF                 ;Mask to invert a byte value

;-------------------------------------------------------------------------------

VECTORS             def       $00C4               ; bootstrap redirected vectors

RxSrv1              def       $003E
RxSrv1_EndOvr       def       RxSrv1+3
                    #MEMORY   RxSrv1 RxSrv1_EndOvr ; free for overlay routine

NullSrv             def       $0058
InSCI               def       $0059

Inh1                def       $0075               ; Inh1 to ...
                    #MEMORY   Inh1 VECTORS-1      ; ... $C3 free for overlay routine

REGS                def       $1000
SCDR                def       REGS+$2F
HPRIO               def       REGS+$3C

; Following constant is the base address of a buffer to be located anywhere in
; free RAM. The required buffer size is equal to the EEPROM writing data
; page length, subject to a maximum buffer size of 256 because of limitations
; in the main talker. Note that the E-series main talker places the top-of-stack
; at $01FF, and this would be incompatible with a data page size of 256 starting
; at $0100, although perfectly satisfactory for smaller data page sizes.
; If you are using an E0, E1 or E9 chip and need a data page size of 256 bytes,
; then use the E2 talker which sets the stack pointer to $00FF.

; RAM available in expanded memory can be used equally well (make sure expanded
; memory can be accessed by setting HPRIO to $E5).

RecBuf              equ       $0100

; Constant to record the base address of the EEPROM chip as seen by the MCU
; Needed only if Software Data Protection is in use

EepromBase          def       $8000               ;alter to suit actual location

SDP                                               ;Enable Software Data Protection

;*******************************************************************************
; This file alters two different locations within the talker. The first
; alteration puts a different branch destination at RxSrv1 in the standard
; talker:
                    org       RxSrv1

                    cmpa      #CMD_WRITE_BYTE^NOT
                    bne       RxSrv2

;*******************************************************************************
; The second alteration overwrites the area of the talker devoted to
; processing requests for inherent (register) data, and the routine which
; responds to SWI's.  These are not needed during memory programming operations.

                    org       Inh1

RxSrv2              proc
          ;--- next 2 lines can go if we run out of room for more important things
                    cmpa      #CMD_WRITE_EXTBYTE^NOT        ; is it byte-write command?
                    beq       Go@@                          ; yes, go (same as page)
          ;---
                    cmpa      #CMD_WRITE_EXTPAGE^NOT        ; is it (not) a page-write command?
                    bne       NullSrv

Go@@                tba                           ; Transfer byte count to A

                    psha                          ; Save byte-counter on stack
                    ldy       #RecBuf             ; Base of buffer for incoming data

          ; At this point in the program:
          ; A  = Byte count
          ; IX = Write address
          ; IY = Base address of buffer

TWriteEE@@          bsr       InSCI               ; Read byte (byte returns in B)
                    stb       ,y                  ; Store byte to buffer
                    stb       SCDR                ; Echo back to host.
                    iny
                    deca
                    bne       TWriteEE@@          ; Get next byte

          ; If the EEPROM memory has Software Data Protection enabled, then
          ; instructions may be inserted here to write the necessary un-lock
          ; codes to the memory chip.
          ; The codes required by Atmel's 28C256 chip are shown below:

                    @DisableBootROM
          #ifdef SDP
                    ldd       #$AAA0              ; A = $AA, B = $A0
                    sta       EepromBase+$5555
                    coma
                    sta       EepromBase+$2AAA
                    stb       EepromBase+$5555
          #endif

          ; Now write the data page to the EEPROM

                    pula                          ; Restore byte count

                    ldy       #RecBuf             ; Point again to source buffer
NextByte@@          ldb       ,y                  ; Load byte from source buffer
                    stb       ,x                  ; Store to destination address
                    inx                           ; Destination pointer + 1
                    iny                           ; Source pointer + 1
                    deca
                    bne       NextByte@@          ; All bytes of record have been written?

                    @EnableBootROM

;*******************************************************************************
; Now delay so that EEPROM is written
; The delay should be adjusted to the memory chip requirements, and here
; note that 3ms may be substituted for 10ms if the AT28C256F part is used

                    jsr       Delay10ms
                    rti                           ; and return

;*******************************************************************************
; Interaction with the outside world:
;
;      Writing page-written memory:
;
;      1.      Host sends $22
;      2.      MCU replies with $DD (one's complement of $22)
;      3.      Host sends byte count ($00 to $FF)
;
; Note that the byte count must be less than or equal to the page length,
; and must be chosen in conjunction with the starting address so that all
; bytes to be written lie within a single page (this is handled
; automatically by JBug11)
;
;      4.      Host sends high byte of starting address in EEPROM
;      5.      Host sends low byte of the address
;
;      6.      Host sends first byte of data for EEPROM
;      7.      MCU acknowledges by echoing same byte
;
;      8.      Repeat 6 & 7 until all data bytes sent
