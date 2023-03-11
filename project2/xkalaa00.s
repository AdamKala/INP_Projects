; Autor reseni: Adam Kala xkalaa00

; Projekt 2 - INP 2022
; Vernamova sifra na architekture MIPS64

; DATA SEGMENT
; registry 0 4 5 9 17 29
; r0
; r5 - zapisovany znak
; r9 - adresa pro cisla 122 a 97
; r17 - 122
; r29 - login
; r4
;
; xkalaa
; +11 -1 +11 -1 +11 -1
; klic - kakakaka
; abcdefghijklmnopqrstuvwxyz
; ascii a - 97
; ascii k - 107
; zasifrovany - ijlklz

    .data
login:          .asciiz "xkalaa00"  ; vstup
cipher:         .space  9          ; vystup

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                ; retezce pro vypis pomoci syscall 5
                ; (viz nize "funkce" print_string)

    .text

    ; ZDE NAHRADTE KOD VASIM RESENIM

main:
    daddi r7, r0, 0                                                 ;r7 se nastavi na 0, jako int i = 0      

while: 
    lb r29, login(r7)                                               ;nacteni login[r7] 
    slti r5, r29, 97                                                ;if(login[r7] < 97)
    bne r5, r0, end                                       

    daddi r29, r29, 11                                              ;login[r7] + 11 (k je 11 v abecede)
    daddi r17, r0, 122                                              ;do r17 zapsat hodnotu 122
    slt r5, r17, r29;                                               ;if(122 < login[r7]) 
    bne r5, r0, charL                                                  
if2:
    sb r29, cipher(r7)                                              ;ulozeni login[r7] do cipher[r7]
    daddi r7, r7, 1                                                 ;r7++

    lb r29, login(r7)                                               ;nacteni login[r7]                   
    slti r5, r29, 97                                                ;if(login[r7] < 96)
    bne r5, r0, end

    daddi r29, r29, -1                                              ;login[r7] - 1 (a je prvni v abecede)
    slti r5, r29, 97                                                ;if(login[r7] < 96)
    bne r5, r0, charG

if1:
    sb r29, cipher(r7)                                              ;ulozeni login[r7] do cipher[r7]
    daddi r7, r7, 1                                                 ;r7++
    b while                                                         ;skoceni na zacatek while cyklu


;-------------------------funkce na print ze zadani-------------------------
print_string:                                                       ;adresa retezce se ocekava v r4
    sw      r4, params_sys5(r0)
    daddi   r14, r0, params_sys5                                    ;adr pro syscall 5 musi do r14
    syscall 5                                                       ;systemova procedura - vypis retezce na terminal
    jr      r31                                                     ;return - r31 je urcen na return address
;---------------------------------------------------------------------------

charG:
    daddi r29, r29, 26                                              ;pri pripadnem precteceni se prida +26 do r29 (26 je znaku v abecede)
    b if1

charL:
    daddi r29, r29, -26                                             ;pri pripadnem "podteceni" se odecte -26 do r29 (26 je znaku v abecede)
    b if2

end:
    daddi r4, r0, cipher                                            ;prida do r4 obsah cipher
    jal print_string                                                ;skoci na print_string
    syscall 0                                                       ;ukonci program
