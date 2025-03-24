;В 64-битных системах первые 6 аргументов передаются через регистры, а остальные — через стек.
;system V ABI
; -march=x86

section .text
    global my_printf
    extern reset_buffer
;===============================================================================================================
;------------------------------------------SECTION.MACROS-------------------------------------------------------
;--------------------------(after this section you can find start of !my_printf!)--------------------------------
;==============================================================================================================

;------------------------------------------------------------------------------------------------
;Macro get argument from stack
;Entry: -
;Exit : RCX - arg
;Destr: RAX RCX
;Calls:	None
;-------------------------------------------------------------------------------------------------
%macro GET_ARG 0

    movzx rax, byte [arg_counter]   ; Load current argument count
    inc al                          ; Increment counter
    mov byte [arg_counter], al      ; Store updated count

    ; Check if we've used all register arguments
    cmp al, 6
    jae %%stk                     ; If >=6, get from stack


    pop rcx                       ; Restore from saved register area
    jmp %%add_to_buf              ; Skip stack handling

%%stk:
    ; Get argument from stack
    mov rcx, [rbp]                ; Read argument from stack frame
    add rbp, 8                    ; Move stack pointer forward

%%add_to_buf:
    ; Argument is now in RCX for use
%endmacro
;-------------------------------------------------------------------------------------
; Macro add char to buf
;Entry: -
;Exit : -
;Destr: -
;Calls:	reset_buffer
;------------------------------------------------------------------------------------
%macro BUFFER_CHAR 1

    mov byte [buffer + r8], %1          ; Record symbol to buffer
    inc r8                              ; Inc position

    cmp r8, buffer_size
    jne %%skip_reset                    ; Check if need buffer reset
    call reset_buffer
%%skip_reset:

%endmacro
;-------------------------------------------------------------------------------------
;Macro to handle %o %x %b
;Entry: %1 - Bits per digit (1 for binary, 3 for octal, 4 for hexadecimal)
;Exit : -
;Destr: -
;Calls:	convert_number_shift
;------------------------------------------------------------------------------------

%macro ARGS_FOR_CONVERT 1

    push rsi                    ; Preserve format string pointer

    ; Set up conversion arguments
    mov rax, rcx                ; Move number to convert into RAX
    mov cl, %1                  ; Set bits
    lea rdi, [buffer_int + 31]  ; Point to end of 32-byte buffer

    call convert_number_shift    ; Perform actual conversion

    pop rsi                     ; Restore format string pointer
    jmp next_char

%endmacro
;-------------------------------------------------------------------------------------
;Transfer from buffer_int to buffer
;Entry:  RDI - pointer on buffer_int
;        RCX - length to copy
;Exit :
;Destr:
;Calls:	convert_number_shift
;------------------------------------------------------------------------------------

%macro  TRANSFER_FROM_BUFFER_INT_TO_BUFFER 1
    mov rsi, rdi             ; Start of num in buffer_int
    mov rdx,  %1             ; Length in rdx !

    lea rdi, [buffer + r8]  ; Pointer on buffer

    rep movsb               ; rcx = 0

    add r8, rdx             ; New position in buf

%endmacro

;===============================================================================================================
;-----------------------------------------!!!!!!!!SECTION.MY_PRINTF!!!!!!!!!!------------------------------------
;================================================================================================================

my_printf:

    push rbp
    mov rbp, rsp
    add rbp, 16                ; 16 - Skip return address and saved RBP


    push r9
    push r8
    push rcx                    ; Save argument registers
    push rdx
    push rsi


    mov rsi, rdi                    ; RSI = format string pointer
    xor r8, r8                      ; Initialize buffer position to 0 (IMPORTANT to save)

; Main format string processing loop
next_char:
    lodsb                           ; Load next character into AL, increment RSI
    test al, al                     ; Check for null
    jz end_printf                   ; If end of string, finish

    cmp al, '%'                     ; Check for format specifier
    je format_specifier             ; Handle format specifier


    BUFFER_CHAR al                  ; Regular character case
    jmp next_char

