;--------------------------------------------------------------------------
;
;                       Program SpecROM v.1.0
;
;    autor: Łukasz Bacik
:     data: 2001 rok.  
; asembler: 8051
;
;	     Program został umieszczony w pamięci ROM układu SPEC ( Sterownik
; Przepływu Energii Cieplnej ), będącego tematem pracy licencjackiej.
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
; Stałe
;--------------------------------------------------------------------------

DIODA1                  EQU     P1.1    ; Stałe, odnoszące sie do
PR_2                    EQU     P1.2    ; wyświetlacza LCD, zostały
PR_1                    EQU     P1.3    ; umieszczone w bloku
Klawisz_lewo            EQU     P1.4    ; funkcji obsługi wyswietlacza.
Klawisz_prawo           EQU     P1.5
Klawisz_czerwony        EQU     P1.6
Klawisz_niebieski       EQU     P1.7
DSPort                  EQU     P0

;--------------------------------------------------------------------------
; Aliasy
;--------------------------------------------------------------------------

Tryb                    EQU     2
DSwl                    EQU     3
oTemp                   EQU     4
aTemp                   EQU     5
sAl                     EQU     6
DSerr                   EQU     7
DSTemp                  EQU     8
Al                      EQU     0FH
TermBT                  EQU     12H
sTemp                   EQU     14H
MaskaDSbit              EQU     18H
CRC                     EQU     19H
Termometr               EQU     1AH
MaskaDSPort             EQU     1BH
Licznik                 EQU     1CH
Maska                   EQU     1DH
DSTH                    EQU     1EH
DSTL                    EQU     1FH
Flagi                   EQU     20H
Escape                  EQU     20H.0
Bufor                   EQU     21H

;--------------------------------------------------------------------------

                        LJMP    START
                        ORG     100H

;--------------------------------------------------------------------------
; Stałe tekstowe
;--------------------------------------------------------------------------

Kom_Zaznaczenie0:       DB      ' ',0,' ',0
Kom_Zaznaczenie1:       DB      126,0,127,0
Kom_DS_wyl:             DB      '><',0
Kom_DS_err1:            DB      '<>',0
Kom_DS_OK:              DB      '^ ',0
Kom_DS_Al:              DB      'v ',0
Kom_PustaLinia:         DB      '                        ',0
Kom_Gumka:              DB      '   ',0
Kom_DS_ON:              DB      'on ',0
Kom_DS_OFF:             DB      'off',0
Kom_Znak_Term:          DB      0A1H,0
Kom_Znak_Pola:          DB      '>',0
Kom_Pusty:              DB      ' ',0
Kom_rodzina:            DB      'R:',0
Kom_ID:                 DB      ' id:',0
Kom_error:              DB      'Error: ',0
Kom_SC:                 DB      ' ',0DFH,'C  ',0
Kom_BT:                 DB      '-- ',0
Cyfry_HEX:              DB      '0123456789ABCDEF'

;--------------------------------------------------------------------------
; INIT
;--------------------------------------------------------- Część inicjująca

START:        MOV      SP,#4FH          ; Stos ( max.wielkość 32 bajty )
              MOV      TMOD,#00000001B  ; Bajt konfigurujący dla Timer'ów
              CLR      EA               ; Blokuj wszystkie przerwania
              CLR      DIODA1           ; **************** stany lini I/O
              CLR      PR_1             ;
              CLR      PR_2             ;
              MOV      Tryb,#02H        ; ****************** INIT zmienne
              MOV      DSwl,#0FH        ; Wszystkie termometry włączone
              MOV      sAl,#0
              MOV      Flagi,#0
              MOV      DSerr,#0
              LCALL    Kasuj_sTemp
              MOV      R1,#8            ; Wypełnianie tablicy DSTemp
INIT0:        MOV      @R1,#0           ; domyślną wartością TNP ( 0 )
              INC      R1
              CJNE     R1,#0CH,INIT0
              LCALL    INIT_LCD         ; ******** Init wyświetlacz LCD
              MOV      A,#0CH           ; Wyłącz kursor
              LCALL    FUNKCJA_LCD
              MOV      Termometr,#0     ; ****** Inicjalizacja ustawień
INIT1:        LCALL    WlaczDS          ; termometrów - funkcja WlaczDS
              JZ       INIT11           ; określa min. wartości tablic:
              LCALL    ERROR            ; sTemp, TermBT, Al, DSerr
INIT11:       INC      Termometr
              MOV      A,Termometr
              CJNE     A,#4,INIT1
              MOV      Termometr,#0     ; ******************************
              MOV      A,#20
              MOV      B,#1
              LCALL    GOTOXY_LCD
              MOV      DPTR,#Kom_SC
              LCALL    CIAG_ROM_NA_LCD  ; wypisz znak "stopni Celcjusza"

;--------------------------------------------------------------------------
; RUN
;--------------------------------------------------  ####################
                                                  ;  #                  #
Petla_glowna:                                     ;  #   PĘTLA GŁÓWNA   #
                                                  ;  #                  #
        JNB      Klawisz_czerwony, Obsluga_kl_c   ;  #                  #
        JNB      Klawisz_niebieski, Obsluga_kl_n  ;  #                  #
        JNB      Klawisz_lewo, Obsluga_kl_l       ;  #        W         #
        JNB      Klawisz_prawo, Obsluga_kl_p      ;  #                  #
pg_k:   LCALL    Uaktualniaj                      ;  #                  #
        SJMP     Petla_glowna                     ;  #  NIESKOŃCZONOŚĆ  #
                                                  ;  #                  #
;--------------------------------------------------  ####################
; Koniec programu głównego
;--------------------------------------------------------------------------
; *--------------------*
; |  Klawisz czerwony  |___________________________________________________

Obsluga_kl_c:   MOV     A,Tryb             ;   Zmiana trybu pracy programu
                CJNE    A,#1,OKC_T2W       ;
                SJMP    OKC_T2             ;
OKC_T2W:        CJNE    A,#2,OKC_T3        ;   aktualny TRYB    nowy TRYB
OKC_T2:         MOV     A,#3               ;
                LCALL   ZmienTryb          ;             1  ->   3
                SJMP    OKC_END            ;             2  ->   3
OKC_T3:         CJNE    A,#3,OKC_T456      ;             3  ->   2
OKC_T31:        MOV     A,#2               ;             4  ->   3  ( Esc )
                LCALL   ZmienTryb          ;             6  ->   3  ( Esc )
                SJMP    OKC_END            ;
OKC_T456:       SETB    Escape             ;Esc - jeżeli termometr jest wł.
                SJMP    OKC_T2             ;to do DSTemp[Termometr] będzie
OKC_END:        SJMP    pg_k               ;skopiowana wartość z pamięci
                                           ;SCRATCHPAD układu DS 1820
; *---------------------*
; |  Klawisz niebieski  |__________________________________________________

Obsluga_kl_n:   MOV      A,Tryb        ; Zmiana trybu pracy programu
                CJNE     A,#2,OKN_T6   ; akt. TRYB     nowy TRYB
                SJMP     OKN_T62       ;       1    ->      2  ( inc Tryb )
OKN_T6:         CJNE     A,#6,OKN_T4   ;       2    ->      1  ( RR  Tryb )
OKN_T62:        RR       A             ;       3    ->      4  ( inc Tryb )
                LCALL    ZmienTryb     ;       4    ->      6  ( Tryb =+2 )
                SJMP     OKN_END       ;       6    ->      3* ( RR  Tryb )
OKN_T4:         CJNE     A,#4,OKN_T13  ;
                INC      A             ;   * dane z DSTemp[ Termometr ]
OKN_T13:        INC      A             ; zostaną zapisane w pamięci EEPROM
                LCALL    ZmienTryb     ; układu DS1 820
OKN_END:        SJMP     pg_k          ;

; *---------------------*  Strzałki służą do zmiany, edytowanych w trybach
; |  Klawisz lewo       |  4 i 6, zmiennych oraz do wyboru termometru
; *---------------------*  w trybach 1 i 3.
; |  Klawisz prawo      |__________________________________________________

Obsluga_kl_l:   MOV     B,#0             ; Parametr dla podprocedur
Ob_kl_p:        MOV     DPTR,#JMPTAB1    ;#
                MOV     A,Tryb           ;#
                MOVC    A,@A+DPTR        ;#     SWITCH ( Tryb ) of ...
                MOV     DPTR,#kl_l_d1    ;#
                JMP     @A+DPTR          ;#
kl_l_d1:        LCALL   ZmienNrDS        ;  -----------------------------
                LCALL   WypiszID         ;             Tryb 1
                SJMP    kl_l_end         ;  -----------------------------
kl_l_d3:        LCALL   ZmienNrDS        ;  -----------------------------
                LCALL   WypiszSzczegoly0 ;             Tryb 3
                SJMP    kl_l_end         ;  -----------------------------
kl_l_d4:        LCALL   ZmienDSTemp      ;  -----------------------------
                LCALL   WypiszSzczegoly1 ;             Tryb 4
                SJMP    kl_l_end         ;  -----------------------------
