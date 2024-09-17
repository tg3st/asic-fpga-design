#------------------------------------------------------------
#
# Basic Synthesis Script (TCL format)
#                                  
# Revision History 
#   1999 : Author : P. Franzon               
#   1/15/03  : Author Shane T. Gehring - from class example
#   2/09/07  : Author Zhengtao Yu      - from class example
#   12/14/07 : Author Ravi Jenkal      - updated to 180 nm & tcl
#   11/6/2017 : P. Franzon.  Removed replace_synthetic.  
#                            Added a 2nd check_design
#
#------------------------------------------------------------

#---------------------------------------------------------
# Read in Verilog file and map (synthesize) onto a generic
# library.
# MAKE SURE THAT YOU CORRECT ALL WARNINGS THAT APPEAR
# during the execution of the read command are fixed 
# or understood to have no impact.
# ALSO CHECK your latch/flip-flop list for unintended 
# latches                                            
#---------------------------------------------------------

read_verilog $RTL_DIR/counter.v
