extern GetStdHandle                  ; kernel32.dll
extern WriteConsoleA                 ; kernel32.dll

global MyPrintf

section .text

PRINT_BUFFER_CAPACITY equ 16d
INT_BUFFER_CAPACITY   equ 20d


;------------------------------------------------
; MyPrintf (analog to printf function in stdio)
; Supports nothing
; Return: text in console
;------------------------------------------------

MyPrintf:       push rbp
                mov rbp, rsp                       ; bp-chain

                push rbx                         ; 
                push rdi                         ; saving non-volatile registers MyPrintf destructs
                push rsi                         ; 

; To use arguments in a straightforward manner, we should move args from registers to memory right before ret addr.
; It's possible, because compiler reserves 32 bytes in stack before ret addr

                mov [rbp+18h], rdx               ; move second argument before ret addr
                mov [rbp+20h], r8                ; move third argument before ret addr
                mov [rbp+28h], r9                ; move fourth argument before ret addr
                push rcx                         ; push format string

                mov rcx, -11                     ; STD_OUTPUT_HANDLE = -11
                call GetStdHandle                ; stdout = GetStdHandle (-11)           

                mov rdi, rax                     ; rdi = stdout value
        
                pop rdx                          ; rdx = str addr
                mov rbx, rdx                     ; rbx = str addr
    
                call MyStrlen               
                mov rcx, rax                     ; rcx = str length

                lea rsi, [rel print_buffer]      ; rsi = addr to buffer
StringPrint:    cmp byte [rdx], '%'               
                jne NotSpecifier
                
                call PrintSpecifier

                loop StringPrint

NotSpecifier:   mov al, byte [rdx]               ; al = curr symbol      
                call BufferCharAdd

                loop StringPrint

                cmp byte [rel buffer_size], 0
                je EndPrint

                call CmdFlush                    ; calling cmd flush if the buffer is not empty
                
EndPrint:       pop rsi                          ;
                pop rdi                          ;
                pop rbx                          ; popping non-volatile registers
                pop rbp                          ; 

                ret


;------------------------------------------------
; MyStrlen
; Entry: rbx = string addr
; Return: rax = string length
; Destruct: rbx
;------------------------------------------------

MyStrlen:       xor rax, rax            ; rax = zero length

NewChar:        cmp byte [rbx], 0
                je EndString            ; if null-terminator

                inc rax
                inc rbx
                jmp NewChar             ; if not null-terminator

EndString:      ret


;------------------------------------------------
; BufferCharAdd
; Note: if buffer is full, BufferCharAdd flushes buffer to console
; Entry: al = symbol
; Assumes: rsi = buffer addr, rdx = pos in printable string
; Return: -
; Destructs:
;------------------------------------------------

BufferCharAdd:  mov [rsi], al                                         ; filling buffer

                inc byte [rel buffer_size]                            ; buffer_size++
                inc rsi                                               ; inc pos in buffer
                inc rdx                                               ; inc pos in string

                cmp byte [rel buffer_size], PRINT_BUFFER_CAPACITY - 1 ; minus 1 because of last null-terminator
                jne NoFlush

                push rcx                                              ; saving rest str length
                push rdx                                              ; saving pos in string
                call CmdFlush
                pop rdx                                               ; popping pos in string
                pop rcx                                               ; popping rest str length

NoFlush:        ret


;------------------------------------------------
; CmdFlush (prints buffer to cmd)
; Entry: rdi = stdout 
; Return: printed buffer 
; Destructs: rcx, rdx, r8, r9
;------------------------------------------------

CmdFlush:       mov rcx, rdi                     ; rcx = stdout
                mov rdx, print_buffer            ; rdx = print_buffer addr
                movsx r8, byte [rel buffer_size] ; r8 = buffer size
                xor r9, r9                       ; r9 = 0 (offset to char ptr) 
                push qword 0                     ; reserved
           
                call WriteConsoleA               ; WriteConsole (stdout, print_buffer, buffer_size, NULL, 0)
                add rsp, 8                       ; clears the arguments stored in stack 

                mov byte [rel buffer_size], 0    ; buffer_size = 0
                lea rsi, [rel print_buffer]      ; rsi = addr to buffer

                ret      


;------------------------------------------------
; PrintSpecifier (print thing that choosed by specifier after %)
; Entry: rdx = addr to string
; Destructs: rbx
;------------------------------------------------

