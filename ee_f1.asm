;*******************************************************************************
;* Language  : Motorola/Freescale/NXP 68HC11 Assembly Language (aspisys.com/ASM11)
;*******************************************************************************
; JBug11 supplementary talker file for writing to EEPROM on F1 series chips
; The s19 file produced from this is used to overwrite the standard talker
; (JBug.boo) in page-zero memory when programming EEPROM. When the operation
; is finished, the standard talker is reinstated.
;
; This utility is arranged to erase bytes back to $FF if necessary, before
; writing them, and to skip the programming of bytes if they already have the
; correct value.
;*******************************************************************************
                    #CaseOn

                    #Uses     jbug.exp            ;various constant definitions

RxSrv1              def       $003E
RxSrv1_EndOvr       def       RxSrv1+3
                    #MEMORY   RxSrv1 RxSrv1_EndOvr ; free for overlay routine

NullSrv             def       $0058
InSCI               def       $0059
Inh1                def       $0075               ; Inh1 to ...
                    #MEMORY   Inh1 VECTORS-1      ; ... $C3 free for overlay routine

REGS                def       $1000
SCDR                def       REGS+$2F
PPROG               def       REGS+$3B

; Command accepted by this talker for writing EEPROM is:
; EEPROM byte write:    $02     (1's complement: $FD)
;
; This file alters two different locations within the talker. The first
; alteration puts a different branch destination at RxSrv1 in the standard
; talker:

                    org       RxSrv1

                    cmpa      #CMD_WRITE_BYTE^NOT
                    bne       RxSrv2

; The second alteration overwrites the area of the talker devoted to
; processing requests for inherent (register) data, and the routine
; which responds to SWI's.  These are not needed during EEPROM writing
; operations

                    org       Inh1

RxSrv2              proc
                    cmpa      #CMD_WRITE_EEPROM^NOT  ; is it (not) EEPROM byte write?
                    bne       NullSrv

                    tba                           ; Transfer byte count to A
;                   bra       TWritEE

;*******************************************************************************
; At this point in the program:
; A  = Byte count
; IX = Write address

TWritEE             proc
                    bsr       InSCI               ; Read byte (byte returns in B)
                    ldy       #REGS
                    cmpb      ,x                  ; Does byte already have desired value?
                    beq       Done@@              ; then skip programming cycle

                    psha                          ; we need A to check erased state
                    lda       ,x                  ; Fetch current memory value
                    cmpa      #$FF                ; Is it an erased byte?
                    pula
                    beq       Skip@@              ; then skip the erase cycle

                    bset      [PPROG,y,$16        ; Set 'byte erase' mode
                    bsr       Prog

Skip@@              bset      [PPROG,y,$02        ; Set 'byte programming' mode
                    bsr       Prog

Done@@              ldb       ,x                  ; Read stored byte, and
                    stb       SCDR                ; echo back to host.
                    inx                           ; Increment memory location
                    deca                          ; Decrement byte count
                    bne       TWritEE             ; until all done
                    rti

;-------------------------------------------------------------------------------

Prog                proc
                    stb       ,x                  ; Store data to EEPROM address
                    bset      [PPROG,y,$01        ; Turn on EPGM
                    bsr       Delay10ms
                    clr       PPROG               ; turn off high voltage & set to read mode
                    rts

;*******************************************************************************
; Interaction with the outside world:
;
;       write EEPROM bytes
;
;       1.      Host sends $02
;       2.      MCU replies with $FD (one's complement of $02)
;       3.      Host sends byte count ($00 to $FF)
;       4.      Host sends high byte of address
;       5.      Host sends low byte of address
;
;       6.      Host sends first byte for EEPROM
;       7.      MCU acknowledges by echoing same byte
;
;       8.      Repeat 6 & 7 until all bytes sent
;*******************************************************************************
