%define prev_word 0

%macro native 3
section .data
w_%2:
  dq prev_word
  db %1, 0
  db %3
xt_%2:
  dq %2_impl
section .text
%2_impl:
%define prev_word w_%2
%endmacro

%macro native 2
native %1, %2, 0
%endmacro

%macro colon 3
section .data
w_%2:
  dq prev_word
  db %1, 0
  db %3
xt_%2:
  dq docol
%define prev_word w_%2
%endmacro

%macro colon 2
colon %1, %2, 0
%endmacro

%define pc r15
%define w r14
%define rstack r13

native '+', plus
  pop rax
  add [rsp], rax
  jmp next

native '-', minus
  pop rax
  sub [rsp], rax
  jmp next

native '<', less
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

native 'swap', swap
  pop rax
  pop rcx
  push rax
  push rcx
  jmp next

native '.s', dump_word
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

colon '>', greater
  dq xt_swap
  dq xt_less
  dq retcol

extern string_equals
extern my_exit
extern string_length
extern print_string
extern print_string_fd
extern read_word
extern print_newline
extern print_newline_fd
extern parse_int
extern print_int
extern print_char

section .data
  last_word: dq prev_word

  program_stub: dq 0
  dummy_next: dq xt_interpreter
  xt_interpreter: dq interpreter_loop

  unknown_word: db "unknown word.", 0

  minus_text: db "-", 0
  test_string: db "hello, world", 0

section .bss
  resq 1023
  return_stack_start: resq 1 ; アドレスの低い方に向かって1024(1023+1)セル分のforthのリターンスタック
  forth_data_stack_start: resq 1 ; データスタックの先頭
  forth_memory: resq 65536
  input_buf: resb 1024

global _start
section .text

; 引数
;  rdi: 検索対象の辞書のワード名
; 戻り値
;  rax: ワードが見つかった場合、そのワードヘッダのアドレス
;       見つからなかった場合、0
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

; 引数
;  rdi: ワードヘッダのアドレス
; 戻り値
;  rax: 対象ワードの実行トークンのアドレス
cfa:
  lea r12, [rdi + 8] ;次の要素へのポインタを読み飛ばしてワード文字列のアドレスにセット
  mov rdi, r12
  call string_length
  lea r12, [r12 + rax + 1 + 1] ;r12の位置から文字列長さ + ヌル文字1byte分 + フラグ1byte分先のアドレス
  mov rax, r12
  ret

; 次のforth実行トークンを実行する
next:
  mov w, [pc]
  mov pc, 8
  jmp [w]

; コロンワードの実行から戻る
retcol:
  mov pc, [rstack]
  add rstack, 8
  jmp next

; コロンワードを実行する
docol:
  sub rstack, 8
  mov [rstack], pc
  add w, 8
  mov pc, w
  jmp next

interpreter_loop:
  mov rdi, input_buf
  call read_word
  mov rdi, rax
  call print_string
  ; 読んだ文字列の長さが0なら空文字なので終了
  cmp rdx, 0
  je .empty_word

  ; 読んだワードが辞書に登録されているかどうかチェック
  mov rdi, input_buf
  call find_word

  cmp rax, 0
  je .word_not_found
.word_found:
  mov rdi, rax
  call cfa
  mov [program_stub], rax
  mov pc, program_stub
  jmp next
.word_not_found:
  mov rdi, input_buf
  call parse_int

  ;数値としてパースできた文字列が存在するかチェック
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
  mov rstack, return_stack_start
  mov [forth_data_stack_start], rsp
  mov pc, dummy_next
  jmp next

_start:
  ; mov rdi, minus_text
  ; call find_word

  ; mov rdi, rax
  ; call cfa

  jmp init

  call my_exit
