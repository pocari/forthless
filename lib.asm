%define O_RDONLY 0
%define PROT_READ 0x1
%define MAP_PRIVATE 0x2

global my_exit
global string_length
global print_string
global print_string_fd
global print_char
global print_char_fd
global print_newline
global print_newline_fd
global print_uint
global print_int
global string_equals
global read_char
global read_word
global read_line
global parse_uint
global parse_int
global string_copy

section .text
my_exit:
    mov rax, 60
    syscall

; rdi 文字列へのポインタ
string_length:
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0 ;バイト単位で比較する必要があるのでbyteが要る
    je .end
    inc rax
    jmp .loop
.end:
    ret ; この時点でraxに文字列長がセットされている

; rdi 文字列へのポインタ
print_string:
    mov rsi, 1
    jmp print_string_fd

print_string_fd:
    push rsi
    push rdi ; rdiを渡すので退避
    call string_length ; rdiに渡ってきている文字列へのポインタをそのまま渡し, raxにサイズがセットされている
    pop rdi  ; 退避していたもともとのrdiを戻す
    pop rsi

    mov rdx, rax ; writeの三番目の引数 文字列長
    mov rax, 1 ; write syscall no
    push rsi
    mov rsi, rdi ; writeの第二引数文字列へのポインタ
    pop rdi
    syscall
    ret

print_char:
    mov rsi, 1
    jmp print_char_fd

print_char_fd:
    mov r8, rsi
    push rdi ; 渡された文字コードをスタックに積む
    mov rsi, rsp ;文字コードを積んだ場所へのポインタをwriteの第二引数にセット
    mov rdi, r8  ; writeの第一引数 fd
    mov rdx, 1  ; writeの第三引数 charの出力なのでサイズは1固定
    mov rax, 1  ; write syscall no
    syscall
    pop rdi
    ret

print_newline:
    mov rsi, 1
    jmp print_newline_fd

print_newline_fd:
    mov rsi, rdi
    mov rdi, 0x000000000000000A
    jmp print_char_fd

; rdi 表示対象の8バイト符号なし整数
print_uint:
    mov rax, rdi
    mov rdi, rsp
    push 0        ; 8byte整数の0をスタックに積む
    sub rsp, 16   ; 更にスタックポインタを16byte減らして、計(8+16)=24byte確保する

    dec rdi       ; この位置が文字列末尾の\0文字になる
    mov r8, 10
.loop:
    xor rdx, rdx  ; 余りがセットされるレジスタクリア
    div r8        ; rax / 10を計算し、 商をrax, 余りをrdxにセット
    or dl, 0x30   ; rdxの下位8bitのdlにセットされている余り(数値)をasciコードに変換(dl = dl + 0x30) 数字の0はアスキーの0x30
    dec rdi       ; 次の文字書き込み位置をセット
    mov [rdi], dl ; 文字書き込み
    test rax, rax    ; 商が0になったら終了
    jnz .loop     ; ゼロじゃなかったら(jnz)繰り返す

    call print_string

    add rsp, 24   ; 確保したスタックをクリア
    ret


; rdi 表示対象の8バイト符号あり整数
print_int:
    test rdi, rdi ;testで同一レジスタを比較しSFフラグを更新する。これで正の場合にjns(jump no sign)で飛ばすのがイディオムの用
    jns print_uint ; 符号無しならすでにあるprint_uintにジャンプ.callじゃなくてjumpして、呼び先のretでもどるみたい。

    push rdi      ; 符号を表示するためにrdi退避
    mov rdi, '-'
    call print_char
    pop rdi
    neg rdi          ; rdiを正の数に変換
    jmp print_uint

; 引数
; rdi 文字列1へのポインタ
; rsi 文字列2へのポインタ
;
; 戻り値
; rax 等しければ1, それ以外は0
string_equals:
    xor rax, rax

.loop:
    mov r8, [rdi + rax]
    mov r9, [rsi + rax]

    ; 下位8bitのみ取り出す
    and r8, 0xff
    and r9, 0xff

    cmp r8, r9
    jne .not_equal ; 等しくなければ0を返す

    cmp r8, 0
    jne .next       ; 等しくてかつnull文字じゃなければ次の文字へ

    ;ここに来たら等しくて同じタイミングでnull文字になった
    ; => 文字列の最後まで同じ文字だった=同じ文字列だった
    mov rax, 1
    ret
.next:
    inc rax
    jmp .loop
.not_equal:
    xor rax, rax
    ret

; 引数無し
read_char:
    sub rsp, 1 ; 読み込んだ1byte格納用にスタックに1byte確保
    mov rsi, rsp ; readの第二引数確保した場所へのポインタ取得
    ; read システムコールメモ
    ; rax: 0 システムコール番号
    ; 1: 読み込むファイルディスクリプタ
    ; 2: 読んだ文字を格納するバッファへのポインタ
    ; 3: 読み出すバイト数
    mov rdi, 0 ; 第一引数: stdinのfd
    mov rdx, 1 ; 第三引数: 読み込むバイト数
    mov rax, 0 ; readのシステムコール番号
    syscall

    test rax, -1
    je .eof
    mov rax, [rsp]
    jmp .end
.eof:
    mov rax, 0
.end:
    add rsp, 1
    ret

; 引数
; rdi 読み込みたいバッファへのアドレス
; rsi そのバッファのサイズ

; 戻り値
; rax 正常に読んだ場合、バッファへのアドレス, バッファが足りなかった場合 0
; rdx 読み込んだwordの長さ
read_word:
    xor r8, r8; ループカウンタ