kl_l_d6:        LCALL   ZmienDSwl        ;  -----------------------------
                LCALL   WypiszSzczegoly3 ;             Tryb 6
kl_l_end:       LJMP    pg_k             ;  -----------------------------

Obsluga_kl_p:   MOV     B,#1             ;  Parametr dla podprocedur
                SJMP    Ob_kl_p          ;      skok do SWITCH'a
JMPTAB1:        DB      0                ;---------------------------------
                DB      0                ;
                DB      kl_l_end-kl_l_d1 ;   Tablica długości skoków
                DB      kl_l_d3-kl_l_d1  ;   dla "instrukcji SWITCH".
                DB      kl_l_d4-kl_l_d1  ;
                DB      kl_l_end-kl_l_d1 ;
                DB      kl_l_d6-kl_l_d1  ;---------------------------------
;--------------------------------------------------------------------------
; ZmienTryb
;               We: rejestr A - nowy tryb
;               Wy: brak
;--------------------------------------------------------------------------
ZmienTryb:      PUSH    ACC				  ;Przyda się na końcu
                MOV     DPTR,#JMPTBL0     ;#
                MOVC    A,@A+DPTR         ;#
                MOV     DPTR,#ZT_NT1      ;# SWITCH( A ) of ...
                JMP     @A+DPTR           ;#
ZT_NT1:         LCALL   Zaznacz1          ; -----
                LCALL   WypiszID          ;|  1  |
                SJMP    ZT_END            ; ------------------------- BREAK
ZT_NT2:         LCALL   MazDolnaLinie     ; -----
                LCALL   Zaznacz0          ;|     |Maż zaznaczenie
                LCALL   Kasuj_sTemp       ;|     |Czyść tablicę sTemp
                MOV     A,#20             ;|     |
                MOV     B,#1              ;|  2  |
                LCALL   GOTOXY_LCD        ;|     |
                MOV     DPTR,#Kom_SC      ;|     |
                LCALL   CIAG_ROM_NA_LCD   ;|     |Wypisz: 'C
                SJMP    ZT_END            ; ------------------------- BREAK
ZT_NT3:         MOV     A,Tryb            ; -----
                ANL     A,#4              ;|     |
                JNZ     ___NT3_T456       ;|     |if Tryb >= 4 to skok
                LCALL   MazDolnaLinie     ;|     |
                LCALL   WypiszSzczegoly0  ;|     |Wypisz wszystkie
                LCALL   Zaznacz1          ;|     |Pokaż zaznaczenie
                SJMP    ZT_END            ;|     |------------------------- 
___NT3_T456:    POP     ACC               ;|     |
                PUSH    ACC               ;|     |W A - nowy Tryb
                LCALL   ZaznaczPole       ;|     |Zaznacz edytowane pole
                LCALL   Uaktualnij_L1     ;|  3  |wynik fun. w A
                JZ      ___NT3_END2       ;|     |A = 1 if Termometr ON
                JB      Escape,___NT3_ESC ;|     |
                LCALL   WyslijDaneDoDS    ;|     |
                JZ      ___NT3_END		  ;|	 |
___NT3_ERR:     LCALL   ERROR			  ;|	 |
                SJMP    ___NT3_END2       ;|     |-------------------------
___NT3_ESC:     LCALL   PobierzDaneOdDS   ;|     |
                JNZ     ___NT3_ERR		  ;|	 |
                LCALL   WypiszSzczegoly0  ;|     |Wypisz wszystkie
___NT3_END:     MOV     A,MaskaDSPort     ;|     |#
                ANL     sAl,A             ;|     |# sAl[ Termometr ] = 0
___NT3_END2:    CLR     Escape			  ;|	 |
                SJMP    ZT_END            ; ------------------------- BREAK
ZT_NT4:                                   ; -----
ZT_NT6:         POP     ACC               ;| 4,6 |
                PUSH    ACC               ;|     |
                LCALL   ZaznaczPole       ; -----
ZT_END:         POP     ACC               ;================================
                MOV     Tryb,A            ;  Tryb = nowy Tryb ( rej A )
                RET                       ;

JMPTBL0:        DB      0                 ;--------------------------------
                DB      ZT_NT1-ZT_NT1     ;
                DB      ZT_NT2-ZT_NT1     ;    Tablica długości skoków
                DB      ZT_NT3-ZT_NT1     ;    dla "instrukcji" SWITCH
                DB      ZT_NT4-ZT_NT1     ;
                DB      0                 ;<- tryb niewykorzystywany
                DB      ZT_NT6-ZT_NT1     ;--------------------------------
;--------------------------------------------------------------------------
; ZmienNrDS
;               We: rej. B = 0 - zmniejsz o jeden
;                          = 1 - zwiększ  o jeden
;               Wy: brak
;--------------------------------------------------------------------------
ZmienNrDS:      PUSH     B
                LCALL    Zaznacz0         ; kasuj zaznaczenie( na LCD )
                POP      ACC
                JZ       ZnD_o            ; w A parametr wywołania(0 lub 1)
                INC      Termometr        ;
                SJMP     ZnD_spr          ;
ZnD_o:          DEC      Termometr        ;
ZnD_spr:        ANL      Termometr,#03H   ; zakres zmiennej to [ 0,3 ]
ZnD_k:          LCALL    Zaznacz1         ; pokaż zaznaczenie( na LCD )
                RET

;--------------------------------------------------------------------------
; ZmienDSTemp   ( dokładniej DSTemp[ Termometr ] )
;               We: rej. B = 0 - zmniejsz o jeden
;                          = 1 - zwiększ  o jeden
;               Wy: brak
;--------------------------------------------------------------------------
ZmienDSTemp:    MOV      A,#DSTemp        ; adres początku tablicy DSTemp
                ADD      A,Termometr      ;
                MOV      R1,A             ; R1 = adres DSTemp[ Termometr ]
                MOV      A,B              ; B - parametr wywołania
                JZ       ZDT_o
                CJNE     @R1,#7DH,ZDT_d0  ; 7Dh = 125d
                SJMP     ZDT_k
ZDT_d0:         INC      @R1
                SJMP     ZDT_k
ZDT_o:          CJNE     @R1,#0C9H,ZDT_d1 ; 0C9h = -55
                SJMP     ZDT_k
ZDT_d1:         DEC      @R1
ZDT_k:          RET

;--------------------------------------------------------------------------
; ZmienDSwl
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
ZmienDSwl:      MOV     R1,Termometr
                LCALL   ObliczMaske
                XRL     DSwl,A            ; zmień stan bitu DSwl.Termometr
                RET

