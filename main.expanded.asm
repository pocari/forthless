%line 2+1 main.asm

%line 15+1 main.asm

%line 19+1 main.asm

%line 30+1 main.asm

%line 34+1 main.asm

%line 38+1 main.asm

[section .data]
%line 39+0 main.asm
w_plus:
 dq 0
 db '+', 0
 db 0
xt_plus:
 dq plus_impl
[section .text]
plus_impl:
%line 40+1 main.asm
 pop rax
 add [rsp], rax
 jmp next

[section .data]
%line 44+0 main.asm
w_minus:
 dq w_plus
 db '-', 0
 db 0
xt_minus:
 dq minus_impl
[section .text]
minus_impl:
%line 45+1 main.asm
 pop rax
 sub [rsp], rax
 jmp next

[section .data]
%line 49+0 main.asm
w_less:
 dq w_minus
 db '<', 0
 db 0
xt_less:
 dq less_impl
[section .text]
less_impl:
%line 50+1 main.asm
 pop rax
 pop rcx
 cmp rcx, rax
 jl .true
.true:
 push qword 1
 jmp .end
.false:
 push qword 0
.end:
 jmp next

[section .data]
%line 62+0 main.asm
w_swap:
 dq w_less
 db 'swap', 0
 db 0
xt_swap:
 dq swap_impl
[section .text]
swap_impl:
%line 63+1 main.asm
 pop rax
 pop rcx
 push rax
 push rcx
 jmp next

[section .data]
%line 69+0 main.asm
w_dump_word:
 dq w_swap
 db '.s', 0
 db 0
xt_dump_word:
 dq dump_word_impl
[section .text]
dump_word_impl:
%line 70+1 main.asm
 mov r8, forth_data_stack_start
.loop:
 cmp r8, rsp
 je .end
 mov rdi, [r8]
 call print_int
 mov rdi, 0x20
 call print_char
 lea r8, [r8 + 8]
 jmp r8
.end:
 ret

[section .data]
%line 83+0 main.asm
w_greater:
 dq w_dump_word
 db '>', 0
 db 0
xt_greater:
 dq docol
%line 84+1 main.asm
 dq xt_swap
 dq xt_less
 dq retcol

[extern string_equals]
[extern my_exit]
[extern string_length]
[extern print_string]
[extern print_string_fd]
[extern read_word]
[extern print_newline]
[extern print_newline_fd]
[extern parse_int]
[extern print_int]
[extern print_char]

[section .data]
 last_word: dq w_greater

 program_stub: dq 0
 dummy_next: dq xt_interpreter
 xt_interpreter: dq interpreter_loop

 unknown_word: db "unknown word.", 0

 minus_text: db "-", 0
 test_string: db "hello, world", 0

[section .bss]
 resq 1023
 return_stack_start: resq 1
 forth_data_stack_start: resq 1
 forth_memory: resq 65536
 input_buf: resb 1024

[global _start]
[section .text]






find_word:
 mov r12, [last_word]
.loop:
 cmp r12, 0
 je .not_found
 lea rsi, [r12 + 8]
 call string_equals
 cmp rax, 1
 jz .found
.next_word:
 mov r12, [r12]
 jmp .loop
.found:
 mov rax, r12
 ret
.not_found:
 xor rax, rax
 ret





cfa:
 lea r12, [rdi + 8]
 mov rdi, r12
 call string_length
 lea r12, [r12 + rax + 1 + 1]
 mov rax, r12
 ret


next:
 mov r14, [r15]
 mov r15, 8
 jmp [r14]


retcol:
 mov r15, [r13]
 add r13, 8
 jmp next


docol:
 sub r13, 8
 mov [r13], r15
 add r14, 8
 mov r15, r14
 jmp next

interpreter_loop:
 mov rdi, input_buf
 call read_word

 cmp rdx, 0
 je .empty_word


 mov rdi, input_buf
 call find_word

 cmp rax, 0
 je .word_not_found
.word_found:
 mov rdi, rax
 call cfa
 mov [program_stub], rax
 mov r15, program_stub
 jmp next
.word_not_found:
 mov rdi, input_buf
 call parse_int


 cmp rdx, 0
 je .not_number
.read_number:
 push rax
 ret
.not_number:
 mov rdi, unknown_word
 mov rsi, 2
 call print_string_fd
 mov rdi, 2
 call print_newline_fd
 ret
.empty_word:
 ret

init:
 mov r13, return_stack_start
 mov [forth_data_stack_start], rsp
 mov r15, dummy_next
 jmp next

_start:






 jmp init

 call my_exit
