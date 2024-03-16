extern GetStdHandle                  ; kernel32.dll
extern WriteConsoleA                 ; kernel32.dll

global MyPrintf

section .text

PRINT_BUFFER_CAPACITY equ 16d

; TODO - output to buffer instead of right to the console

;------------------------------------------------
; MyPrintf (analog to printf function in stdio)
; Supports nothing
; Return: text in console
;------------------------------------------------

MyPrintf:       push rcx

                mov rcx, -11                               ; STD_OUTPUT_HANDLE = -11
                call GetStdHandle                          ; stdout = GetStdHandle (-11)           
                            
                mov rdi, rax                               ; rdi = stdout value
                                    
                pop rdx                                    ; rdx = str addr
                mov rbx, rdx                               ; rbx = str addr
                    
                call MyStrlen                      
                mov rcx, rax                               ; rcx = str length
  
                lea rsi, [rel print_buffer]                ; rsi = addr to buffer

StringPrint:    cmp byte [rdx], '%'
                
                je PrintSpecifier

                mov al, byte [rdx]                                    ; al = curr symbol              
                mov [rsi], al                                         ; filling buffer

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

NoFlush:        loop StringPrint

                cmp byte [rel buffer_size], 0
                je EndPrint

                call CmdFlush                                     ; calling cmd flush if the buffer is not empty
EndPrint:       ret

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

;------------------------------------------------ HAVEN'T BEEN IMPLEMENTED
; PrintChar (prints one symbol)
; Entry: rcx = symbol
; Return: -
;------------------------------------------------

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
; PrintSpecifier (print thing that choosed by %)
; 
;
;
;------------------------------------------------
PrintSpecifier: ret

section .data
print_buffer times PRINT_BUFFER_CAPACITY db 0
buffer_size  db 0