.loop:
    push rdi
    push rsi
    push r8
    call read_char ; 一文字取得
    pop r8
    pop rsi
    pop rdi
    cmp rax, 0  ; eofかどうか(raxが0かどうか)チェック
    je .eof        ; rax & raxが0なら(jz) eofだったので.eofにジャンプ

    cmp al, 0x20  ; 半角スペース
    je .space
    cmp al, 0x09  ; 半角タブ
    je .space
    cmp al, 0x0a  ; lf
    je .space
    cmp al, 0x0d  ; cr
    je .space

    ; wordの構成文字の場合

    ; バッファのサイズを超える場合
    cmp r8, rsi
    jae .overflow

    ; バッファに文字をコピー
    mov byte [rdi + r8], al
    inc r8
    jmp .loop
.space:
    cmp r8, 0
    je .loop ; まだwordになる文字を一文字も読んでいなければ読み飛ばし
    mov byte [rdi + r8], 0; 最後にnull文字設定
    mov rax, rdi; 読み込んだバッファへのポインタ
    mov rdx, r8; 文字列長
    jmp .end
.eof:
    mov byte [rdi + r8], 0; 最後にnull文字設定
    mov rax, rdi; 読み込んだバッファへのポインタ
    mov rdx, r8; 文字列長
    jmp .end
.overflow:
    mov rax, 0; 無効なアドレスを設定
    mov rdx, r8; 文字列長
    jmp .end
.end:
    ret

; 引数
; rdi 読み込みたいバッファへのアドレス
; rsi そのバッファのサイズ

; 戻り値
; rax 正常に読んだ場合、バッファへのアドレス, バッファが足りなかった場合 0
; rdx 読み込んだwordの長さ
read_line:
    xor r8, r8; ループカウンタ
.loop:
    push rdi
    push rsi
    push r8
    call read_char ; 一文字取得
    pop r8
    pop rsi
    pop rdi
    cmp rax, 0  ; eofかどうか(raxが0かどうか)チェック
    je .eos        ; rax & raxが0なら(jz) eofだったので.eofにジャンプ

    cmp al, 0x0a  ; lf
    je .eos

    ; wordの構成文字の場合

    ; バッファのサイズを超える場合
    cmp r8, rsi
    jae .overflow

    ; バッファに文字をコピー
    mov byte [rdi + r8], al
    inc r8
    jmp .loop
.space:
    cmp r8, 0
    je .loop ; まだwordになる文字を一文字も読んでいなければ読み飛ばし
    mov byte [rdi + r8], 0; 最後にnull文字設定
    mov rax, rdi; 読み込んだバッファへのポインタ
    mov rdx, r8; 文字列長
    jmp .end
.eos:
    mov byte [rdi + r8], 0; 最後にnull文字設定
    mov rax, rdi; 読み込んだバッファへのポインタ
    mov rdx, r8; 文字列長
    jmp .end
.overflow:
    mov rax, 0; 無効なアドレスを設定
    mov rdx, r8; 文字列長
    jmp .end
.end:
    ret

; 引数
; rdi 数値文字列へのポインタ
; 戻り値
; rax パースした数値
; rdx パースした文字数(数値の桁数)
parse_uint:
    xor rax, rax
    xor r9, r9
    mov r8, 10
.loop:
    ; 最終的にrdxにパースした文字を返すのでrdxをオフセットにしてもいいが、
    ; mulの計算時にrdxを退避する必要があるので、r9で計算しておいて、最後にrdxにセットする
    mov rcx, [rdi + r9]
    and rcx, 0xff
    ;読んだ文字をxとすると;
    cmp rcx, 0
    je .end     ; 文字列の最後まで来てたら終了

    cmp rcx, '0'
    jl .end ; x < '0' なら無効な文字なので終了

    cmp rcx, '9'
    jg .end ; x > '9' なら無効な文字なので終了

    sub rcx, 0x30  ; 文字を数値に変換 ('0' = 0x30)
    mul r8        ; rax = rax * 10 raxを1桁繰り上げ
    add rax, rcx  ; 読み込んだ一桁目を足す

    inc r9
    jmp .loop
.end:
    mov rdx, r9
    ret

; 引数
; rdi 数値文字列へのポインタ
; 戻り値
; rax パースした数値
; rdx パースした文字数(数値の桁数)
parse_int:
    cmp byte [rdi], '-'
    jne parse_uint ; 先頭が-じゃなかったらparse_uintに丸投げ

    ; 先頭が'-'で始まっている場合
    add rdi, 1      ; '-'の次の文字にポインタ移動
    call parse_uint ; 符号無しとしてパースする
    neg rax         ; パースした数値の負の数が返すべき値
    inc rdx         ; パースした文字数も符号文字分、1増やしておく
    ret

; rdi src文字列へのポインタ
; rsi destバッファへのポインタ
; rdx destバッファのサイズ
string_copy:
    push rdi ;rdiをstring_lengthにわたすので退避
    call string_length ; raxに文字列長がセットされている
    inc rax ;文字列最後のnull文字用の1バイト考慮
    pop rdi ; 退避していた、src文字列へのポインタを復元

    cmp rax, rdx ; src文字列とバッファの長さ比較 rax:src文字列長, rdx: destバッファ長
    ja .too_short_end ; src文字列のほうが長かった場合
.loop:
    mov rcx, [rdi + rax] ; 一文字srcからコピー
    mov [rsi + rax], rcx ; コピーした文字をdestに設定

    cmp rax, 0
    je .end

    dec rax
    jmp .loop
.too_short_end:
    mov rax, 0
    ret
.end:
    mov rax, rsi ; コピー先の先頭アドレスを返す
    ret