PrintSpecifier: inc rdx                     ; rdx = pos in string after %

                cmp byte [rdx], 'x'         ;
                ja JumpTableEnd             ; if specifier doesn't exist

                cmp byte [rdx], '%'         ;
                je PercSpecifier            ; %%

                cmp byte [rdx], 'b'         ;
                jb JumpTableEnd             ; if specifier doesn't exist 

                movzx rbx, byte [rdx]       ; rdx is char from 0 to 255              
                lea rax, [rel JumpTable] 
                jmp [rax + (rbx - 'b') * 8] ; rbx - 'b' = base address,                            
                                            ; * 8 because size of one cell in jump table = 8 bytes
JumpTable:  
                        dq BinSpecifier     ; %b                        
                        dq CharSpecifier    ; %c                        
                        dq DecSpecifier     ; %d

times ('n' - 'e' + 1)   dq JumpTableEnd     ; skip e - n

                        dq OctSpecifier     ; %o

times ('r' - 'p' + 1)   dq JumpTableEnd     ; skip p - r

                        dq StrSpecifier     ; %s

times ('w' - 't' + 1)   dq JumpTableEnd     ; skip t - w

                        dq HexSpecifier     ; %x

times ('z' - 'y' + 1)   dq JumpTableEnd     ; skip y - z


PercSpecifier:  mov al, '%'
                call BufferCharAdd
                jmp JumpTableEnd

BinSpecifier:   add rbp, 8h                 ; next arg
                mov rbx, [rbp+10h]          ; rbx = number to bin print
                call PrintBin
                inc rdx                     ; inc pos in format str
                jmp JumpTableEnd

CharSpecifier:  add rbp, 8h                 ; next arg
                mov al, byte [rbp+10h]      ; al = symbol
                call BufferCharAdd             
                jmp JumpTableEnd

DecSpecifier:   add rbp, 8h                 ; next arg
                mov ebx, [rbp+10h]          ; rbx = number to dec print
                call PrintDec               
                inc rdx                     ; inc pos in format str
                jmp JumpTableEnd

OctSpecifier:   add rbp, 8h                 ; next arg
                mov rbx, [rbp+10h]          ; rbx = number to oct print
                call PrintOct
                inc rdx                     ; inc pos in format str
                jmp JumpTableEnd

StrSpecifier:   add rbp, 8h                 ; next arg
                mov rbx, [rbp+10h]          ; rbx = str addr
                call PrintStr
                inc rdx                     ; inc pos in format str
                jmp JumpTableEnd

HexSpecifier:   add rbp, 8h                 ; next arg
                mov rbx, [rbp+10h]          ; rbx = hex number
                call PrintHex
                inc rdx                     ; inc pos in format str
                jmp JumpTableEnd

JumpTableEnd:   ret        


;------------------------------------------------
; ClrLeadingZeros
; Entry: rbx = number
; Return: rcx = 64 - cleared bits
; Note: number will be rolled to rcx bits
; Destructs: rax
;------------------------------------------------

ClrLeadingZeros:    xor rcx, rcx

ZerosClearStart:    mov rax, rbx            ; rax = number

                    inc rcx

                    rol rax, cl
                    and al, 1h
                    test al, al             ; checks if bit is zero            

                    je ZerosClearStart

                    dec rcx                 

                    mov rbx, rax
                    ror rbx, 1d             ; one iteration is extra

                    mov rax, 64d
                    sub rax, rcx
                    xchg rax, rcx           ; rcx = 64 - rolled bits 

                    ret


;------------------------------------------------
; PrintDec (prints decimal number)
; Entry: rbx = number to decimal print
; Return: -
; Destructs: rax, rcx
; Note: number should be 32-bit
;------------------------------------------------

PrintDec:       push rdx                    ; saving rdx because div destructs it
                push rcx                    ; saving rcx

                mov eax, ebx                ; eax = number to dec print

                rol ebx, 1d                ; sign bit is least bit now
                and bl, 1h                  ; bl = 1 if signed

                test bl, bl                 ; bl = sign of num
                je NotSigned

                mov bl, al                  ; saving al
                mov al, '-'                 
                call BufferCharAdd
                mov al, bl                  ; restoring al

                not eax                     ;
                inc eax                     ; abs of signed num

NotSigned:      xor rcx, rcx                ; symbol counter

                mov r9, 10d          

                lea rbx, [rel buffer_to_int]

