extern GetStdHandle                  ; kernel32.dll
extern WriteConsoleA                 ; kernel32.dll
extern ExitProcess                   ; kernel32.dll

global MyPrintf

section .text

;----------------------------------------------
; MyPrintf (analog to printf function in stdio)
; Supports nothing
; Return: text in console
;----------------------------------------------

MyPrintf:   push rcx

            mov rcx, -11        ; STD_OUTPUT_HANDLE = -11
            call GetStdHandle   ; stdout = GetStdHandle (-11)           
            mov rcx, rax        ; rcx = stdout

            pop rbx             ; rbx = str addr
            push rbx            ; saving str addr in stack
            call MyStrlen
            mov r8, rax         ; r8 = str length
  
            pop rdx             ; rdx = message
            xor r9, r9          ; 0 = offset to char ptr 
            push qword 0        ; reserved
           
            call WriteConsoleA  ; WriteConsole (stdout, msg, 5, NULL, 0)
            add rsp, 8

	        ret

;---------------------------------------------
; MyStrlen
; Entry: rbx = string addr
; Return: rax = string length
; Destruct: rbx
;---------------------------------------------

MyStrlen:   xor rax, rax            ; rax = zero length

NewChar:    cmp byte [rbx], 0
            je EndString            ; if null-terminator

            inc rax
            inc rbx
            jmp NewChar             ; if not null-terminator

EndString:  ret