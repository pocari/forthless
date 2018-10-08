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

command="\
1
2
+
.
"
expect "$command" "3"

command="\
1
2
-
.
"
expect "$command" "-1"

command="\
1
dup
.s
"
expect "$command" "1 1"
echo