; Format specifier handler (%x, %d, etc.)
format_specifier:
    lodsb                           ; Get character after '%'

    ; Handle %% case
    cmp al, '%'
    je case_per


    mov bl, al                      ; Store specifier in BL
    sub bl, 'a'                     ; Convert to index
    movzx rbx, bl                   ; Extend to 64 bits
    cmp rbx, jump_table_size
    jae case_def                    ; Handle invalid specifiers

    ; Jump through format table
    lea rcx, [jump_table_format]    ; Load jump table address
    jmp [rcx + rbx*8]
    jmp [rcx + rbx*8]               ; Jump to handler (each entry is 8 bytes)

;=================================================================================================================
;-----------------------------------------SECTION.MY_FORMATS-----------------------------------------------------
;=================================================================================================================

;-------------------------------------------------------------------------------
;Handle %s (char) format specifier
;Entry: -
;Exit : -
;Destr: -
;Macros:GET_ARG, BUFFER_CHAR
;-------------------------------------------------------------------------------
case_c:
    GET_ARG
    BUFFER_CHAR cl
    jmp next_char
;--------------------------------------------------------------------------------
;Handle %s (string) format specifier
;Entry: -
;Exit : -
;Destr:  RAX RBX RCX
;Calls : strlen, reset_buffer, syscall
;Macros:GET_ARG
;-------------------------------------------------------------------------------

case_s:
    GET_ARG                   ; Get string argument (pointer stored in RCX)
    push rsi                  ; Preserve registers
    push rdi

    ; Prepare for string length calculation
    mov rdi, rcx             ; RDI = source string pointer
    call strlen              ; Calculate length (RAX = length)
    mov rcx, rax             ; Store length in RCX

    ; Check if string fits in remaining buffer space
    add rax, r8              ; RAX = potential new buffer position
    cmp rax, buffer_size     ; Compare with buffer capacity
    jbe copy_str             ; If fits, proceed with buffer copy

    ; Buffer overflow handling
    call reset_buffer        ; Flush current buffer contents

    ; Check if string is larger than entire buffer
    cmp rcx, buffer_size
    ja sys_call              ; If too large, use syscall

; Copy string to output buffer
copy_str:
    mov rsi, rdi             ; RSI = source string
    lea rdi, [buffer + r8]   ; RDI = destination in buffer
    push rcx                 ; Preserve string length
    rep movsb                ; Copy RCX bytes from RSI to RDI

    ; Update buffer position
    pop rcx                  ; Restore string length
    add r8, rcx              ; Advance buffer position
    pop rdi                  ; Restore registers
    pop rsi
    jmp next_char            ; Continue format processing

; Handle oversized string (larger than buffer)
sys_call:
    ; Direct write to stdout
    mov rsi, rdi             ; RSI = string pointer (src for syscall)
    mov rdx, rcx             ; RDX = length (arg for syscall)
    mov eax, 1               ; Syscall number for write()
    mov edi, 1               ; File descriptor 1 (stdout)
    syscall                  ; Perform write operation
    jmp next_char
;--------------------------------------------------------------------------------
;Handle %d (integer) format specifier
;Entry: -
;Exit : -
;Destr:  RAX RBX RCX RDX RDI
;Calls : -
;Macros:GET_ARG, BUFFER_CHAR
;--------------------------------------------------------------------------------

case_d:
    GET_ARG                     ; Get the integer argument from stack/registers
    push rsi                    ; Save RSI
    mov rax, rcx                ; Move argument to RAX for div

    xor rcx, rcx                ; Zeroing counter to 0
    lea rdi, [buffer_int + 31]  ; Point to end of temporary buffer (32 bytes)
    mov byte [rdi], 0           ; Null-terminate the buffer

    mov rbx, 10                 ; Set divisor for base-10

    ; Handle negative numbers
    test rax, rax               ; Check sign flag
    jns .convert_loop           ; Jump if positive
    neg rax                     ; Make number positive
    BUFFER_CHAR '-'             ; Write minus sign to buffer


