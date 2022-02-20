; Archivo: Lab4_Contador.s
; Dispositivo: PIC16F887 
; Autor: Brandon Cruz
; Copilador: pic-as (v2.30), MPLABX v5.40
;
; Programa: Interrupciones 
; Hardware: LEDS en el puerto A y pushbuttons en el puerto B  
;
; Creado: 31 enero, 2022
; Última modificación: 3 enero, 2022
    
PROCESSOR 16F887
#include <xc.inc>

; CONFIGURACIÓN 1
  CONFIG  FOSC = INTRC_NOCLKOUT // Oscilador interno sin salidas
  CONFIG  WDTE = OFF            // WDT disabled (reinicio repetitivo del pic)
  CONFIG  PWRTE = ON            // PWRT enabled (reinicio repetitivo del pic)
  CONFIG  MCLRE = OFF           // El pin de MCLR se utiliza como I/O
  CONFIG  CP = OFF              // Sin protección de código
  CONFIG  CPD = OFF             // Sin protección de datos
  CONFIG  BOREN = OFF           // Sin reinicio cuando el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            // Reinicio sin cambio de reloj de interno a externo 
  CONFIG  FCMEN = OFF           // Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = ON              // Programación en bajo voltaje permitida

; CONFIGURACIÓN 2
  CONFIG  BOR4V = BOR40V        // Reinicio abajo de 4V, (BOR21V=2.1V)
  CONFIG  WRT = OFF             // Protección de autoescritura por el programa desactivado
  

;--------------Macros-------------------------;
reiniciar_tmr0 MACRO
    ;Para un incremento de cada 1000ms, seguir la siguiente fórmula
    ;Tosc=4uS
    ;Prescaler = 256
    ;Fosc = 250kHz
    ;0.1 = 4*0.000004*(256-tmr0)*256
    ;24 = (256-tmr0)
    ;tmr0=178
    banksel PORTD
    movlw 178    ; Es lo que necesita para tener un impremento de 1000ms
    movwf TMR0
    bcf T0IF    ; Se limpia la bandera
    ENDM

UP EQU 7
DOWN EQU 0
 
PSECT udata_bank0; common memory
    CONT: DS 2; 2 byte
    CONT1: DS 2
    PORT: DS 1
    PORT1: DS 1
    PORT2: DS 2
    PORT3: DS 1
    PORTC1: DS 1
    
PSECT udata_shr ; common memory
    W_TEMP: DS 1
    STATUS_TEMP: DS 1
    
    
PSECT resVect, class=CODE, abs, delta=2

;--------------Vector reset-------------------------;
ORG 00h ; posición 0000h para el reset

resetVec:
    PAGESEL main
    goto main

PSECT intVect, class=CODE, abs, delta=2

ORG 04h ; Posición para las interrupciones
 
;----------Configación de interrupciones-----------------;

push:
    movwf W_TEMP
    swapf STATUS, W
    movwf STATUS_TEMP
isr:
    btfsc T0IF
    call int_t0
    
    btfsc RBIF
    call int_iocb
       
pop:
    swapf STATUS_TEMP,W
    movwf STATUS
    swapf W_TEMP, F
    swapf W_TEMP, W
    retfie
    
;---------------Subrutinas de interripciones-----------
int_iocb:
    banksel PORTA
    btfss PORTB, UP
    incf PORT
    btfss PORTB, DOWN
    decf PORT
    movf PORT, W
    andlw 00001111B
    movwf PORTA
 
    bcf RBIF
    return

int_t0:
    reiniciar_tmr0
    incf CONT
    movf CONT,W
    sublw 50
    btfss ZERO
    goto RETURN_T0
    clrf CONT
    incf PORT1
    movf PORT1,W
    call Tabla
    movwf PORTD
    
    movf PORT1, W
    sublw 10
    btfsc STATUS, 2
    call Incremento
    
    movf PORT3,W
    call Tabla
    movwf PORTC
    
    return
    
Incremento:
    incf PORT3
    clrf PORT1
    movf PORT1,W
    call Tabla
    movwf PORTD
    
    movf PORT3, W
    sublw 6
    btfsc STATUS, 2
    clrf PORT3
    return

RETURN_T0:
    return
    
    
PSECT code, delta=2, abs
ORG 100h ; posición para el codigo

Tabla: 
    clrf PCLATH  ; El registro de PCLATH se coloca en 0
    bsf PCLATH, 0 ; El valor del PCLATH adquiere el valor 01
    andlw 0x0f ; Se restringe el valor máximo de la tabla
    addwf PCL ; PC=PCL+PLACTH+W
    retlw 00111111B ;0
    retlw 00000110B ;1
    retlw 01011011B ;2
    retlw 01001111B ;3
    retlw 01100110B ;4
    retlw 01101101B ;5
    retlw 01111101B ;6
    retlw 00000111B ;7
    retlw 01111111B ;8
    retlw 01101111B ;9
    retlw 01110111B ;A
    retlw 01111100B ;B
    retlw 00111001B ;C
    retlw 01011110B ;D
    retlw 01111001B ;E
    retlw 01110001B ;F
   
main:
    call config_io      ; se manda a llamar configuración de los pines
    call config_reloj   ;4 Mhz
    call config_tmr0
    call config_int_enable
    call config_iocrb    
    
;-----------------Loop principal----------------------;
loop:
    goto loop     ; loop por siempre


;-----------------Sub rutinas----------------------;
config_iocrb:
    banksel TRISA
    bsf IOCB, UP
    bsf IOCB, DOWN
    
    banksel PORTA
    movf PORTB, W   ; al leer termina la condición mismatch
    bcf RBIF
    return
    
config_tmr0:
    banksel TRISD
    bcf T0CS ; reloj interno - tmr0 como contador
    bcf PSA ; prescaler
    bsf PS2
    bsf PS1
    bsf PS0 ; PS=111 - 1:256
    reiniciar_tmr0
    return
    
config_int_enable:
    bsf GIE ; INTCON
    bsf T0IE
    bcf RBIE
    
    bsf T0IF
    bcf RBIF
    return
    
config_reloj:
    banksel OSCCON
    ;Oscilador de 4MHz (110)
    bsf IRCF2 ; OSCCON,6  
    bsf IRCF1 ; OSCCON,5
    bcf IRCF0 ; OSCCON,4   
    bsf SCS ; reloj interno
    return
    
config_io:
    bsf STATUS, 5 ; banco 11
    bsf STATUS, 6  
    clrf ANSEL    ; Pines digitales
    clrf ANSELH

    
    bsf STATUS, 5 ; banco 01
    bcf STATUS, 6  
    banksel TRISA
    movlw 0F0h
    movwf  TRISA
    clrf TRISC    ; PORT C como salida
    clrf TRISD    ; PORT D como salida
    
    bsf TRISB, UP
    bsf TRISB, DOWN
    
    bcf OPTION_REG, 7 ;habilitar pull-ups
    bsf WPUB, UP
    bsf WPUB, DOWN
    
    bcf STATUS, 5 ; banco 00
    bcf STATUS, 6 
    clrf PORTA
    clrf PORTC
    clrf PORTD
    return
    
    
END