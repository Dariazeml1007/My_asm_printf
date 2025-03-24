;В 64-битных системах первые 6 аргументов передаются через регистры, а остальные — через стек.
;system V ABI
; -march=x86

section .text
    global my_printf
    extern reset_buffer
;------------------------------------------------------------------------------------------------
;Macro get argument from stack
;Entry: -
;Exit : RCX - arg
;Destr: RAX RCX
;Calls:	None
;-------------------------------------------------------------------------------------------------
%macro GET_ARG 0
    movzx rax, byte [arg_counter]
    inc al
    mov byte [arg_counter], al
    cmp al, 6
    jae %%stk
    pop rcx
    jmp %%add_to_buf
%%stk:
    mov rcx, [rbp]
    add rbp, 8
%%add_to_buf:
%endmacro
;-------------------------------------------------------------------------------------
; Macro add char to buf
;Entry: -
;Exit : -
;Destr: -
;Calls:	reset_buffer
;------------------------------------------------------------------------------------
%macro BUFFER_CHAR 1

   ; mov rbx, [buffer_pos]

    mov byte [buffer + r8], %1 ; record sym to buf
    inc r8                 ; inc pos

    cmp r8, buffer_size       ;
    jne %%skip_reset          ; check if need buffer reset
    call reset_buffer          ;
%%skip_reset:

%endmacro

;----------------------------------------------------------------------------------------------------------
;-----------------------------------------MY_PRINTF------------------------------------------------------
;---------------------------------------------------------------------------------------------------
my_printf:

    push rbp
    mov rbp, rsp
    add rbp, 16

    push r9
    push r8
    push rcx
    push rdx
    push rsi

    mov rsi, rdi               ; format pointer
    xor r8, r8




next_char:
    lodsb                      ; load si to ax, inc rsi
    test al, al                ; test if end
    jz done                   ; jmp if end
    cmp al, '%'                ; check %
    je format_specifier       ; process %

    BUFFER_CHAR al             ; add to buf
    jmp next_char

format_specifier:
    lodsb

    cmp al, '%'
    je case_per
    mov bl, al
    sub bl, 'a'
    movzx rbx, bl
    cmp rbx, jump_table_size
    jae case_def

    lea rcx, [jump_table_format]
    jmp [rcx + rbx*8]

;-------------------------------------------------------------------------------
;Process %c
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
;Process %s
;Entry: -
;Exit : -
;Destr:  RAX RBX RCX
;Calls : strlen, reset_buffer, syscall
;Macros:GET_ARG
;-------------------------------------------------------------------------------
case_s:
    GET_ARG
    push rsi
    push rdi

    mov rdi, rcx             ; rdi = source
    call strlen              ; rax = length
    mov rcx, rax

    mov rbx, [r8]   ; buffer pos
    add rax, rbx
    cmp rax, buffer_size
    jbe copy_str


    call reset_buffer
    mov rbx, [r8]
    cmp rcx, buffer_size
    ja sys_call

copy_str:
    mov rsi, rdi
    lea rdi, [buffer + rbx]
    push rcx
    rep movsb

    pop rcx
    add r8 , rcx ;buffer pos

    pop rdi
    pop rsi
    jmp next_char

sys_call :

    mov rsi, rdi             ; rsi = source
    mov rdx, rcx             ; rdx = length
    mov eax, 1               ; syscall: write
    mov edi, 1               ; file descriptor: stdout
    syscall
    jmp next_char
;--------------------------------------------------------------------------------
;Process %d
;Entry: -
;Exit : -
;Destr:  RAX RBX RCX RDX RDI
;Calls : -
;Macros:GET_ARG, BUFFER_CHAR
;--------------------------------------------------------------------------------

case_d:
    GET_ARG
    push rsi
    mov rax, rcx

    xor rcx, rcx                ; Counter
    lea rdi, [buffer_int + 31]  ; Pointer on end of buffer_int

    mov rbx, 10

    test rax, rax               ; if < 0
    jns .convert_loop
    not rax
    inc rax
    BUFFER_CHAR '-'          ; Add - in buff

.convert_loop:
    xor rdx, rdx
    div rbx                  ; Div rax by 10 (res in rax, num in  rdx)
    add dl, '0'              ; Transfer to symbol
    dec rdi
    mov [rdi], dl            ; Save symbol to buffer_int
    inc rcx                  ; Increase counter
    test rax, rax            ;IF zero
    jnz .convert_loop


    mov rsi, rdi             ; Start of num in buffer_int
    mov rdx, rcx             ; Length !

    lea rdi, [buffer + r8]  ; Pointer on buffer

    rep movsb

    add r8, rdx    ; New position in buf

    pop rsi
    jmp next_char


;--------------------------------------------------------------------------------
case_x:
    jmp next_char
;---------------------------------------------------------------------------------
case_o:
    jmp next_char
;--------------------------------------------------------------------------------
case_per:
    BUFFER_CHAR '%'
    jmp next_char
;-----------------------------------------------------------------------------------
case_def:
    BUFFER_CHAR '%'
    BUFFER_CHAR al             ; add to buf
    jmp next_char

;--------------------------------------------------------------------------------------------------
;------------------------------End of printf--------------------------------------------------------
;---------------------------------------------------------------------------------------------------
done:
    call reset_buffer
    movzx rax, byte [arg_counter]
    cmp rax, 5
    jae pop_5

    lea rbx, [jump_table_pop]
    jmp [rbx + rax*8]

pop_0:
    pop rsi
pop_1:
    pop rdx
pop_2:
    pop rcx
pop_3:
    pop r8
pop_4:
    pop r9
pop_5:
    pop rbp
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
    xor rax, rax ; length counter
    str_loop:
        cmp byte [rcx + rax] , 0
        je str_end
        inc rax
    jmp str_loop
str_end:
ret
;------------------------------------------------------------------------------------------
section .data
    buffer_size equ 1024      ; buffer_size
    buffer times buffer_size db 0

    buffer_int db 32 dup(0)
    numbers db "0123456789ABCDEF"

    jump_table_format:
        dq case_def     ; 'a'
        dq case_def     ; 'b'
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


    jump_table_pop:
        dq pop_0
        dq pop_1
        dq pop_2
        dq pop_3
        dq pop_4
        dq pop_5

    arg_counter db 0

section .note.GNU-stack noalloc noexec nowrite progbits
