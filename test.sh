#!/bin/bash

function success() {
  echo -n -e "\e[32m$*\e[m"
}

function fail() {
  echo -e "\e[31m$*\e[m"
}

function expect() {
  local script="$1"
  local expected="$2"

  result=$(echo "$1" | ./main | tail -2 | head -1 | sed 's/  *$//g')
  # echo $result

  if [ "$expected" = "$result" ] ; then
    success .
  else
    fail NG expected ["$expected"], but returns ["$result"]
    fail test command
    fail "$script"
  fi
}

#--------------------------
command="\
1
2
+
.
"
expect "$command" "3"

#--------------------------
command="\
1
2
-
.
"
expect "$command" "-1"

#--------------------------
command="\
1
dup
.s
"
expect "$command" "1 1"

#--------------------------
command="\
2
3
*
.
"
expect "$command" "6"

#--------------------------
command="\
10
2
/
.
"
expect "$command" "5"

#--------------------------
command="\
1
2
<
.
"
expect "$command" "1"


#--------------------------
command="\
2
1
<
.
"
expect "$command" "0"

#--------------------------
command="\
2
2
=
.
"
expect "$command" "1"

#--------------------------
command="\
2
3
=
.
"
expect "$command" "0"

#--------------------------
command="\
2
3
swap
.s
"
expect "$command" "3 2"

#--------------------------
command="\
2
3
swap
swap
.s
"
expect "$command" "2 3"

#--------------------------
command="\
1
1
and
.
"
expect "$command" "1"

#--------------------------
command="\
0
1
and
.
"
expect "$command" "0"

#--------------------------
command="\
1
0
and
.
"
expect "$command" "0"

#--------------------------
command="\
0
0
and
.
"
expect "$command" "0"

#--------------------------
command="\
0
not
.
"
expect "$command" "1"

#--------------------------
command="\
1
not
.
"
expect "$command" "0"

#--------------------------
command="\
1
2
3
rot
.s
"
expect "$command" "2 3 1"


#--------------------------
command="\
1
2
3
drop
.s
"
expect "$command" "1 2"

#--------------------------
command="\
mem
3
!
2
mem
@
+
.
"
expect "$command" "5"

#--------------------------
command="\
1
1
or
.
"
expect "$command" "1"

#--------------------------
command="\
0
1
or
.
"
expect "$command" "1"

#--------------------------
command="\
1
0
or
.
"
expect "$command" "1"

#--------------------------
command="\
0
0
or
.
"
expect "$command" "0"

#--------------------------
command="\
1
2
>
.
"
expect "$command" "0"

#--------------------------
command="\
2
1
>
.
"
expect "$command" "1"

#--------------------------
command="\
: my_dup dup ;
3
dup
.s
"
expect "$command" "3 3"

#--------------------------
command="\
: my_command rot - + ;
5
3
1
my_command
.
"
expect "$command" "-1"

echo