DecNextSymbol:  xor rdx, rdx                ; rdx:rax = signed number

                div r9                      ; rdx = remainder, rax = result

                inc rbx                     ; rbx = addr to empty cell in buffer to int               
                add dl, '0'                 ; dl = ascii code of current symbol
                mov [rbx], dl               ; add symbol to buffer

                inc rcx

                test rax, rax
                jne DecNextSymbol

PrintBufFill:   mov al, [rbx]
                dec rbx                     ; dec pos in buffer to int 

                call BufferCharAdd

                loop PrintBufFill

                pop rcx                     ; popping rcx
                pop rdx                     ; popping rdx

                ret


;------------------------------------------------
; PrintOct (prints octal number)
; Entry: rbx = number to octal print
; Return: -
; Destructs: rax
; Note: number should be 32-bit
;------------------------------------------------

PrintOct:       push rcx                    ; saving rcx
                push rdx                    ; saving rdx because BufferCharAdd changes it

                rol ebx, 1d                 ; rol sign of num

                mov al, bl  
                and al, 1h                  ; 0001b, al = sign of num
               
                test al, al
                jne OctSignNotZero

                call ClrLeadingZeros

                jmp PrintOctStart

OctSignNotZero: add al, '0'                 ; al = either 0 or 1

                call BufferCharAdd

                mov rcx, 21d                ; whole number range (21*3 + 1 = 64 bits)

PrintOctStart:  rol ebx, 3d                 ; three bits rol

                mov al, bl 
                and al, 7h                  ; 0111b
                add al, '0'                 ; al = ascii code 0-7

                call BufferCharAdd

                loop PrintOctStart

                pop rdx                     ; popping rdx
                pop rcx                     ; popping rcx

                ret


;------------------------------------------------
; PrintBin (prints binary number)
; Entry: rbx = number to binary print
; Return: -
; Destructs: rax
; Note: number should be 32-bit
;------------------------------------------------

PrintBin:       push rcx                    ; saving rcx
                push rdx                    ; saving rdx because BufferCharAdd changes it

                mov eax, ebx                ;
                xor rbx, rbx                ; 
                mov ebx, eax                ; 32-bit number

                call ClrLeadingZeros

PrintBinStart:  rol rbx, 1d                 ; one bit rol      

                mov al, bl 
                and al, 1d                  ; al either 1 or 0, mask to the least bit
                add al, '0'                 ; al = ascii code of either 1 or 0

                call BufferCharAdd

                loop PrintBinStart

                pop rdx                     ; popping rdx
                pop rcx                     ; popping rcx

                ret


;------------------------------------------------
; PrintHex (prints hex number)
; Entry: rbx = number to hex print
; Return: -
; Destructs: rax
; Note: number should be 32-bit
;------------------------------------------------

PrintHex:       push rcx                    ; saving rcx
                push rdx                    ; saving rdx because BufferCharAdd changes it

                mov eax, ebx                ;
                xor rbx, rbx                ; 
                mov ebx, eax                ; 32-bit number

                call ClrLeadingZeros
                
                mov dl, cl
                shr rcx, 2                  ; rcx /= 4 
                
                and dl, 3h                  
                test dl, dl                 ; check if counter is divisible by 4

                je PrintHexStart

                inc rcx                     ; add extra symbol to print

PrintHexStart:  rol rbx, 4d                 ; one symbol rol      

                mov dl, bl                  ; symbol in dl
                and dl, 0Fh                 ; 00001111b mask to very right symbol
                lea rax, [rel hex_letters]  
                add al, dl                  ; rax = addr to symbol in hex_letters

                mov al, [rax]               ; al = ascii code of symbol 

                call BufferCharAdd

                loop PrintHexStart

                pop rdx                     ; popping rdx
                pop rcx                     ; popping rcx

                ret


;------------------------------------------------
; PrintStr (prints string)
; Entry: rbx = string addr
; Return: -
; Destructs: al
;------------------------------------------------

PrintStr:       cmp byte [rbx], 0 
                je PrintStrEnd              ; if null-terminal

                push rdx                    ; saving rdx because BufferCharAdd changes it

PrintStrStart:  mov al, byte [rbx]
                call BufferCharAdd          ; add to buf

                inc rbx                     ; inc pos in str

                cmp byte [rbx], 0 
                jne PrintStrStart            ; if null-terminal

                pop rdx                     ; popping rdx

PrintStrEnd:    ret 

section .data

print_buffer times PRINT_BUFFER_CAPACITY db 0
buffer_size                              db 0

hex_letters                              db "0123456789ABCDEF"

buffer_to_int times INT_BUFFER_CAPACITY  db 0
