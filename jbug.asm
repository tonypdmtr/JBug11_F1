;*******************************************************************************
;* Language  : Motorola/Freescale/NXP 68HC11 Assembly Language (aspisys.com/ASM11)
;*******************************************************************************
; This is the program for the various main JBug11 talkers
;
; This file may be used to assemble talkers for A, E and F1 variants of the
; MC68HC11 MCU.
;
; This assembly language file will produce talkers compatible with the Motorola
; ones, but note that a leading $FF must be added to establish the baud rate.
; (Couldn't JBug11 send this $FF byte just before sending the talker binary?)
;
; Use the conditional assemby commands below to select the type of interrupt
; control mechanism which JBug11 will use to get control of the MCU:
;*******************************************************************************
                    #CaseOn
;*******************************************************************************
; Talker Commands
;*******************************************************************************

;-------------------------------------------------------------------------------
; Basic
;-------------------------------------------------------------------------------

CMD_READ_BYTE       exp       $01
CMD_WRITE_BYTE      exp       $41
CMD_READ_REG        exp       $81
CMD_WRITE_REG       exp       $C1
CMD_SWI             exp       $B5

CMD_SWI_REPLY       def       $4A

;-------------------------------------------------------------------------------
; Special memory
;-------------------------------------------------------------------------------

CMD_WRITE_EEPROM    exp       $02
CMD_WRITE_OTP       exp       $20
CMD_WRITE_EXTBYTE   exp       $42
CMD_WRITE_EXTPAGE   exp       $22

;-------------------------------------------------------------------------------
; Indirect memory
;-------------------------------------------------------------------------------

CMD_READ_INTREG     exp       $31
CMD_WRITE_INTREG    exp       $32
CMD_READ_INTMEM     exp       $33
CMD_WRITE_INTMEM    exp       $34

;-------------------------------------------------------------------------------

NOT                 exp       $FF                 ; Mask to invert a byte value
RBOOT_              equ       $80

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
; Definitions of various constant defaults
;*******************************************************************************

IntType             def       0                   ; 0 for a .BOO talker not using XIRQ
                                                  ; 1 for a .XOO talker using XIRQ
MHZ                 def       8                   ; default MCU crystal speed (MHz)
BUS_MHZ             def       MHZ/4               ; default MCU bus speed (MHz)
BUS_KHZ             def       BUS_MHZ*1000        ; default MCU bus speed (KHz)

MCU                 def       $F1                 ; default MCU variant (F1)

REGS                def       $1000               ; Base address for control registers
SCSR                equ       REGS+$2E            ; SCI status register
SCDR                equ       REGS+$2F            ; SCI data register
BAUD                equ       REGS+$2B            ; BAUD register
SCCR1               equ       REGS+$2C            ; SCI control register 1
SCCR2               equ       REGS+$2D            ; SCI control register 2
HPRIO               equ       REGS+$3C

VECTORS             def       $00C4               ; bootstrap redirected vectors

;*******************************************************************************
; Select where the stack will go (based on variant used):

?                   macro     MCU,Stack
          #if MCU = $~1~
STACKTOP            def       ~2~
          #endif
                    endm

                    @?        A,$00ED             ; for A
                    @?        E2,$00ED            ; for 811E2
                    @?        E0,$01FF            ; for E0
                    @?        E1,$01FF            ; for E1
                    @?        E9,$01FF            ; for E9
                    @?        E20,$02FF           ; for E20
                    @?        F1,$03FF            ; for F1

          #ifndef STACKTOP
                    #Error    MCU must = A, E2, E0, E1, E9, E20, or F1
          #endif

;*******************************************************************************

talker_start        def       0                   ;talker starts at beginning of RAM

                    #ROM
                    org       talker_start

          ; Set the stack pointer SP to a suitable value for the chip

                    lds       #STACKTOP

          ; Set up the SCI for communication with the host

                    ldx       #REGS
                    clr       [SCCR1,x            ; Clear SCCR1, i.e. 1 start, 8 data,
                                                  ; 1 stop; and idle-line wake-up

; Load the BAUD and SCCR2 registers. BAUD is loaded with $30 for a communication
; rate of 9612 with an 8MHz crystal. This is the closest available rate to 9600,
; and quite close enough to work with the UART in PC's

; SCCR2 is loaded with either $2C for a .BOO type talker, or $0C for an .XOO one.

; $2C means:
; TIE   Transmit interrupt enable               = 0
; TCIE  Transmit complete interrupt enable      = 0
; RIE   Receive interrupt enable                = 1 for a .BOO talker
; ILIE  Idle line interrupt enable              = 0
; TE    Transmit enable                         = 1
; RE    Receive enable                          = 1
; RWU   Receiver wake-up                        = 0
; SBK   Send break                              = 0

; $0C means:
; TIE   Transmit interrupt enable               = 0
; TCIE  Transmit complete interrupt enable      = 0
; RIE   Receive interrupt enable                = 0 for an .XOO talker
; ILIE  Idle line interrupt enable              = 0
; TE    Transmit enable                         = 1
; RE    Receive enable                          = 1
; RWU   Receiver wake-up                        = 0
; SBK   Send break                              = 0

          #ifz IntType
                    ldd       #$302C
          #else
                    ldd       #$300C
          #endif
                    sta       [BAUD,x             ; 9600 baud. $2B is the BAUD register offset
                    stb       [SCCR2,x            ; See note above

          #ifz IntType
                    lda       #$40                ; CCR = - X - - - - - -
          #else                                   ; i.e. /XIRQ disabled, /IRQ enabled
                    lda       #$10                ; CCR = - - - I - - - -
          #endif                                  ; i.e. /XIRQ enabled, /IRQ disabled
                    tap                           ; Transfer to CCR

;*******************************************************************************
talker_idle         bra       *                   ; Hang-around loop
;*******************************************************************************

sci_srv             proc
                    bsr       InSCI               ; Read a byte from the SCI
                    tba                           ; ... into A

          ; Echo the received character back to the host in inverted form
          ; inverted as a safety precaution?

                    coma                          ; Do a one's complement
                    bsr       OutSci              ; and echo to host

          ; The most significant bit of command bytes is used as a flag that
          ; what follows is a command to read or write the CPU inherent
          ; registers. This bit is tested next by the Branch if Plus (BPL)
          ; operation, remembering that the command byte has been inverted

                    bpl       Inh1                ; branch if inherent register command

          ; Else read byte count from host into ACCB

                    bsr       InSCI               ; Read byte count from host

                    xgdx                          ; Save command & byte count in IX

          ; Read the high address byte from host into ACCA, then read low
          ; address byte into ACCB

                    bsr       InSCI               ; Read
                    tba                           ; Result returns in B, so move to A
                    bsr       InSCI               ; Read

          ; Restore (inverted) command byte to A, byte count to B, and save
          ; address in IX

                    xgdx

          ; Is the command a 'memory read'?
          ; Check by comparing the (inverted) command with $FE
          ; This implies original memory read command is $01

                    cmpa      #CMD_READ_BYTE^NOT
                    bne       RxSrv1              ; Maybe it's a 'memory write' command ?

          ; Following section reads memory and sends it to the host

TReadMem            @DisableBootROM
                    lda       ,x                  ; Fetch byte from memory
                    bsr       OutSci              ; Send byte to host
                    @EnableBootROM

                    tba                           ; Save byte count
                    bsr       InSCI               ; Wait for host acknowledgement (may be any char)
                    tab                           ; Restore byte count

                    inx                           ; Increment address
                    decb                          ; Decrement byte count
                    bne       TReadMem            ; branch until done
                    rti                           ; Return to idle loop or user code

;*******************************************************************************

EnableBootROM       proc
                    lda       HPRIO
                    ora       #RBOOT_             ; RBOOT = 1
                    bra       SaveHPRIO

;-------------------------------------------------------------------------------

DisableBootROM      proc
                    lda       HPRIO
                    anda      #RBOOT_^NOT         ; RBOOT = 0
SaveHPRIO           sta       HPRIO
                    rts

;*******************************************************************************
; Run a 'wait' loop to allow for external EEPROM.  The assembler will auto-
; matically calculate the correct delay constant based on the defined BUS speed
; (symbol BUS_KHZ which is derived from MHZ, etc.).  This is common delay for
; use by this talker and its overlay routines.

MS_TO_DELAY         def       10                  ;msec to delay (default = 10)

                    #Cycles

Delay10ms           proc
                    pshx
                    ldx       #DELAY@@            ; Set up wait loop and run

                    #Cycles

Loop@@              dex                           ; [4]
                    bne       Loop@@              ; [3]

                    #temp     :cycles

                    pulx
                    rts

DELAY@@             equ       MS_TO_DELAY*BUS_KHZ-:cycles-:ocycles/:temp

;*******************************************************************************
; Is the command a 'memory write'?  Check by comparing the (inverted)
; command with $BE
; This implies original memory write command is $41

RxSrv1              cmpa      #CMD_WRITE_BYTE^NOT ; If unrecognised command received simply return
                    bne       NullSrv             ; i.e. branch to an RTI
RxSrv1_EndOvr       equ       *-1                 ; marks the end of this overlaid section

          ; Following section writes bytes from the host to memory

                    tba                           ; Save byte count in A

          ; Read the next byte from the host.  Byte goes into B

TWriteMem           bsr       InSCI               ; Read byte
                    stb       ,x                  ; Store it at the next address

                    ldb       ,x                  ; Read stored byte, and
                    stb       SCDR                ; echo back to host

                    inx                           ; Increment memory location
                    deca                          ; Decrement byte count
                    bne       TWriteMem           ; until all done

NullSrv             rti

;*******************************************************************************
;               SUBROUTINES TO SEND AND RECEIVE A SINGLE BYTE
;*******************************************************************************

;*******************************************************************************
; Purpose: InSCI gets the received byte from the host PC via the SCI.
; Input  : None
; Output : B = received byte

InSCI               ldb       SCSR                ; Load B from the SCI status register

; Test B against $0A, %00001010, for a 'break' character being received.
; If a 'break' character is received, then the OR and/or FE flags will be set

          ; TDRE  Transmit data register empty    = ?     (? = irrelevent)
          ; TC    Transmit complete               = ?
          ; RDRF  Receive data register full      = ?
          ; IDLE  Idle-line detect                = ?
          ; OR    Overrun error                   = 0
          ; NF    Noise flag                      = ?
          ; FE    Framing error                   = 0
          ; 0                                     = ?

                    bitb      #$0A                ; If break detected, then
                    bne       talker_start        ; restart talker

          ; Test B against the RDRF mask, $20, %0010:0000

          ; TDRE  Transmit data register empty    = ?
          ; TC    Transmit complete               = ?
          ; RDRF  Receive data register full      = 1
          ; IDLE  Idle-line detect                = ?
          ; OR    Overrun error                   = ?
          ; NF    Noise flag                      = ?
          ; FE    Framing error                   = ?
          ; 0     (always reads zero)             = ?

                    andb      #$20                ; If RDRF not set then
                    beq       InSCI               ; listen for char from host

          ; Read data received from host and return it in B

                    ldb       SCDR
                    rts

;*******************************************************************************
; Purpose: OutSCI is the subroutine which transmits a byte from the SCI to the host PC
; Input  : A = Byte to send
; Output : None

OutSci              proc
                    tst       SCSR                ; Load A from the SCI status register

          ; If TDRE, the Transmit Data Register Empty flag is not set then loop round.
          ; Not by chance, the TDRE flag is the msb of the SCI status register

                    bpl       OutSci
                    sta       SCDR                ; Send byte
                    rts

;*******************************************************************************
;               READING AND WRITING THE CPU INHERENT REGISTERS
;*******************************************************************************

;*******************************************************************************
; Now decide which CPU inherent register command was sent.
; If command is to read the MCU registers then the one's complement of the
; command will be $7E (command = $81)

Inh1                proc
                    cmpa      #CMD_READ_REG^NOT
                    bne       WriteReg@@          ; Maybe a write of the registers?

;-------------------------------------------------------------------------------
; READ REGISTERS
;-------------------------------------------------------------------------------

ReadReg@@           tsx                           ; Store stack pointer in IX
                    xgdx                          ; then to D

          ; Send stack pointer to host, high byte first. Note that the value
          ; sent is SP+1 because the TSX command increments SP on transfer to IX

                    bsr       OutSci              ; Send byte
                    tba
                    bsr       OutSci              ; Send byte

                    tsx                           ; Again store stack pointer to IX

          ; Use TReadMem to send 9 bytes on the stack

                    ldb       #9
                    bra       TReadMem

          ; If the command was to write MCU registers, then the one's complement
          ; of the command would be $3E (command = $C1)

WriteReg@@          cmpa      #CMD_WRITE_REG^NOT  ; If not $3E then
                    bne       SwiSrv1             ; Maybe to service an SWI?

;-------------------------------------------------------------------------------
; WRITE REGISTERS
;-------------------------------------------------------------------------------

; Get stack pointer from host, high byte first. Note that the host needs to send
; SP+1 because the TXS operation will decrement the IX value by 1 on transfer to
; SP.

                    bsr       InSCI
                    tba
                    bsr       InSCI

                    xgdx                          ; Move to IX
                    txs                           ; and copy to Stack Pointer

          ; Use TWriteMem to get the next nine bytes from the host onto the stack

                    lda       #9
                    bra       TWriteMem

;*******************************************************************************
; Breakpoints generated by SWI instructions cause this routine to run
; The code $4A is sent to the host as a signal that a breakpoint has been reached

swi_srv             lda       #CMD_SWI_REPLY
                    bsr       OutSci

;*******************************************************************************
; Now enter idle loop until the acknowledge signal is received from the host (also $4A)

SWIidle             equ       *
          #ifz IntType
                    cli                           ; Enable interrupts
          #else
                    sei                           ; Disable interrupts (except /XIRQ)
          #endif
                    bra       SWIidle

;*******************************************************************************
; If command from host is an acknowledgement of breakpoint ($B5 complemented, = $4A),
; then the stack pointer is unwound 9 places, ie to where it was before the host
; acknowledged the SWI

SwiSrv1             cmpa      #CMD_SWI^NOT
                    bne       NullSrv             ; branch to $0058 (NullSrv).
                                                  ; If not $4A then simply return
;-------------------------------------------------------------------------------
; HOST SERVICE SWI
;-------------------------------------------------------------------------------

                    tsx                           ; Copy stack pointer to IX
                    ldb       #9                  ; Load B with 9
                    abx                           ; Add 9 to IX
                    txs                           ; Copy IX to the stack pointer

          ; Send the breakpoint return address to the host, high byte first.
          ; Note that the address sent is actually the one immediately following
          ; the address at which the break occurred.

                    ldd       7,x
                    bsr       OutSci
                    tba
                    bsr       OutSci

          ; Alter the value of PC on the return stack to be the address of the
          ; SWIidle routine, so that after sending the CPU registers to the host
          ; the CPU will enter the idle routine

                    ldd       #SWIidle            ; Force idle loop on return
                                                  ; from breakpoint processing
                    std       7,x
                    bra       ReadReg@@           ; Return all CPU registers to host

;*******************************************************************************
; END OF TALKER CODE
;*******************************************************************************

                    #temp     {VECTORS-:PC}
          #if :temp < 0
                    #Warning  Out-of-memory ({:temp})
                    #temp
          #endif
          #ifnz :temp
                    fcb::temp 0                   ; Any remaining space is blank
          #endif

;*******************************************************************************
; Interrupt pseudo-vectors.
; Unlabelled interrupts all point to NullSrv which is an RTI instruction.
;*******************************************************************************

                    #VECTORS
                    org       VECTORS

                    !jmp      sci_srv             ; SCI -> sci_srv
                    !jmp:13   NullSrv             ; Unused ints (TOS FOR SMALLER DEVICES)
                    !jmp      NullSrv             ; /IRQ
          #ifz IntType
xirq_jmp            !jmp      NullSrv             ; /XIRQ -> Nullsrv
          #else
xirq_jmp            !jmp      sci_srv             ; /XIRQ -> sci_srv
          #endif
                    !jmp      swi_srv             ; SWI
swi_jmp             equ       *-2,2               ; label refers to address
                    !jmp      talker_start        ; Illegal opcode -> restart
illop_jmp           equ       *-2,2               ; label refers to address
                    !jmp:2    NullSrv             ; COP and CMF failure

          #ifdef DEBUG                            ; for simulator runs
                    org       $FFD6
                    dw        sci_srv

                    org       $FFFE
                    dw        talker_start
          #endif

;*******************************************************************************
; Export needed symbols to the .EXP file (which will also be used as a MAP file)
;*******************************************************************************

                    #Export   talker_start,talker_idle,swi_srv,swi_jmp,illop_jmp

          ;--- the symbols below are for making overlay assembly fully automatic

                    #Export   RxSrv1,RxSrv1_EndOvr,Inh1,NullSrv,InSCI,VECTORS
                    #Export   EnableBootROM,DisableBootROM,Delay10ms
                    #Export   REGS

;*******************************************************************************
;               COMMUNICATION FLOW - PC <--> TALKER
;*******************************************************************************
;
;-------------------------------------------------------------------------------
; Read Memory Bytes
;-------------------------------------------------------------------------------
;
; 1.      Host sends $01
; 2.      MCU replies with $FE (one's complement of $01)
; 3.      Host sends byte count ($00 to $FF)
; 4.      Host sends high byte of address
; 5.      Host sends low byte of address
;
; 6.      MCU  sends first byte of memory
; 7.      Host acknowledges with any old byte
;
; 8.      Repeat 6 & 7 until all bytes read
;
;-------------------------------------------------------------------------------
; Write Memory bytes
;-------------------------------------------------------------------------------
;
; 1.      Host sends $41
; 2.      MCU replies with $BE (one's complement of $41)
; 3.      Host sends byte count ($00 to $FF)
; 4.      Host sends high byte of address
; 5.      Host sends low byte of address
;
; 6.      Host sends first byte of memory
; 7.      MCU acknowledges by echoing same byte
;
; 8.      Repeat 6 & 7 until all bytes sent
;
;-------------------------------------------------------------------------------
; Read MCU Registers
;-------------------------------------------------------------------------------
;
; 1.      Host sends $81
; 2.      MCU replies with $7E
; 3.      MCU  sends high byte of Stack Pointer   } Note 1
; 4.      MCU  sends low byte of Stack Pointer    }
;
; 5.      MCU  sends lowest byte on stack
; 6.      Host acknowledges with any old byte
;
; 7.      Repeat steps 5 & 6 for a total of 9 times
;         Bytes are sent in this order: CCR
;                                       B
;                                       A
;                                       IXH
;                                       IXL
;                                       IYH
;                                       IYL
;                                       PCH
;                                       PCL
;
;-------------------------------------------------------------------------------
; Write MCU Registers
;-------------------------------------------------------------------------------
;
; 1.      Host sends $C1
; 2.      MCU replies with $3E
; 3.      Host sends high byte of Stack Pointer   } Note 2
; 4.      Host sends low byte of Stack Pointer    }
;
; 5.      Host sends lowest byte on stack
; 6.      MCU acknowledges by echoing same byte
;
; 7.      Repeat steps 5 & 6 for a total of 9 times
;         Bytes are sent in this order: CCR
;                                       B
;                                       A
;                                       IXH
;                                       IXL
;                                       IYH
;                                       IYL
;                                       PCH
;                                       PCL
;
;-------------------------------------------------------------------------------
; Software Interrupt
;-------------------------------------------------------------------------------
;
; When an SWI is encountered, the MCU transmits the character $4A (ASCII
; letter 'J'). This triggers JBug11 to make use of the following routine:
;
; SWI Service Routine
;
; 1.      Host sends $B5
; 2.      MCU replies with $4A
;
; 3.      MCU sends high byte of breakpoint address       } Note 3
; 4.      MCU sends low byte of breakpoint address        }
;
; 5.      MCU sends high byte of Stack Pointer            } Note 1
; 6.      MCU sends low byte of Stack Pointer             }
; 7.      MCU sends lowest byte on stack
; 8.      Host acknowledges by echoing any old byte
;
; 9.      Repeat steps 7 & 8 for a total of 9 times
;         Bytes are sent in this order: CCR
;                                       B
;                                       A
;                                       IXH
;                                       IXL
;                                       IYH
;                                       IYL
;                                       PCH     } Note 4
;                                       PCL     }
;
;-------------------------------------------------------------------------------
; NOTES
;-------------------------------------------------------------------------------
;
; 1     The MCU sends the actual value of the stack pointer plus 1
; 2     The host must send the desired value of the stack pointer plus 1
; 3     The MCU sends the actual value of the breakpoint plus 1
; 4     The value of PC returned by the SWI service routine is always the
;       address of SWIidle.
;
;*******************************************************************************