;--------------------------------------------------------------------------
; Uaktualnij_L1
;               We: brak
;               Wy: rej. A = Dswl[ Termometr ]
;--------------------------------------------------------------------------
Uaktualnij_L1:  MOV     R1,Termometr      ; Funkcja wypisuje na wyś.LCD
                LCALL   ObliczMaske       ; ciąg Kom_DS_OK lub Kom_DS_wyl
                ANL     A,DSwl            ; w zależności od stanu bitu
                PUSH    ACC               ; DSwl.Termometr ("0" oznacza, że
                JZ      UL1_DSoff         ; dany termometr został wyłączony
                MOV     DPTR,#Kom_DS_OK   ; przez użytkownika ).
                SJMP    UL1_END
UL1_DSoff:      MOV     DPTR,#Kom_DS_wyl
UL1_END:        LCALL   PiszL1
                POP     ACC
                RET
;--------------------------------------------------------------------------
; Uaktualnij_L1a
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
Uaktualnij_L1a: MOV     A,Maska           ; Procedura porównuje bity zm.Al
                ANL     A,Al              ; i zm.sAl dla aktualnej wartości
                JZ      UL1a_P0           ; zm. Maska.
                ANL     A,sAl             ; Jeżeli wartości bitów są różne
                JZ      UL1a_P1           ; to następuje ustawienie bitu
                SJMP    UL1a_END          ; zm. sAl wg bitu zm. Al oraz
UL1a_P0:        MOV     A,Maska           ; wg wartości bitu zm. Al zostaje
                ANL     A,sAl             ; wypisany na wyś. LCD komunikat:
                JZ      UL1a_END          ;   dla bitu = 0 - Kom_DS_OK,
                CPL     A                 ;     a dla bitu = 1 - Kom_DS_Al.
                ANL     sAl,A
                MOV     DPTR,#Kom_DS_OK
                LCALL   PiszL1
                SJMP    UL1a_END
UL1a_P1:        MOV     A,Maska
                ORL     sAl,A
                MOV     DPTR,#Kom_DS_Al
                LCALL   PiszL1
UL1a_END:       RET

;--------------------------------------------------------------------------
; WypiszSzczegóły0/1/3
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
WypiszSzczegoly0: LCALL   WypiszSzczegoly1 ; Procedura posiada trzy wejścia
WypiszSzczegoly3: MOV     R1,Termometr     ; 1. We."0" - Wypisz wszystkie
                  LCALL   ObliczMaske      ;                     szczegóły
                  ANL     A,DSwl           ; 2. We."1" - Wypisz tylko TNP
                  JZ      WS3_off          ;
                  MOV     DPTR,#Kom_DS_ON  ; 3. We."3" - Wypisz tylko stan
                  SJMP    WS3_p            ;             ON/OFF termometru
WS3_off:          MOV     DPTR,#Kom_DS_OFF ;
WS3_p:            MOV     A,#0CH           ; Temperatura przed wypisaniem
                  MOV     B,#01H           ; na wyświetlacz LCD zostaje
                  LCALL   GOTOXY_LCD       ; zamieniona na liczbę w sys.
                  LCALL   CIAG_ROM_NA_LCD  ; dziesiętnym ze znakiem
                  RET                      ; ( SCHAR_TO_DEC ).
				  ;========================; ==============================
WypiszSzczegoly1: MOV     A,#DSTemp        ;
                  ADD     A,Termometr      ; Wszystkie "szczegóły" są
                  MOV     R1,A             ; wypisywane wg stałych współ-
                  MOV     A,@R1            ; rzędnych.
                  MOV     R1,#Bufor        ;
                  LCALL   SCHAR_TO_DEC     ;
                  MOV     A,#2             ;
                  MOV     B,#1             ;
                  LCALL   GOTOXY_LCD       ;
                  MOV     R0,#Bufor        ;
                  LCALL   CIAG_RAM_NA_LCD  ;
                  MOV     DPTR,#Kom_SC     ;
                  LCALL   CIAG_ROM_NA_LCD  ;
WS_P_END:         RET                      ;
;--------------------------------------------------------------------------
; Uaktualniaj
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
Uaktualniaj:    MOV      A,Tryb           ; Procedura wykonuje się tylko
                CJNE     A,#2,U_END       ; w Trybie drugim.
                MOV      R1,Termometr     ; Jednorazowo pobierana jest
                LCALL    ObliczMaske      ; temperatura od tylko jednego
                MOV      Maska,A          ; termometru - czas wykonania
                ANL      A,DSwl           ; f. DS_CONVERT_TEMPERATURE
                JZ       U_BT             ; wynosi ponad 0.5s, co dla
                MOV      A,Maska          ; 4 termpmetrów dawało by ponad
                ANL      A,DSerr          ; 2 sekundy, a to powodowało by
                JNZ      U_WlDS           ; "oporną" pracę klawiatury.
U_P01:          LCALL    UaktualnijTemperature
                JNZ      U_ERR            ; Dla termometrów wyłączonych,
                LCALL    SprAlarm         ; lub "z błędem" w dolnej lini
                LCALL    Uaktualnij_L1a   ; LCD wypisywany jest ciąg "--"
U_P0:           LCALL    UstawPrzekaz     ; Dla termometrów włączonych,
                INC      Termometr        ; sygnalizujących błąd w ko-
                ANL      Termometr,#3     ; munikacji, podejmowana jest
U_END:          RET                       ; próba ich "inicjacji".
				;=========================; ===============================
U_BT:           MOV      A,Maska
                ANL      A,TermBT
                JNZ      U_P0
                MOV      A,Termometr      ; Dla termometrów włączonych,
                MOV      B,#5             ; działających bez błędu, lub
                MUL      AB               ; tych, których "inicjacja"
                ADD      A,#2             ; zakończyła się sukcesem
                MOV      B,#1             ; wykonywane są następujące
                LCALL    GOTOXY_LCD       ; czynności :
                MOV      DPTR,#Kom_BT     ; - pobierana jest temperatura
                LCALL    CIAG_ROM_NA_LCD  ; - sprawdzany jest stan ALARM
                MOV      A,Maska
                ORL      TermBT,A
                SJMP     U_P0             ; - uaktualniana linia 1 LCD
U_WlDS:         LCALL    WlaczDS          ;
                JZ       U_P01            ; Na końcu inkrementowana jest
U_ERR:          LCALL    ERROR            ; wartość zmiennej Termometr,
                SJMP     U_BT             ; oraz ustawiane są
                                                                                    ; przerzutniki.
;--------------------------------------------------------------------------
; UaktualniajTemperatury
;               We: brak
;               Wy: rejestr A - Kod wyjścia
;--------------------------------------------------------------------------
UaktualnijTemperature: 
				LCALL  WypiszZnakTermometru1 ; Funkcja pobiera temperaturę
                LCALL  PobierzTemperature ; od termometru, którego numer
                JNZ    UT_END             ; znajduje się w zmiennej
                MOV    A,#sTemp           ; Termometr. Temperatura(aTemp)
                ADD    A,Termometr        ; jest porównywna z wartością w
                MOV    R1,A               ; tablicy sTemp i w przypadku
                MOV    A,@R1              ; różnicy :
                CJNE   A,aTemp,UT_P2      ; sTemp[ termometr ] := aTemp,
                SJMP   UT_P3              ; oraz: wypisz aTemp na LCD
UT_P2:          MOV    @R1,aTemp          ;
                LCALL  WypiszTemperature  ; Funkcja "zaznacza" również
UT_P3:          MOV    A,#0               ; na LCD dla którego termometru
UT_END:         PUSH   ACC                ; jest aktualnie wykonywana.
                LCALL  WypiszZnakTermometru0; Wartość zwracana(Kod wyjścia)
                POP    ACC                ; jest opisana niżej, w części:
                RET                       ; "Blok kom. z Termometrami"
;--------------------------------------------------------------------------
; WypiszTemperature
;               We : brak
;               Wy : brak
;--------------------------------------------------------------------------
WypiszTemperature:
                MOV    A,aTemp            ; Zamienia bajt aTemp na
                MOV    R1,#Bufor          ; na liczbę dziesiętną ze
                LCALL  SCHAR_TO_DEC       ; znakiem ( funkcja :
                MOV    R0,#Bufor          ; SCHAR_TO_DEC ) oraz
                LCALL  CIAG_RAM_NA_LCD    ; wypisuje na LCD.
                MOV    A,#' '
                LCALL  ZNAK_NA_LCD
                RET

;--------------------------------------------------------------------------
; WypiszZnakTermometru0/1
;               We : brak
;               Wy : brak
;--------------------------------------------------------------------------
WypiszZnakTermometru0: MOV    DPTR,#Kom_Pusty ; Mazanie zaznaczenia
WZT_p0:         MOV    A,Termometr            ; termometru w dolnej lini
                MOV    B,#5					  ; wyświetlacza LCD.
                MUL    AB
                ADD    A,#0
                MOV    B,#1
                LCALL  GOTOXY_LCD
                LCALL  CIAG_ROM_NA_LCD
                RET

WypiszZnakTermometru1: MOV    DPTR,#Kom_Znak_Term 
                SJMP   WZT_p0  

;--------------------------------------------------------------------------
; UstawPrzekaz
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
UstawPrzekaz:      MOV     A,Al           ; Procedura ustawia
                   ANL     A,#0FH         ; przerzutniki na podstawie
                   JZ      UP_off         ; wartości bitów zmiennej Al.
                   SETB    PR_1           ;
                   SETB    DIODA1         ; Ustawiony bit (którykolwiek)
                   MOV     A,Al           ; młodszej połówki bajtu jest
                   ANL     A,#0F0H        ; interpretowany jako rozkaz
                   JZ      UP_off2        ; ustawienia przerzutnika 1.
                   SETB    PR_2           ;
                   SJMP    UP_END         ; Górna połówka bajtu Al odnosi
UP_off:            CLR     PR_1           ; się do przerzutnika nr 2.
                   CLR     DIODA1         ;
UP_off2:           CLR     PR_2
UP_END:            RET

;--------------------------------------------------------------------------
; SprAlarm
;                  We: brak
;                  Wy: brak
;--------------------------------------------------------------------------
SprAlarm:       MOV     B,oTemp           ; oTemp - aktualna temperatura
                MOV     A,#DSTemp         ; *       połówkowo.
                ADD     A,Termometr       ; |      temperatura ustawiona
                MOV     R1,A              ; |      przez użytkownika
                MOV     A,@R1             ; *-> do A
                RLC     A                 ; A * 2 = temp. user połówkowo
                XCH     A,B               ; w F0 znak aktualnej temp.
                JC      SA_AU             ; w C znak temp. użytkownika
                JB      F0,SA_RZ          ; if "+" i "-" to skok
                SJMP    SA_P0             ; if dwa razy "+" to skok
SA_AU:          JB      F0,SA_P0          ; if dwa razy "-" to skok
                SJMP    SA_NA             ; if "-" i "+" to wył. ALARM
SA_P0:          CLR     C                 ; *    jeżeli aktualna temp. jest
                SUBB    A,B               ; |    mniejsza od temp. user
                JC      SA_PR1on          ; *->  to włącz przerzutnik 1
                SJMP    SA_NA             ; w przeciwnym razie wył. ALARM
SA_RZ:          ADD     A,B               ; w A różnica
SA_PR1on:       PUSH    ACC               ; róznica na stos
                MOV     A,Maska           ; *
                ORL     Al,A              ; *-> zapal bit w dolnej
                RL      A                 ; |       połówce
                RL      A                 ; |
                RL      A                 ; |
                RL      A                 ; |
                CPL     A                 ; |
                ANL     Al,A              ; *-> zgaś bit w połówce górnej
                POP     ACC               ; różnica do A
                CLR     C                 ; *
                MOV     B,#0FDH           ; |
                SUBB    A,B               ; |
                JNC     SA_END            ; *-> if różnica < 2 to koniec
                MOV     A,Maska           ; *       dla różnicy >= 2
                RL      A                 ; |
                RL      A                 ; |
                RL      A                 ; |
                RL      A                 ; |       zapal bit w górnej
                ORL     Al,A              ; *-> połówce bajtu Al
                SJMP    SA_END
SA_NA:          MOV     A,Maska           ; *      wyłącz ALARM dla tego
                CPL     A                 ; |      termometru
                ANL     Al,A              ; *-> zgaś bit w dolnej
                RL      A                 ; |       połówce
                RL      A                 ; |
                RL      A                 ; |
                RL      A                 ; |
                ANL     Al,A              ; *-> zgaś bit w górnej połówce
SA_END:         RET

;--------------------------------------------------------------------------
; Zaznacz0/1
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
Zaznacz0:       MOV     DPTR,#Kom_Zaznaczenie0 ; Procedura maże lub rysuje
                SJMP    Zaz_d0                 ; zaznaczenie termometru
Zaznacz1:       MOV     DPTR,#Kom_Zaznaczenie1 ; w lini górnej wyś. LCD.
Zaz_d0:         MOV     A,Termometr     ; x = ( Termometr * 5 ) + 1
                MOV     B,#05H          ;
                MUL     AB              ;
                ADD     A,#01H
                PUSH    ACC             ; przyda się dalej
                MOV     B,#00H          ; y = 0
                LCALL   GOTOXY_LCD
                LCALL   CIAG_ROM_NA_LCD
                POP     ACC             ; A = ( Termometr * 5 ) + 1
                ADD     A,#03H          ; x = A + 2
                MOV     B,#00H          ; y = 0
                LCALL   GOTOXY_LCD
                INC     DPTR
                LCALL   CIAG_ROM_NA_LCD
                RET
;--------------------------------------------------------------------------
; ZaznaczPole
;               We: rej. A - Tryb ( 3,4,6 )
;               Wy: brak
;--------------------------------------------------------------------------
ZaznaczPole:    CJNE    A,#3,ZP_4       ;|Tryb|
                LCALL   ZP_10           ;   3  Maż zaznaczenie przy polu 1
                LCALL   ZP_20           ;                  -"-                        2
                SJMP    ZP_END          ;
ZP_4:           CJNE    A,#4,ZP_6       ;
                LCALL   ZP_11           ;   4  Zaznacz pole 1
                LCALL   ZP_20           ;      Maż zaznaczenie przy polu 2
                SJMP    ZP_END          ;
ZP_6:           LCALL   ZP_10           ;   6  Maż zaznaczenie przy polu 1
                LCALL   ZP_21           ;      Zaznacz pole 2
ZP_END:         RET		;===============; =================================
ZP_10:          MOV     A,#0             
                MOV     B,#1            ;----------------------------------
                LCALL   GOTOXY_LCD      ;  Procedura rysuje zaznaczenie
                MOV     A,#' '          ; przy edytowanym, w linii dolnej
                LCALL   ZNAK_NA_LCD     ; wyświetlacza LCD polu.
                RET                     ;----------------------------------
ZP_11:          MOV     A,#0
                MOV     B,#1
                LCALL   GOTOXY_LCD
                MOV     DPTR,#Kom_Znak_Pola
                LCALL   CIAG_ROM_NA_LCD
                RET
ZP_20:          MOV     A,#10
                MOV     B,#1
                LCALL   GOTOXY_LCD
                MOV     A,#' '
                LCALL   ZNAK_NA_LCD
                RET
ZP_21:          MOV     A,#10
                MOV     B,#1
                LCALL   GOTOXY_LCD
                MOV     DPTR,#Kom_Znak_Pola
                LCALL   CIAG_ROM_NA_LCD
                RET

;--------------------------------------------------------------------------
; MazDolnaLinie
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
MazDolnaLinie:  MOV     A,#00H
                MOV     B,#01H
                LCALL   GOTOXY_LCD
                MOV     DPTR,#Kom_PustaLinia
                LCALL   CIAG_ROM_NA_LCD
                RET

;--------------------------------------------------------------------------
; ObliczMaske
;               We : rejestr R1 - indeks
;               Wy : rejestr  A - obliczona Maska
;--------------------------------------------------------------------------
ObliczMaske:    MOV     A,#1            ; funkcja wykorzystywana do
OM_P0:          CJNE    R1,#0,OM_P1     ; obliczenia maski bitowej
                RET                     ; wg wartości przekazanej 
OM_P1:          RL      A				; w rej. R1
                DEC     R1
                SJMP    OM_P0
;--------------------------------------------------------------------------
; ObliczMaskeP
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
ObliczMaskaP:   MOV     R1,Termometr    ; Funkcja oblicza maskę bitową
                LCALL   ObliczMaske     ; wg wartości zm. Termometr,
                MOV     Maska,A         ; i umieszcza ją w zm. Maska.
                CPL     A               ; Zanegowana maska bitowa jest
                MOV     MaskaDSPort,A   ; kopiowana do zm. MaskaDSPort.
                RET

;--------------------------------------------------------------------------
; PISZ_L1
;
;       We : rejestr DPTR  - początek ciągu zakończonego zerem.
;       Wy : brak.
;--------------------------------------------------------------------------
PiszL1:         MOV     B,Termometr     ; Procedura wypisuje w pierwszej
                MOV     A,#5            ; linii wyświetlacza ciąg
                MUL     AB              ; zakończony zerem którego adres
                ADD     A,#2            ; jest przekazany w DPTR ( ciąg
                MOV     B,#0            ; musi być umieszczony w ROM'ie )
                LCALL   GOTOXY_LCD      ; Wsp. x jest liczona wg wzoru:
                LCALL   CIAG_ROM_NA_LCD ; x = ( Termometr * 5 ) + 2.
                RET

;--------------------------------------------------------------------------
; Kasuj_sTemp
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
Kasuj_sTemp:    MOV     R1,#sTemp       ; Procedura wypełnia tablicę sTemp
                MOV     R0,#4           ; wartościami spoza przedziału
K_P0:           MOV     @R1,#07FH       ; możliwych temperatur.
                INC     R1              ; zakres DS1820 [ -50,125 ]
                DJNZ    R0,K_P0         ;           7FH = 127
                MOV     TermBT,#0
                RET

;--------------------------------------------------------------------------
; Kasuj_Alarm
;               We: brak
;               Wy: brak
;--------------------------------------------------------------------------
Kasuj_Alarm:    MOV     A,Maska
                CPL     A
                ANL     sAl,A
                ANL     Al,A
                RL      A
                RL      A
                RL      A
                RL      A
                ANL     Al,A
                RET

;--------------------------------------------------------------------------
; SCHAR_TO_DEC
;               We: R1    - adres bufora na dane wyjsciowe
;                   rej.A - liczba do zamiany
;               Wy: dane w buforze
;--------------------------------------------------------------------------
SCHAR_TO_DEC:   JB      ACC.7,SC_ZU2
                MOV     @R1,#' '
                INC     R1
SC_ZN:          MOV     B,#0FFH
                PUSH    B
SC_P0:          MOV     B,#10
                DIV     AB
                PUSH    B
                CJNE    A,#0,SC_P0
SC_P1:          POP     ACC
                CJNE    A,#0FFH,SC_P2
                SJMP    SC_P3
SC_P2:          ADD     A,#30H
                MOV     @R1,A
                INC     R1
                SJMP    SC_P1
SC_P3:          MOV     @R1,#0
                RET		;===============;
SC_ZU2:         MOV     @R1,#'-'
                INC     R1
                CPL     A
                ADD     A,#1
                SJMP    SC_ZN

;--------------------------------------------------------------------------
; BYTE_TO_HEX
;               We: rej. A - bajt do zamiany
;                       R0 - początek bufora na dane wyjściowe. Po zapisa-
;                            niu danych, procedura dopisze jeszcze #0.
;               Wy: dane w buforze
;--------------------------------------------------------------------------
BYTE_TO_HEX:    PUSH    ACC
                RL      A
                RL      A
                RL      A
                RL      A
                ANL     A,#0FH
                MOV     DPTR,#Cyfry_HEX
                MOVC    A,@A+DPTR
                MOV     @R0,A
                INC     R0
                POP     ACC
                ANL     A,#0FH
                MOVC    A,@A+DPTR
                MOV     @R0,A
                INC     R0
                MOV     @R0,#0
                RET

;--------------------------------------------------------------------------
; ERROR
;               We : rejestr A - kod błędu
;               Wy : brak
;--------------------------------------------------------------------------
ERROR:          MOV     A,Maska
                ANL     A,DSerr
                JNZ     ERROR_END
                MOV     A,Maska
                ORL     DSerr,A
                LCALL   Kasuj_Alarm
                MOV     DPTR,#Kom_DS_err1
                LCALL   PiszL1
ERROR_END:      RET

;--------------------------------------------------------------------------
; WypiszID
;               We:
;               Wy:
;--------------------------------------------------------------------------
WypiszID:       LCALL   MazDolnaLinie
                LCALL   ObliczMaskaP
                LCALL   DS_ID
                JNZ     WID_ERR
                MOV     A,#0
                MOV     B,#1
                LCALL   GOTOXY_LCD
                MOV     DPTR,#Kom_rodzina
                LCALL   CIAG_ROM_NA_LCD
                MOV     A,Bufor
                MOV     R0,#Bufor+9
                LCALL   BYTE_TO_HEX
                MOV     R0,#Bufor+9
                LCALL   CIAG_RAM_NA_LCD
                MOV     DPTR,#Kom_ID
                LCALL   CIAG_ROM_NA_LCD
                MOV     R1,#Bufor+6
WID_P1:         MOV     A,@R1
                MOV     R0,#Bufor+9
                LCALL   BYTE_TO_HEX
                MOV     R0,#Bufor+9
                LCALL   CIAG_RAM_NA_LCD
                DEC     R1
                MOV     A,R1
                CLR     C
                SUBB    A,#Bufor
                JNZ     WID_P1
                RET
WID_ERR:        PUSH    ACC
                MOV     A,#0
                MOV     B,#1
                LCALL   GOTOXY_LCD
                MOV     DPTR,#Kom_error
                LCALL   CIAG_ROM_NA_LCD
                POP     ACC
                ADD     A,#30H
                LCALL   ZNAK_NA_LCD
                RET

;--------------------------------------------------------------------------
;
;                       BLOK KOMUNIKACJI Z TERMOMETRAMI
;
;--------------------------------------------------------------------------
;
;     KOD WJŚCIA - jest to wartość zwracana w rejestrze A przez każdą
;                  funkcję komunikującą się z układami DS 1820.
;
;     wartość    znaczenie
;
;        0       Wszystko OK - komunikacja przebiegła prawidłowo.
;        1       Błąd CRC.
;        2       Błąd funkcji DS_RST ( Reset and Presence Pulses )
;                - układ DS nie odpowiada ( brak sygnału Presence ).
;        3       Błąd funkcji DS_RST - sygnał Presence zbyt długi.
;        4       Błąd funkcji DS_RST - sygnał Presence zbyt krótki.
;        5       Błąd funkcji DS_BUSY - przekroczony czas oczekiwania.
;        9       Błąd funkcji DS_WRITE_EE - nieprawidłowe dane
;                w pamięci SCRATCHPAD.
;
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
; WlaczDS
;               We: brak.
;               Wy: rej. A - Kod wyjścia
;--------------------------------------------------------------------------
WlaczDS:        LCALL   ObliczMaskaP    ; Niezbędne
                LCALL   DS_RECALL_EE    ; Kopiuj E^2 do SCRATCHPAD'a
                JNZ     WlDS_ERR
                LCALL   PobierzDaneOdDS ; ustaw DSTemp[ Termometr ]
                JNZ     WlDS_ERR
                MOV     A,#sTemp        ; sTemp[ Termometr ] = 7FH
                ADD     A,Termometr     ;
                MOV     R1,A            ;
                MOV     @R1,#7FH        ;
                MOV     A,MaskaDSPort
                ANL     TermBT,A
                ANL     DSerr,A
                LCALL   Kasuj_Alarm
                LCALL   Uaktualnij_L1
                MOV     A,#0
WlDS_ERR:       RET

;--------------------------------------------------------------------------
; PobierzDaneOdDS
;
;               We : zm. BUFOR - adres początku bufora na dane
;               Wy : rej. A    - Kod wyjścia
;--------------------------------------------------------------------------
PobierzDaneOdDS:LCALL   ObliczMaskaP
                LCALL   DS_READ_SCRATCHPAD
                JNZ     PD_ERR
                MOV     A,#DSTemp       ; DSTemp[ Termometr ] =
                ADD     A,Termometr     ;    = Bufor[ 3 ]
                MOV     R1,A
                MOV     A,Bufor+3
                MOV     @R1,A
                MOV     A,#0
PD_ERR:         RET

;--------------------------------------------------------------------------
; PobierzTemperature
;
;               We : brak
;               Wy : rejestr A - kod wyjścia, 
;                    jeżeli równy zero to :
;                    1. zm. oTemp - odczytana temperatura ( połówkowo )
;                    2. flaga F0  - znak odczytanej temperatury ( oTemp )
;                    3. zm. aTemp - odczytana temperatura
;--------------------------------------------------------------------------
PobierzTemperature:     LCALL   ObliczMaskaP
                LCALL   DS_CONVERT_TEMPERATURE
                JNZ     PT_ERR
                LCALL   DS_READ_SCRATCHPAD
                JNZ     PT_ERR
                MOV     A,Bufor+1       ; znak
                RRC     A
                MOV     F0,C
                MOV     A,Bufor         ; temperatura ( połówkowo )
                MOV     oTemp,A
                RRC     A
                MOV     aTemp,A
                MOV     A,#0
PT_ERR:         RET

;--------------------------------------------------------------------------
; WyślijDaneDoDS
;
;               We : brak
;               Wy : rej.A - Kod wyjścia
;--------------------------------------------------------------------------
WyslijDaneDoDS: MOV     A,#DSTemp       ; DSTL=DSTemp[ Termometr ]
                ADD     A,Termometr
                MOV     R1,A
                MOV     DSTL,@R1
                MOV     DSTH,#7FH       ; DSTH = 7FH
                LCALL   ObliczMaskaP
                MOV     R1,#DSTH
                LCALL   DS_WRITE_EE
                RET

;--------------------------------------------------------------------------
;
;               Funkcje obsługi układów DS 1820.
;
;--------------------------------------------------------------------------
;
;     UWAGA!
;     
;     Przed wywołaniem każdej z funkcji należy odpowiednio ustawić
;     zmienne: Termometr, Maska oraz MaskaDSPort.
;
;--------------------------------------------------------------------------

;--------------------------------------------------------------------------
; DS_ID
;
;       We: zm. Bufor - adres bufora na dane
;       Wy: rej. A - Kod wyjścia, jeżeli równy zero to w buforze są dane:
;                        1 bajt   - kod rodziny,
;                        6 bajtów - numer seryjny,
;                        1 bajt   - CRC.
;--------------------------------------------------------------------------
DS_ID:          LCALL   DS_RST          ; Reset and Presence pulses
                JNZ     DS_ID_END
                MOV     A,#33H          ; Read ROM Command
                LCALL   MASTER_Tx
                MOV     R0,#Bufor
                MOV     B,#8
                LCALL   MASTER_Rx_CIAG  ; Czytaj dane
                LCALL   DS_RST          ; Reset and Presence pulses
                JNZ     DS_ID_END
                MOV     R0,#Bufor
                MOV     B,#7
                LCALL   OBLICZ_CRC
                MOV     A,Bufor+7       ; Porównanie CRC
                CLR     C
                SUBB    A,CRC
                JZ      DS_ID_END       ; OK!
                MOV     A,#1            ; CRC-ERROR
DS_ID_END:      RET

;--------------------------------------------------------------------------
; DS_RECALL_EE
;
;               We : brak
;               Wy : rej. A - Kod wyjścia
;
;    Kopiuje zawartość pamięci E^2 do pamięci SCRATCHPAD układu DS1820.
;--------------------------------------------------------------------------
DS_RECALL_EE:   LCALL   DS_RST          ; Reset and Presence pulses
                JNZ     DS_REE_END
                MOV     A,#0CCH         ; Skip ROM Command
                LCALL   MASTER_Tx
                MOV     A,#0B8H         ; Recall E^2
                LCALL   MASTER_Tx
                LCALL   DS_BUSY         ; czekaj aż wolny
                JNZ     DS_REE_END
                LCALL   DS_RST          ; Reset and Presence pulses
DS_REE_END:     RET

;--------------------------------------------------------------------------
; DS_CONVERT_TEMPERATURE
;
;               We: brak
;               Wy: rej. A - Kod wyjścia
;--------------------------------------------------------------------------

DS_CONVERT_TEMPERATURE: LCALL   DS_RST  ; Reset and Presence pulses
                JNZ     DS_CT_END
                MOV     A,#0CCH
                LCALL   MASTER_Tx       ; Skip ROM Command
                MOV     A,#44H          ; Convert Temperature
                LCALL   MASTER_Tx
                CLR     TR0             ; ds pin = hi przez min 500 ms
                CLR     TF0             ;             czyli  500000 us
                MOV     Licznik,#8      ; 8 * 65536 = 524288
DS_CT_P1:       MOV     TH0,#0
                MOV     TL0,#0
                SETB    TR0
                JNB     TF0,$           ; Strong pull-up
                CLR     TR0
                CLR     TF0
                DJNZ    Licznik,DS_CT_P1
                LCALL   DS_BUSY         ; czekaj aż DS będzie wolny
                JNZ     DS_CT_END
                LCALL   DS_RST          ; Reset and Presence pulses
DS_CT_END:      RET

;--------------------------------------------------------------------------
; DS_WRITE_EE
;
;         We: rej. R1 - Początek bufora z danymi ( dwa bajty ).
;         Wy: rej. A  - Kod wyjścia.
;
;         Funkcja kopiuje zawartość bufora, którego początek wskazuje
; rejestr R1 do pamięci SCRATCHPAD układu DS1820, następnie odczytuje tę
; pamięć i sprawdza czy została zapisana prawidłowo i, jeżeli wszystko w
; porządku to kopiuje zawatrość pamięci SCRATCHPAD do pamięci E^2.
;--------------------------------------------------------------------------
DS_WRITE_EE:    LCALL   DS_WRITE_SCRATCHPAD
                JNZ     DS_WEE_END
                LCALL   DS_READ_SCRATCHPAD
                JNZ     DS_WEE_END
                MOV     R0,#DSTH
                CLR     C               ; Spr. poprawności zapisu
                MOV     A,Bufor+2       ; TH
                SUBB    A,@R0           ; @R0 - pierwszy bajt
                JNZ     DS_WEE_ERR
                INC     R0              ; teraz @R0 to bajt drugi
                CLR     C
                MOV     A,Bufor+3       ; TL
                SUBB    A,@R0
                JZ      DS_WEE_P1
DS_WEE_ERR:     MOV     A,#09H
                LJMP    DS_WEE_END
DS_WEE_P1:      LCALL   DS_COPY_SCRATCHPAD
DS_WEE_END:     RET

;--------------------------------------------------------------------------
; DS_READ_SCRATCHPAD
;
;               We: zm. Bufor  - początek bufora danych ( roz. 9 bajtów ).
;               Wy: rej. A     - Kod wyjścia.
;--------------------------------------------------------------------------
DS_READ_SCRATCHPAD:     LCALL   DS_RST  ; Reset and Presence pulses
                JNZ     DS_RC_END
                MOV     A,#0CCH         ; Skip ROM Command
                LCALL   MASTER_Tx
                MOV     A,#0BEH         ; Read Scratchpad
                LCALL   MASTER_Tx
                MOV     R0,#Bufor
                MOV     B,#9
                LCALL   MASTER_Rx_CIAG  ; Czytaj 9 bajtów
                LCALL   DS_RST          ; Reset and Presence pulses
                JNZ     DS_RC_END
                MOV     R0,#Bufor       ; Sprawdzam CRC
                MOV     B,#8
                LCALL   OBLICZ_CRC
                MOV     A,Bufor+8       ; Porównanie CRC
                CLR     C
                SUBB    A,CRC
                JZ      DS_RC_P1        ; OK!
                MOV     A,#1
                LJMP    DS_RC_END
DS_RC_P1:       MOV     A,#0
DS_RC_END:      RET

;--------------------------------------------------------------------------
; DS_WRITE_SCRATCHPAD
;
;               We : rej. R1 - adres początku bufora z danymi ( dwa bajty )
;               Wy : rej. A  - kod wyjścia
;
;     Funkcja zapisuje do pamięć SCRATCHPAD ( dwa dostępne bajty )
; układu DS1820 dane z bufora ( bajt pierwszy pod adresem 2, drugi pod
; adresem 3 ).
;--------------------------------------------------------------------------
DS_WRITE_SCRATCHPAD:    LCALL   DS_RST  ; Reset and Presence pulses
                JNZ     DS_WS_END
                MOV     A,#0CCH         ; Skip ROM Command
                LCALL   MASTER_Tx
                MOV     A,#4EH          ; Write Scratchpad
                LCALL   MASTER_Tx
                MOV     A,@R1           ; wyślij bajt pierwszy
                LCALL   MASTER_Tx
                INC     R1              ; @R1 - bajt drugi
                MOV     A,@R1           ; wyślij bajt drugi
                LCALL   MASTER_Tx
                LCALL   DS_RST          ; Reset and Presence pulses
                JNZ     DS_WS_END
DS_WS_END:      RET

;--------------------------------------------------------------------------
; DS_COPY_SCRATCHPAD
;
;               We: brak
;               Wy: rej. A - Kod wyjścia
;
;     Funkcja kopiuje dwa bajty pamięci SCRATCHPAD układu DS1820 ( rozpo-
; czynając od adresu 2 ) do pamięci E^2.
;--------------------------------------------------------------------------
DS_COPY_SCRATCHPAD:     LCALL   DS_RST  ; Reset and Presence pulses
                JNZ     DS_CS_END
                MOV     A,#0CCH         ; Skip ROM Command
                LCALL   MASTER_Tx
                MOV     A,#48H          ; Copy Scratchpad
                LCALL   MASTER_Tx
                CLR     TR0             ; Strong pull-up
                CLR     TF0
                MOV     TH0,#0D8H       ; 10 ms
                MOV     TL0,#0F0H
                SETB    TR0
                JNB     TF0,$
                CLR     TR0
                CLR     TF0
                LCALL   DS_BUSY         ; czekaj aż wolny
                JNZ     DS_CS_END
                LCALL   DS_RST          ; Reset and Presence pulses
DS_CS_END:      RET

;--------------------------------------------------------------------------
; DS_BUSY
;
;               We : brak
;               Wy : rej. A - Kod wyjścia
;
;     Funkcja bada stan BUSY układu DS1820. Wyjście następuje po
; przesłaniu przez układ DS1820 sygnału "wolny" lub po przekroczeniu
; czasu oczekiwania ( przyczyną może być zwarcie ).
;--------------------------------------------------------------------------
DS_BUSY:        CLR     TR0
                MOV     TL0,#0          ; czas oczekiwania = 65536um
                MOV     TH0,#0
                CLR     TF0
                SETB    TR0
DSB_P0:         JB      TF0,DSB_ERR
                MOV     A,DSPort
                ANL     A,Maska
                JZ      DSB_P0
                CLR     TR0
                SJMP    DSB_P1
DSB_ERR:        MOV     A,#5
                SJMP    DSB_END
DSB_P1:         MOV     A,#0
DSB_END:        RET

;--------------------------------------------------------------------------
;
;				        Protokół 1-Wire(TM) 
;                   Najniższa warstwa logiczna.
;
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
;  DS_RST
;                       *----------------------------*
;                       | Reset and Presence pulses. |
;                       *----------------------------*
;
;               We : brak
;               Wy : rej. A - Kod wyjścia
;
;--------------------------------------------------------------------------
DS_RST:         MOV     TH0,#0FDH       ; ------------ Krok 1 -------------
                MOV     TL0,#44H        ; Ustawienie timer'a
                CLR     TF0             ; 65536 - 700(dl.syg.RESET)=FD44h
                SETB    TR0             ; Timer0 Start!
                MOV     DSPort,MaskaDSPort ; Master Tx = 0
                JNB     TF0,$           ;
                MOV     DSPort,#0FFh    ; Master Tx = 1;
                CLR     TR0             ; Timer0 Stop!
                CLR     TF0             ; Flaga przepełnienia w dół.
                MOV     B,#2            ; ------------ Krok 2 -------------
                MOV     TH0,#0FFH       ; ustaw licznik na 60 mikro sek.
                MOV     TL0,#0C4H       ;
                SETB    TR0             ; Timer0 Start!
__P1:           MOV     A,Maska         ; Oczekiwanie na reakcję DS'a
                ANL     A,DSPort        ;
                JZ      __P2            ; DS odpowiedział
                JB      TF0,RST_ERR     ; Jeżeli czekamy zbyt długo...
                LJMP    __P1            ;
__P2:           CLR     TR0             ; Jeżeli nastąpiła reakcja to...
                MOV     B,#3            ; ------------ Krok 3 -------------
                MOV     TH0,#0FFH       ; Ustawienie timer'a
                MOV     TL0,#06H        ;
                CLR     TF0             ;
                SETB    TR0             ; Timer0 Start!
__P3:           MOV     A,DSPort        ;
                ANL     A,Maska         ;
                JNZ     __P4            ; Koniec syg. PRESENCE
                JB      TF0,RST_ERR     ; if log. "0" trwa zbyt długo...
                LJMP    __P3
__P4:           CLR     TR0             ; Timer0 Stop!
                MOV     B,#4            ; ------------ Krok 4 -------------
                MOV     A,#TL0          ; Sprawdźmy czy Presence pulse
                SUBB    A,#32H          ; nie trwał zbyt krótko.
                JC      RST_ERR         ; if mniej niż 50um to ERROR.
                MOV     B,#0            ; ------------ Koniec -------------
RST_ERR:        MOV     A,B             ; Do A kod wyjścia
                RET

;--------------------------------------------------------------------------
; MASTER_Tx
;
;               We : rej. A - bajt maiący zostać wysłanym do DS'a
;               Wy : brak.
;
;               Wysyła bajt z A do DS'a.
;--------------------------------------------------------------------------
MASTER_Tx:      MOV     MaskaDSbit,#1   ; wysyłam bit po bicie wg MASKI
MTx_P0:         PUSH    ACC             ; w A bajt do wysłania
                ANL     A,MaskaDSbit    ; wysłać ZERO czy JEDEN ?
                JZ      MTx_0           ; ZERO
                LJMP    MTx_1           ; JEDEN
MTx_P1:         CLR     C               ; ważne żeby C=0 ( obrót maski )
                MOV     A,MaskaDSbit    ; *
                RLC     A               ; * obrót maski w lewo
                MOV     MaskaDSbit,A    ; *
                POP     ACC
                JNC     MTx_P0
                RET

MTx_0:          LCALL   MASTER_Tx_0
                LJMP    MTx_P1

MTx_1:          LCALL   MASTER_Tx_1
                LJMP    MTx_P1

MASTER_Tx_0:    MOV     Licznik,#30        ; wysyłamy logiczne ZERO
                MOV     DSPort,MaskaDSPort ; DS pin = low
Tlo0:           DJNZ    Licznik,Tlo0       ; czas : 2C * 30 = 60C
                MOV     DSPort,#0FFH       ; DS pin = hi
                RET

MASTER_Tx_1:    MOV     Licznik,#5         ; wysyłamy logiczną JEDYNKĘ
                MOV     DSPort,MaskaDSPort ; DS pin = low
Tlo1:           DJNZ    Licznik,Tlo1       ; czas : 2C * 2 = 4C
                MOV     DSPort,#0FFH       ; DS pin = hi
                MOV     Licznik,#26        ; * wyrównanie SLOT'u
Thi1:           DJNZ    Licznik,Thi1       ; * czas : 2C * 30 = 60C
                RET

;--------------------------------------------------------------------------
; MASTER_Rx_CIAG
;
;               We: rej. B -  ilość bajtów do odebrania
;                       R0 -  początek bufora.
;               Wy: rej. A - ostatni odebrany bajt ( CRC )
;
;               Odebranie ciągu bajtów od DS'a.
;--------------------------------------------------------------------------
MASTER_Rx_CIAG: LCALL   MASTER_Rx
                MOV     @R0,A
                INC     R0
                DJNZ    0F0H,MASTER_Rx_CIAG
                RET

;--------------------------------------------------------------------------
; MASTER_Rx
;
;               We: brak
;               Wy: rej. A - odebrany bajt.
;
;               Odebranie bajtu od DS'a.
;--------------------------------------------------------------------------
                                    ; liczba cykli ( 1 cykl = 1 um )
MASTER_Rx:      MOV     A,#0              ;1C; W A wynik
                MOV     MaskaDSbit,#1     ;2C;
                PUSH    ACC               ;2C; Wynik na STOS
MRx_P0:         LCALL   MASTER_Rx_MONITOR ;2C;
                JZ      MRx_P1            ;2C; if bit = 0 to skok
                POP     ACC               ;2C; % wynik ze STOSU
                ORL     A,MaskaDSbit      ;1C; % zapal bit
                PUSH    ACC               ;2C; % wynik na STOS
MRx_P1:         CLR     C                 ;1C;
                MOV     A,MaskaDSbit      ;2C; *
                RLC     A                 ;1C; *  obrót maski w lewo
                MOV     MaskaDSbit,A      ;2C; *
                JNC     MRx_P0            ;2C; if C=0 to nie koniec
                POP     ACC               ;2C; wynik ze STOSU
                RET                                               ;2C;

;--------------------------------------------------------------------------
; MASTER_Rx_MONITOR
;
;         We: brak
;         Wy: rej. A - odebrany bit
;
;         Nasłuch linii Rx, zwraca odebrany bit.
;--------------------------------------------------------------------------
MASTER_Rx_MONITOR:                    ;liczba cykli ( 1 cykl = 1 um )
                MOV     Licznik,#5         ;2C;
                MOV     DSPort,MaskaDSPort ;2C; DS pin low
MAS_INIT:       DJNZ    Licznik,MAS_INIT   ;2C;
                MOV     DSPort,#0FFH       ;2C;
                MOV     A,DSPort           ;1C;
                ANL     A,Maska            ;1C;
                JNZ     MRx_JEDEN          ;2C;
                MOV     A,#0               ;1C; wynik wykonania funkcji
                LJMP    MRx_MEND           ;2C;
MRx_JEDEN:      MOV     A,#1               ;1C; wynik wykonania funkcji
MRx_MEND:       MOV     Licznik,#30        ;2C;
MRx_MSLOTE:     DJNZ    Licznik,MRx_MSLOTE ;2C;
                RET                        ;2C;

;--------------------------------------------------------------------------
;
;		    	Procedury obliczania sumy kontrolnej ( CRC ) 
;               		w protokole 1-Wire(TM)
;
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
; OBLICZ_CRC
;               We: rej. B - ilość bajtów
;                       R0 - początek ciągu
;               Wy: zm.CRC - CRC
;--------------------------------------------------------------------------
OBLICZ_CRC:     MOV     CRC,#0
OC_P0:          MOV     A,@R0
                LCALL   OBLICZ_CRC_BAJT
                INC     R0
                DJNZ    0F0H,OC_P0
                RET

;--------------------------------------------------------------------------
; OBLICZ_CRC_BAJT
;
;               We: rej. A - bajt
;               Wy: zm.CRC - CRC ( Zmienna CRC nie jest zerowana )
;--------------------------------------------------------------------------
OBLICZ_CRC_BAJT:PUSH    ACC
                MOV     Licznik,#8      ; 8 bitów w bajcie
OCB_P0:         XRL     A,CRC           ; * ( zmiany w A )
                RRC     A               ; * W celu wysunięcia na C
                MOV     A,CRC           ; % teraz zmiany w CRC
                JNC     ZERO            ; % if C = 0 to XOR bez
                XRL     A,#18H          ; %        znaczenia
ZERO:           RRC     A               ; %
                MOV     CRC,A           ; %
                POP     ACC             ; * przesunięcie bajtu wejścia
                RR      A               ; *
                PUSH    ACC             ; *
                DJNZ    Licznik,OCB_P0
                POP     ACC
                RET

;--------------------------------------------------------------------------
; 
;               Procedury obsługi wyświetlacza alfanumerycznego LCD
;                        wyposażonego w sterownik HD44870
;                dla mikrokomputerów jednoukładowych "rodziny 80".
;
; Assembler                     : 8051
; Podłączenie wyświetlacza      : stała LCDPort ( patrz niżej )
; Interfejs 4-bitowy.
;--------------------------------------------------------------------------
;
;  Procedury ( public ):
;
;  INIT_LCD          - inicjacja wyświetlacza ( interfejs 4-bitowy ).
;  CZYSC_LCD         - Czyści wyświetlacz i ustawia kursor w poz. 0,0.
;  GOTOXY_LCD        - pozycjonowanie kursora.
;                      		We : rej. A - x, rej. B - y.
;  ZNAK_NA_LCD       - Wypisanie znaku na wyświetlaczu w aktualnej
;                      pozycji kursora.
;                      		We : rej. A - znak.
;  CIAG_ROM_NA_LCD   - Wypisanie ( od aktualnego miejsca położenia
;                      kursora ) ciągu z pamięci ROM. Ciąg musi być
;                      zakończony zerem.
;                      		We : DPTR - wskażnik na początek ciągu.
;  CIAG_RAM_NA_LCD   - Wypisanie ciągu (zakończonego zerem) z pamięci RAM.
;                      		We : rejestr R0 - początek ciągu
;  CIAGP_RAM_NA_LCD  - Wypisanie ciągu z pamięci RAM.
;                      		We : rejestr R0 - początek ciągu
;                           	 rejestr B  - długość ciągu.
;
;--------------------------------------------------------------------------
;  Procedury wykorzstują:
;
; * Timer 0 ( CZEKAJ_LCD, CZEKAJ_100um ) jako licznik 16-bitowy ( tryb 1 )
; Ustawienie trybu pracy licznika musi nastąpić przed wywołaniem procedury.
; * Rejestry : A, B, R0 i DPTR( ich stan nie jest chroniony poprzez stos ).
; * Zmienną globalną : Licznik.
;
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
; Stałe
;--------------------------------------------------------------------------
LCDPort EQU     P2              ; Port wyświetlacza
RS      EQU     20H             ; sygnał Register Select - linia 5
RW      EQU     40H             ;  -"-   Read/Write      - linia 6
EN      EQU     80H             ;  -"-   Enable          - linia 7

;--------------------------------------------------------------------------
; CZEKAJ_LCD
;
;       Procedura odczekuje stałą wartość 52fh ( FFFFh - FAD0h ) czyli
; 1327 mikro sekund. Jest to niezbędna dla poprawnej komunikacji z wyświe-
; tlaczem pauza pomiędzy wysłaniem kolejnych danych.
;--------------------------------------------------------------------------
CZEKAJ_LCD:     MOV     TH0,#0FAH
                MOV     TL0,#0D0H
                SETB    TR0
                JNB     TF0,$
                CLR     TR0
                CLR     TF0
                RET

CZEKAJ_100um:   MOV     Licznik,#50     ; Procedura "czeka" około 100um
                DJNZ    Licznik,$       ; 
                RET

;--------------------------------------------------------------------------
; ZATRZASK_LCD
;
;               Wejście : rej. A - dolne cztery bity to dane,
;                                  bity 5 i 6 to pozimy sygnałów RS i R/W
;
;     Procedura ustawia poziom sygnałów na porcie wyświetlacza wg danych
; przekazanych w rejestrze A. Następnie poprzez zmianę sygnału ENABLE
; "zatrzaskuje" te dane na liniach wejściowych sterownika wyświetlacza.
;--------------------------------------------------------------------------
ZATRZASK_LCD:   MOV     LCDPort,A       ;
                ORL     LCDPort,#80H    ; Ustaw sygnał Enable ( EN )
                LCALL   CZEKAJ_LCD
                ANL     LCDPort,#6FH    ; Zgaś syg. EN ( zatrzaśnij dane )
                LCALL   CZEKAJ_LCD
                RET

;--------------------------------------------------------------------------
; BAJT_DO_LCD
;
;               Wejście : rej. A - bajt który ma zostać wysłany.
;                         rej. B - bit 5 - poziom sygnału RS
;                                  bit 6 - poziom sygnału R/W
;
;       Wysłanie bajtu odbywa się w dwóch krokach, najpierw wysyłamy górną
; połówkę bajtu, później dolną. Dla "fizycznego" wysłania danych wywoływana
; jest procedura ZATRZASK_LCD ( patrz wyżej ).
;--------------------------------------------------------------------------
BAJT_DO_LCD:    PUSH    ACC          ; przyda się
                RR      A            ; *                       GÓNE PÓŁ
                RR      A            ; |
                RR      A            ; |
                RR      A            ; *-> przesuń górne pół do dolnego pół
                ANL     A,#0FH       ; zeruj górne pół
                ORL     A,B          ; ustaw poziomy sygnałów RS i R/W
                LCALL   ZATRZASK_LCD ; Wyślij!
                POP     ACC          ; mówiłem, że się przyda
                ANL     A,#0FH       ; *                       DOLNE PÓŁ
                ORL     A,B          ; |
                LCALL   ZATRZASK_LCD ; *-> jak wyżej
                RET

;--------------------------------------------------------------------------
; FUNKCJA_LCD
;
;               Wejście : rej. A - numer funkcji.
;
;     Wywołuje funkcję sterownika wyświetlacza, której numer dostaje
;     w rejestrze A.
;
; Uwaga! W czasie pracy z wyświetlaczem okazało się, iż wywołanie funkcji
; sterownika wyświetlacza wymaga dodatkowego opóźnienia - 100um wystarcza.
;--------------------------------------------------------------------------
FUNKCJA_LCD:    MOV     B,#00H          ; dla funkcji poziom RS i R/W = 0
                LCALL   BAJT_DO_LCD
                LCALL   CZEKAJ_100um
                RET

;--------------------------------------------------------------------------
; CZYSC_LCD
;           Czyści wyświetlacz i ustawia kursor w pozycji ( 0,0 ).
;                       - funkcja sterownika.
;--------------------------------------------------------------------------
CZYSC_LCD:      MOV     A,#01H
                LCALL   FUNKCJA_LCD
                RET
;--------------------------------------------------------------------------
; GTOXY_LCD
;               Wejście : rej. A - pozycja x.
;                         rej. B - pozycja y.
;
;    Ustawia kursor wg współrzędnych przekazanych w rejestrach A i B.
;--------------------------------------------------------------------------
GOTOXY_LCD:     PUSH    ACC         ; x na stos
                PUSH    B           ; y na stos
                MOV     A,#02H      ; *   funkcja ta ustawia kursor w pozy-
                LCALL   FUNKCJA_LCD ; *   cji ( 0,0 ).
                POP     ACC         ; y ze stosu
                JZ      G_P1        ; jeżeli y = 0 to skok do P1
                MOV     A,#40       ; else przesuń kursor do pozycji (0,1)
G_P0:           PUSH    ACC         ; ilość kroków w prawo na stos     <--*
                MOV     A,#14H      ; * funkcja przesuwa kursor o         |
                LCALL   FUNKCJA_LCD ; * jedno pole w prawo.               |
                POP     ACC         ; ilość kroków ze stosu               |
                DJNZ    ACC,G_P0    ; jeżeli ilość kroków != 0 to...------*
G_P1:           POP     ACC         ; x ze stosu
                JZ      G_P3        ; jeżeli x = 0 to koniec else...
G_P2:           PUSH    ACC         ; ilość kroków w prawo na stos   <----*
                MOV     A,#14H      ; *                                   |
                LCALL   FUNKCJA_LCD ; *  funkcja przesuwa kursor w prawo  |
                POP     ACC         ; ilość kroków ze stosu               |
                DJNZ    ACC,G_P2    ; jeżeli ilość kroków != 0 to...------*
G_P3:           RET

;--------------------------------------------------------------------------
; ZNAK_NA_LCD
;               Wejście : rej. A - znak.
;
;            Wypisuje znak przekazany w rejestrze A na wyświetlacz.
;--------------------------------------------------------------------------
ZNAK_NA_LCD:    MOV     B,#RS           ; RS = 1, R/W = 0
                LCALL   BAJT_DO_LCD
                RET

;--------------------------------------------------------------------------
; CIAG_ROM_NA_LCD
;
;         Wejście: DPTR - wskazuje adres początku ciągu zakończonego zerem.
;
;         Procedura wypisuje ciąg znaków na wyświetlaczu.
;--------------------------------------------------------------------------
CIAG_ROM_NA_LCD:CLR     A               ; <-------------------------------*
                MOVC    A,@A+DPTR       ; do A znak                       |
                JZ      C_END           ; jeżeli zero to koniec ( C_END ) |
                LCALL   ZNAK_NA_LCD     ; else wypisz znak na LCD         |
                INC     DPTR            ; zwiększ o jeden                 |
                LJMP    CIAG_ROM_NA_LCD ; *-------------------------------*
C_END:          RET

;--------------------------------------------------------------------------
; CIAG_RAM_NA_LCD
;
;        Wejście: R0 - wskazuje adres początku ciągu zakończonego zerem.
;
;        Procedura wypisuje ciąg znaków zakończony zerem na wyświetlacz.
;--------------------------------------------------------------------------
CIAG_RAM_NA_LCD:MOV     A,@R0
                JZ      C_RAM_END
                LCALL   ZNAK_NA_LCD
                INC     R0
                LJMP    CIAG_RAM_NA_LCD
C_RAM_END:      RET

;--------------------------------------------------------------------------
; CIAGP_RAM_NA_LCD
;
;            Wejście: R0       - wskazuje adres początku ciągu.
;                     rej. B   - liczba znaków w ciągu.
;
;            Procedura wypisuje ciąg znaków na wyświetlaczu.
;--------------------------------------------------------------------------
CIAGP_RAM_NA_LCD:MOV     A,@R0
                 LCALL   ZNAK_NA_LCD
                 INC     R0
                 DJNZ    0F0H,CIAGP_RAM_NA_LCD
                 RET

;--------------------------------------------------------------------------
; InitLCD
;            Inicjacja wyświetlacza LCD.
;            Interfejs 4-bitowy.
;
;                        PROCEDURY WYMAGANE
;
;--------------------------------------------------------------------------
INIT_LCD:       MOV     A,#03H
                LCALL   ZATRZASK_LCD
                MOV     B,#6                    ; Czekaj
In_P3:          MOV     Licznik,#0FFH
In_P2:          DJNZ    Licznik,In_P2
                DJNZ    0F0H,In_P3
                MOV     B,#02H
In_P0:          LCALL   ZATRZASK_LCD
                LCALL   CZEKAJ_100um
                DJNZ    0F0H,In_P0
                MOV     A,#02H
                LCALL   ZATRZASK_LCD    ; inicjuj interfejs 4-bitowy
                LCALL   CZEKAJ_100um

             ; Od tego miejsca, każdy bajt do LCD musi być wysłany
             ; w dwóch porcjach - najpierw starsza połówka, później mł.
             ; Co oznacza, że można już korzystać z funkcji
             ; do komunikacji z wyświetlaczem

                MOV     A,#2CH           ; Function Set ( 2Ch )
                LCALL   FUNKCJA_LCD
                MOV     A,#08H           ; Display ON/OFF ( 08h )
                LCALL   FUNKCJA_LCD
                MOV     A,#01H           ; Clear Display ( 01h )
                LCALL   FUNKCJA_LCD
                MOV     A,#06H           ; Entry Mode Set ( 06h )
                LCALL   FUNKCJA_LCD
                RET

;--------------------------------------------------------------------------
;
;						Koniec programu SpecROM.
;
;----------------------------------------------------------------------- ;)
