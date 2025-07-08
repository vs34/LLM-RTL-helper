#!/bin/bash

# Usage: ./run_test.sh <testbench_file.v>
# Example: ./run_test.sh test_my_module.v

# Check if a testbench file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <testbench_file.v>"
  echo "Example: $0 test_my_module.v"
  exit 1
fi

TESTBENCH_FILE="$1"
# Extract the base name (e.g., "test_my_module" from "test_my_module.v")
BASE_NAME=$(basename "$TESTBENCH_FILE" .v)

# Derive the DUT (Design Under Test) file name.
# This assumes your testbench is named `test_something.v` and your DUT is `something.v`.
# If your naming convention is different (e.g., `tb_something.v` and `something.v`),
# you'll need to adjust the string manipulation here.
if [[ "$BASE_NAME" == test_* ]]; then
  DUT_NAME="${BASE_NAME#test_}" # Removes 'test_' prefix
  DUT_FILE="${DUT_NAME}.v"
else
  echo "Warning: Testbench '$TESTBENCH_FILE' does not follow 'test_<module>.v' naming convention."
  echo "Attempting to compile with only the testbench. If your design is in a separate file,"
  echo "you'll need to modify the script or manually specify all files."
  # If the naming convention isn't followed, we'll try to compile just the testbench.
  # This might fail if the DUT is truly in a separate file not specified.
  DUT_FILE="" # Set to empty if we can't reliably derive it
fi

# Output file for the compiled simulation
SIM_OUT="sim_out.vvp"
# Output file for the simulation console text
SIM_TXT="output.txt"
# Output file for VCD (waveform) dump - assuming testbench generates one
VCD_FILE="${BASE_NAME}.vcd"

# --- Compilation ---
echo "--- Compiling Verilog files ---"
COMPILE_COMMAND="iverilog -o \"$SIM_OUT\" \"$TESTBENCH_FILE\""

if [ -n "$DUT_FILE" ] && [ -f "$DUT_FILE" ]; then
  COMPILE_COMMAND+=" \"$DUT_FILE\""
  echo "Compiling: $TESTBENCH_FILE and $DUT_FILE"
elif [ -n "$DUT_FILE" ]; then
  echo "Warning: DUT file '$DUT_FILE' derived but not found. Compiling only testbench."
  echo "Make sure '$DUT_FILE' exists or is included in '$TESTBENCH_FILE'."
  echo "Compiling: $TESTBENCH_FILE"
else
  echo "Compiling: $TESTBENCH_FILE (no separate DUT file derived)"
fi

# Execute compilation
if eval $COMPILE_COMMAND; then
  echo "Compilation successful. Output: $SIM_OUT"
else
  echo "Error: Compilation failed."
  exit 1
fi

# --- Simulation ---
echo "--- Running simulation ---"
if vvp "$SIM_OUT" > "$SIM_TXT"; then
  echo "Simulation successful. Console output saved to $SIM_TXT"
  echo "--- Simulation Output ---"
  cat "$SIM_TXT"
else
  echo "Error: Simulation failed."
  cat "$SIM_TXT" # Show partial output if simulation crashed
  exit 1
fi

# --- Check for VCD file and suggest GTKWave ---
if [ -f "$VCD_FILE" ]; then
  echo "--- Waveform file generated ---"
  echo "Waveform data saved to $VCD_FILE"
  echo "To view waveforms, install GTKWave (sudo apt install gtkwave) and run:"
  echo "gtkwave $VCD_FILE"
else
  echo "Note: No VCD file '$VCD_FILE' found. Ensure your testbench includes \$dumpfile and \$dumpvars."
fi

echo "--- Script finished ---"
