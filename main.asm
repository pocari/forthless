%define PREV_WORD 0
%define MODE_COMPILE 1
%define MODE_INTERPRETER 0
%define WORD_FLAG_IMMEDIATE 0x01

%macro native 3
section .data
w_%2:
  dq PREV_WORD
  db %1, 0
  db %3
xt_%2:
  dq %2_impl
section .text
%2_impl:
%define PREV_WORD w_%2
%endmacro

%macro native 2
native %1, %2, 0
%endmacro

%macro colon 3
section .data
w_%2:
  dq PREV_WORD
  db %1, 0
  db %3
xt_%2:
  dq docol
%define PREV_WORD w_%2
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

native '*', multiple
  pop rdi
  pop rax
  mul rdi
  push rax
  jmp next

native '/', divide
  xor rax, rax
  xor rdx, rdx
  pop rdi
  pop rax
  idiv rdi
  push rax
  jmp next

native '<', less
  pop rax
  pop rcx
  cmp rcx, rax
  jl .true
.false:
  push qword 0
  jmp .end
.true:
  push qword 1
.end:
  jmp next

native '=', equals
  pop rax
  pop rdi
  cmp rax, rdi
  je .equal
.not_equal:
  push qword 0
  jmp .end
.equal:
  push qword 1
.end:
  jmp next

native 'swap', swap
  pop rax
  pop rcx
  push rax
  push rcx
  jmp next

native '.s', dump_word
  mov r8, [forth_data_stack_start]
  sub r8, 8
.loop:
  cmp r8, rsp
  jb .end
  mov rdi, [r8]
  push r8
  call print_int
  mov rdi, ' '
  call print_char
  pop r8
  lea r8, [r8 - 8]
  jmp .loop
.end:
  call print_newline
  jmp next

native 'and', op_and
  pop rax
  pop rdi
  cmp rax, 0
  je .false
  cmp rdi, 0
  je .false
.true:
  push qword 1
  jmp .end
.false:
  push qword 0
.end:
  jmp next

native 'not', op_not
  pop rax
  cmp rax, 0
  je .true
.false:
  push qword 0
  jmp .end
.true:
  push qword 1
.end:
  jmp next

native 'rot', rot
   pop rax
   pop rdi
   pop rcx
   push rdi
   push rax
   push rcx
   jmp next

native 'dup', dup
   pop rax
   push rax
   push rax
   jmp next

native 'drop', drop
   pop rax
   jmp next

native '.', pop_print
   pop rdi
   call print_int
   call print_newline
   jmp next

native 'key', key
  call read_char
  and rax, 0xff
  push rax
  jmp next

native 'emit', emit
  pop rdi
  call print_char
  call print_newline
  jmp next

native 'number', number
  mov rdi, input_buf
  mov rsi, 1024
  call read_word
  cmp rdx, 0
  jne .read
  ; 読めなかったので終わる
  jmp next

.read:
  mov rdi, rax ; 読んだwordへのポインタ
  call parse_int
  cmp rdx, 0
  jne .read_number
  ; パースできなければ終わる
  jmp next
.read_number:
  push rax
  jmp next

native 'mem', push_mem
  push forth_memory
  jmp next

native '!', stack_to_mem_cell
  xor rax, rax
  xor rdx, rdx
  pop rax
  pop rdx
  mov [rdx], rax
  jmp next

native '@', mem_cell_to_stack
  xor rax, rax
  pop rax
  push qword [rax]
  jmp next

native 'c!', stack_to_mem_byte
  xor rax, rax
  xor rdx, rdx
  pop rax
  pop rdx
  and rax, 0xff
  mov [rdx], ax
  jmp next

; これよくわからない
native 'c@', mem_byte_to_stack
  xor rax, rax
  pop rax
  push qword [rax]
  jmp next

native ':', compile_start
  mov rdi, input_buf
  mov rsi, 1024
  call read_word

  ; 前のワードセット
  xor r12, r12
  mov r12, [here]
  mov rcx, [last_word]
  mov qword [r12], rcx

  ; このワードの文字列をセット
  push rdx ; read_wordで読んだ文字列長を退避
  mov rdi, input_buf
  lea rsi, [r12 + 8] ; PREV_WORDの次の項目にワード文字列をセット
  mov rdx, 1024  ;適当にサイズ指定(input_bufが最大収まる感じにする)
  call string_copy
  pop rdx

  ; フラグセット
  mov byte [r12 + 8 + rdx + 1], 0 ; 前のワードへのポインタサイズ(8) + このワードの文字列(rdx + 1)の次にセット

  ; docolセット
  mov qword [r12 + 8 + rdx + 1 + 1], docol

  ; here 更新
  lea rcx,  [r12 + 8 + rdx + 1 + 1 + 8]
  mov [here], rcx

  ; last_word更新
  mov [last_word], r12

  ; compileモードに遷移
  mov qword [state], MODE_COMPILE

  jmp next

native ';', compile_end, WORD_FLAG_IMMEDIATE
  xor rcx, rcx

  ; 今compile中のワードの定義が終了するのでretcolする
  mov r12, [here]
  mov qword [r12], xt_retcol

  ; here更新
  lea rcx, [r12 + 8]
  mov [here], rcx
  ; interpreterモードに戻る
  mov qword [state], MODE_INTERPRETER
  jmp next

