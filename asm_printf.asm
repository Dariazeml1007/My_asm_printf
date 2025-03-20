;В 64-битных системах первые 6 аргументов передаются через регистры, а остальные — через стек.
;system V ABI
; -march=x86


section .data
    buffer_size equ 1024      ; buffer_size
    buffer times buffer_size db 0
    buffer_pos dd 0            ; position buffer

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
section .text
    global my_printf
    extern reset_buffer

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
; Macro add char to buf

%macro buffer_char 1
    mov ebx, [buffer_pos]

    mov byte [buffer + ebx], %1 ; record sym to buf
    inc ebx                   ; inc pos

    mov [buffer_pos], ebx            ; save position

    cmp ebx, buffer_size       ;
    jne %%skip_reset          ; check if need buffer reset
    call reset_buffer          ;
%%skip_reset:
%endmacro


reset_buffer:
    mov eax, 1                 ; write (1)
    mov edi, 1                 ; (stdout)
    lea rsi, [buffer]           ; buf pointer
    lea rdx, [buffer_pos]       ;
    mov edx, [rdx]             ;
    syscall
    mov dword [buffer_pos], 0         ; reset
    ret

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

next_char:
    lodsb                      ; load si to ax, inc rsi
    test al, al                ; test if end
    jz done                   ; jmp if end
    cmp al, '%'                ; check %
    je format_specifier       ; process %

    buffer_char al             ; add to buf
    jmp next_char

format_specifier:
    lodsb

    cmp al, '%'
    je case_per
    sub al, 'a'
    movzx rax, al
    cmp rax, jump_table_size
    jae case_def

    lea rbx, [jump_table_format]
    jmp [rbx + rax*8]

case_c:
    GET_ARG
    buffer_char cl
    jmp next_char

case_s:
    GET_ARG
    push rsi
    push rdi

    mov rdi, rcx             ; rdi = source
    call strlen              ; rax = length
    mov rcx, rax

    mov ebx, [buffer_pos]
    add rax, rbx
    cmp rax, buffer_size
    jbe copy_str


    call reset_buffer
    mov ebx, [buffer_pos]
copy_str:
    mov rsi, rdi
    lea rdi, [buffer + ebx]
    push rcx
    rep movsb

    pop rcx
    add [buffer_pos], ecx
    pop rdi

    pop rsi
    jmp next_char


case_d:
     jmp next_char

case_x:
    jmp next_char

case_o:
    jmp next_char

case_per:
    buffer_char '%'
    jmp next_char

case_def:
    buffer_char '%'
    buffer_char al             ; add to buf
    jmp next_char



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

strlen:
    xor rax, rax ; length counter
    str_loop:
        cmp byte [rcx + rax] , 0
        je str_end
        inc rax
    jmp str_loop
str_end:
ret

section .note.GNU-stack noalloc noexec nowrite progbits
