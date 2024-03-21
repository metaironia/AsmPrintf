extern GetStdHandle                  ; kernel32.dll
extern WriteConsoleA                 ; kernel32.dll

global MyPrintf

section .text

PRINT_BUFFER_CAPACITY equ 16d
RET_OPCODE            equ 3ch

; TODO - output to buffer instead of right to the console

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
                jb JumpTableEnd             ; if specifier doesn't exist    

                movzx rbx, byte [rdx]       ; rdx is char from 0 to 255
                sub rbx, '%'  
                shl rbx, 3d                 ; * 8 because size of one cell in jump table = 8 bytes  
                lea rax, [rel JumpTable] 
                add rax, rbx                ; rax = addr in jmp table
                jmp [rax]                          

JumpTable:   

                        dq PercSpecifier    ; %%

times ('a' - '&' + 1)   dq JumpTableEnd     ; skip & - a

                        dq BinSpecifier     ; %b                        
                        dq CharSpecifier    ; %c                        
                        dq IntSpecifier     ; %d

times ('r' - 'e' + 1)   dq JumpTableEnd     ; skip e - r

                        dq StrSpecifier     ; %s

times ('w' - 't' + 1)   dq JumpTableEnd     ; skip t - w

                        dq HexSpecifier     ; %x

times ('z' - 'y' + 1)   dq JumpTableEnd     ; skip y - z


PercSpecifier:  mov al, '%'
                call BufferCharAdd
                jmp JumpTableEnd

BinSpecifier:   add rbp, 8h                 ; next arg
                mov rbx, [rbp+10h]          ; rbx = hex number
                call PrintBin
                inc rdx
                jmp JumpTableEnd

CharSpecifier:  add rbp, 8h                 ; next arg
                mov al, byte [rbp+10h]      ; al = symbol
                call BufferCharAdd             
                jmp JumpTableEnd

IntSpecifier:   call PrintInt
                jmp JumpTableEnd

StrSpecifier:   add rbp, 8h                 ; next arg
                mov rbx, [rbp+10h]          ; rbx = str addr
                call PrintStr
                inc rdx                     ; inc pos in format
                jmp JumpTableEnd

HexSpecifier:   add rbp, 8h                 ; next arg
                mov rbx, [rbp+10h]          ; rbx = hex number
                call PrintHex
                inc rdx
                jmp JumpTableEnd


JumpTableEnd:   ret        

;------------------------------------------------ HAVEN'T BEEN IMPLEMENTED
; PrintInt (prints integer)
; Entry:
; Return: -
; Destructs: 
;------------------------------------------------

PrintInt:       ret

;------------------------------------------------
; PrintBin (prints binary number)
; Entry: rbx = bin number
; Return: -
; Destructs: rax
;------------------------------------------------

PrintBin:       push rcx                    ; saving rcx
                push rdx                    ; saving rdx because BufferCharAdd changes it

                mov rcx, 64d                 ; whole number range

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
; Entry: rbx = hex number
; Return: -
; Destructs: rax
;------------------------------------------------

PrintHex:       push rcx                    ; saving rcx
                push rdx                    ; saving rdx because BufferCharAdd changes it

                mov rcx, 16d                 ; whole number range

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

args_amount                              db 0

hex_letters                              db "0123456789ABCDEF"