#!/bin/bash

ELF2HEX=/opt/riscv/bin/elf2hex
TRANSLATOR=../trans_vmh.py

echo "Converting binary files to VMH format..."

# Traverse all binary files in the assembly/bin directory
for file in assembly/bin/*
do
  # Get the filename and basename (without extension)
  filename=$(basename -- "$file")
  basename="${filename%.*}"

  echo "Converting $filename..."

  # Convert ELF file to HEX file using elf2hex program
  $ELF2HEX 8 2048 $file >> assembly/vmh/temp

  # Convert HEX file to VMH file using trans_vmh.py script
  $TRANSLATOR assembly/vmh/temp assembly/vmh/$basename.riscv.vmh

  echo "$filename done."
done

echo "Conversion complete"