native 'lit', lit
  ; この命令自体の次のpcの位置にスタックに積むべき数値があるのでそれを取得
  push qword [pc]
  ; プログラムカウンタも変更する
  add pc, 8
  jmp next

colon '>', greater
  dq xt_swap
  dq xt_less
  dq xt_retcol

; andとnotでorを実装する
; a or b = not((not a) and (not b))
colon 'or', op_or
  dq xt_op_not
  dq xt_swap
  dq xt_op_not
  dq xt_op_and
  dq xt_op_not
  dq xt_retcol

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
extern read_char
extern string_copy

section .data
  program_stub: dq 0
  dummy_next: dq xt_main_loop
  xt_main_loop: dq main_loop

  unknown_word: db "unknown word.", 0

  minus_text: db "-", 0
  test_string: db "hello, world", 0

section .bss
  resq 1023
  return_stack_start: resq 1 ; アドレスの低い方に向かって1024(1023+1)セル分のforthのリターンスタック
  forth_data_stack_start: resq 1 ; データスタックの先頭
  forth_memory: resq 65536 ; ユーザ用メモリ
  forth_word_memory: resq 65536 ; ユーザ定義ワード用のメモリ
  here: resq 1 ; forth_word_memoryの最初の空きメモリへのポインタ
  last_word: resq 1 ; 最後のワードへのポインタ
  state: resq 1
  input_buf: resb 1024 ; read_wordの読み込みバッファ

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
;  rdx: このトークンのフラグ値
cfa:
  lea r12, [rdi + 8] ;次の要素へのポインタを読み飛ばしてワード文字列のアドレスにセット
  mov rdi, r12
  call string_length
  xor rdx, rdx
  lea rdx, [r12 + rax + 1] ;r12の位置から文字列長さ + ヌル文字1byte分
  lea rax, [rdx + 1] ;フラグから1byte分先のアドレス
  mov rdx, [rdx] ; rdxにはフラグの値自体をセット
  and rdx, 0xff ;1byteのみ取る
  ret

; 次のforth実行トークンを実行する
next:
  mov w, [pc]
  add pc, 8
  jmp [w]

; コロンワードの実行から戻る
xt_retcol:
  dq retcol_impl
retcol_impl:
  mov pc, [rstack]
  add rstack, 8
  jmp next

; コロンワードを実行する
docol:
  sub rstack, 8
  mov [rstack], pc
  add w, 8 ; この時点のwはdocolを呼んだ場所のアドレスがセットされている
  mov pc, w
  jmp next

main_loop:
  cmp qword [state], MODE_INTERPRETER
  je .exec_interpreter
.exec_compiler:
  jmp compiler_loop
.exec_interpreter:
  jmp interpreter_loop

compiler_loop:
  ; ワードを読む
  mov rdi, input_buf
  mov rsi, 1024
  call read_word
  mov rdi, rax

  ; 読んだ文字列の長さが0なら空文字なので終了
  cmp rdx, 0
  je .empty_word

  ; 読んだワードが辞書に登録されているかどうかチェック
  mov rdi, input_buf
  call find_word

  cmp rax, 0
  je .word_not_found
.word_found:
  ; 読んだワード(rax)に対応するxtを検索
  mov rdi, rax
  call cfa
  cmp rdx, WORD_FLAG_IMMEDIATE
  je .run_immediate
.run_not_immediate:
  mov r12, [here]
  mov [r12], rax
  lea rcx, [r12 + 8]
  mov [here], rcx
  jmp compiler_loop

.run_immediate:
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
  mov r12, [here]
  mov qword [r12], xt_lit ;数字をstackに積むためのxt_lit命令をセット

  ; hereを更新
  lea rcx, [r12 + 8]
  mov [here], rcx

  mov r12, [here]
  mov [r12], rax ; xt_litでstckに積む文字をセット

  ; hereを更新
  lea rcx, [r12 + 8]
  mov [here], rcx

  jmp main_loop
.not_number:
  mov rdi, unknown_word
  mov rsi, 2
  call print_string_fd
  mov rdi, 2
  call print_newline_fd
  jmp my_exit
.empty_word:
  jmp my_exit

interpreter_loop:
  ; ワードを読む
  mov rdi, input_buf
  mov rsi, 1024
  call read_word
  mov rdi, rax

  ; 読んだワードをechoする
  push rdx ; read_wordで読んだ文字数退避
  call print_string
  call print_newline
  pop rdx
  ; 読んだ文字列の長さが0なら空文字なので終了
  cmp rdx, 0
  je .empty_word

  ; 読んだワードが辞書に登録されているかどうかチェック
  mov rdi, input_buf
  call find_word

  cmp rax, 0
  je .word_not_found
.word_found:
  ; 読んだワード(rax)に対応するxtを検索
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
  jmp main_loop
.not_number:
  mov rdi, unknown_word
  mov rsi, 2
  call print_string_fd
  mov rdi, 2
  call print_newline_fd
  jmp my_exit
.empty_word:
  jmp my_exit

init:
  mov rstack, return_stack_start
  mov [forth_data_stack_start], rsp
  mov pc, dummy_next
  mov qword [here], forth_word_memory
  mov qword [last_word], PREV_WORD
  mov qword [state], MODE_INTERPRETER
  jmp next

_start:
  ; mov rdi, minus_text
  ; call find_word

  ; mov rdi, rax
  ; call cfa

  jmp init

  call my_exit
