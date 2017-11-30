#!/bin/bash

while getopts ":nsg" opt
do
case $opt in
n) echo "get next";;
s) echo "set";;
g) echo "get";;
esac
done
