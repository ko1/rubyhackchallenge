require_relative 'yasm'

script = <<END_OF_SCRIPT
# insert your favorite Ruby program here.

1 + 2

END_OF_SCRIPT

YASM.compile_and_disasm(script)
# YASM.compile_and_to_ary(script)