.convert_loop:
    xor rdx, rdx                ; Clear dividend
    div rbx                     ; RAX = result, RDX = remainder

    lea rsi, [digits]           ; Load address of digits
    mov dl, [rsi + rdx]         ; Convert remainder to ASCII

    dec rdi                     ; Move buffer pointer
    mov [rdi], dl               ; Load digit in buffer
    inc rcx                     ; Increment digit counter

    test rax, rax               ; Check if result is zero
    jnz .convert_loop           ; Continue if more digits remain


    TRANSFER_FROM_BUFFER_INT_TO_BUFFER rcx

    pop rsi
    jmp next_char
;--------------------------------------------------------------------------------------------
; Handle %o (octal) format specifier
;Entry: -
;Exit : -
;Destr:  RAX RBX RCX RDX RDI
;Calls : -
;Macros:GET_ARG ARGS_FOR_CONVERT
;-------------------------------------------------------------------------------------------
case_o:

    GET_ARG                      ; Get the octal argument from stack/registers

    ARGS_FOR_CONVERT 3

;-------------------------------------------------------------------------------
; Handle %x (hex) format specifier
;Entry: -
;Exit : -
;Destr:  RAX RBX RCX RDX RDI
;Calls : -
;Macros:GET_ARG ARGS_FOR_CONVERT
;--------------------------------------------------------------------------------
case_x:
    GET_ARG                      ;Get the hex argument from stack/registers

    ARGS_FOR_CONVERT 4

;-------------------------------------------------------------------------------
;Handle %b (binary) format specifier
;Entry: -
;Exit : -
;Destr:  RAX RBX RCX RDX RDI
;Calls : convert_number_shift
;Macros:GET_ARG ARGS_FOR_CONVERT
;--------------------------------------------------------------------------------
case_b:
    GET_ARG                      ;Get the binary argument from stack/registers

    ARGS_FOR_CONVERT 1

;-------------------------------------------------------------------------------
;Handle %%
;Entry: -
;Exit : -
;Destr: -
;Calls : -
;Macros: BUFFER_CHAR
;--------------------------------------------------------------------------------
case_per:
    BUFFER_CHAR '%'             ; add to buffer symbol %
    jmp next_char
;-------------------------------------------------------------------------------
;Handle % and not format symbol
;Entry: -
;Exit : -
;Destr: -
;Calls : -
;Macros: BUFFER_CHAR
;--------------------------------------------------------------------------------
case_def:
    BUFFER_CHAR '%'            ; add to buffer symbol %
    BUFFER_CHAR al             ; add to buffer symbol after %
    jmp next_char

;===============================================================================================================
;-------------------------------------------End of printf--------------------------------------------------------
;================================================================================================================

end_printf:
    ; Flush any remaining data in output buffer
    call reset_buffer          ; Write buffered content to stdout

    ; Determine how many argument registers we need to restore
    movzx rax, byte [arg_counter]   ; Load argument count (0-6)
    cmp rax, 5                      ; Check if we used all register args
    jae pop_5                       ; If >6 args, do full cleanup

    ; Use jump table for efficient stack cleanup
    lea rbx, [jump_table_pop] ; Load address of pop table
    jmp [rbx + rax*8]         ; Jump to appropriate cleanup routine

pop_0:
    pop rsi                   ; Restore 6th argument register
pop_1:
    pop rdx                   ; Restore 5th argument register
pop_2:
    pop rcx                   ; Restore 4th argument register
pop_3:
    pop r8                    ; Restore 3rd argument register
pop_4:
    pop r9                    ; Restore 2nd argument register
pop_5:
    pop rbp                   ; Restore frame pointer
    ret


;===============================================================================================================
;---------------------------------------------SECTION.FUNCTIONS-----------------------------------------------
;==============================================================================================================


