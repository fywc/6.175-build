#!/bin/bash

ELF2HEX=/opt/riscv/bin/elf2hex
TRANSLATOR=../trans_vmh_bmark.py

echo "Converting binary files to VMH format..."

# Traverse all binary files in the benchmarks/bin directory
for file in benchmarks/bin/*
do
  # Get the filename and basename (without extension)
  filename=$(basename -- "$file")
  basename="${filename%.*}"

  echo "Converting $filename..."

  # Convert ELF file to HEX file using elf2hex program
  $ELF2HEX 8 65536 $file >> benchmarks/vmh/temp

  # Convert HEX file to VMH file using trans_vmh.py script
  $TRANSLATOR benchmarks/vmh/temp benchmarks/vmh/$basename.riscv.vmh

  echo "$filename done."
done

echo "Conversion complete"

~                                                                                                                                                                                                                                                                                                 
~                                                