;---------------------------------------------------------------------------
; Convert numbers
;   RAX - num
;   CL  - log2 (%o - 3, %x - 4, %b - 1)
;   RDI - pointer on buf
; Exit:
;   RCX - amount of
;------------------------------------------------------------------------------------
convert_number_shift:
    push r8                 ; Save buffer position
    xor r8, r8              ; R8 to 0
    lea rsi, [digits]       ; Load address of digits
    mov r9d, 1              ; Prepare bit mask
    shl r9, cl              ; Shift left by CL bits
    dec r9                  ; Create mask

.convert_loop:
    mov rdx, rax            ; Copy current number value
    and rdx, r9             ; Use bit mask
    mov dl, [rsi + rdx]     ; Get ASCII character
    dec rdi                 ; Decrease buffer pointer
    mov [rdi], dl           ; Load digit character in buffer
    inc r8                  ; Inc counter

    shr rax, cl             ; Shift number right to process next digit
    test rax, rax           ; Check if we've finished
    jnz .convert_loop       ; Continue if more digits remain

    mov rcx, r8             ; Return digit count in RCX
    pop r8                  ; Restore R8 (buf_pointer)

    ; Macro call to transfer digits from buffer_int to main output buffer
    TRANSFER_FROM_BUFFER_INT_TO_BUFFER rcx

    ret
;-----------------------------------------------------------------------------------------
;Function of resetting buffer
;Entry: -
;Exit : None
;Destr: EAX EDI RSI RDX
;Calls:	None
;-----------------------------------------------------------------------------------------
reset_buffer:
    mov eax, 1                  ; write (1)
    mov edi, 1                  ; (stdout)
    lea rsi, [buffer]           ; buf pointer
    mov edx, r8d                ; buf position

    syscall
    mov r8, 0                   ; reset
    ret
;------------------------------------------------------------------------------------------
;Strlen
;Entry: RCX - pointer on string
;Exit : RAX
;Destr: RAX
;Calls:	None
;-----------------------------------------------------------------------------------------
strlen:
    xor rax, rax                   ; Length counter
    str_loop:
        cmp byte [rcx + rax] , 0  ; If Null-terminate the string
        je str_end                ; End if null
        inc rax                   ; Else increase rax
    jmp str_loop
str_end:
ret
;------------------------------------------------------------------------------------------




;=================================================================================================================
;----------------------------------------------SECTION.DATA--------------------------------------------------------
;==================================================================================================================
section .data
    buffer_size equ 1024                ; Buffer_size
    buffer times buffer_size db 0       ; The main buffer

    buffer_int db 32 dup(0)
    digits db "0123456789ABCDEF"

    jump_table_format:
        dq case_def     ; 'a'
        dq case_b       ; 'b'
        dq case_c       ; 'c'
        dq case_d       ; 'd'
        dq case_def     ; 'e'
        dq case_def     ; 'f'
        dq case_def     ; 'g'
        dq case_def     ; 'h'
        dq case_def     ; 'i'
        dq case_def     ; 'j'
        dq case_def     ; 'k'
        dq case_def     ; 'l'
        dq case_def     ; 'm'
        dq case_def     ; 'n'
        dq case_o       ; 'o'
        dq case_def     ; 'p'
        dq case_def     ; 'q'
        dq case_def     ; 'r'
        dq case_s       ; 's'
        dq case_def     ; 't'
        dq case_def     ; 'u'
        dq case_def     ; 'v'
        dq case_def     ; 'w'
        dq case_x       ; 'x'
        dq case_def     ; 'y'
        dq case_def     ; 'z'
    jump_table_size equ ($ - jump_table_format) / 8 ; Amount of elements in table


    ; -----------------------------------------------------------------
    ; Jump table for register restoration
    ; Contains addresses of pop_0 through pop_5 labels
    ; Each entry is 8 bytes (64-bit pointer)
    ; -----------------------------------------------------------------
    jump_table_pop:
        dq pop_0
        dq pop_1
        dq pop_2
        dq pop_3
        dq pop_4
        dq pop_5

    arg_counter db 0              ; amount of arguments in printf

section .note.GNU-stack noalloc noexec nowrite progbits
