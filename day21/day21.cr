#!/usr/bin/env crystal

require "../lib/utils.cr"
require "../lib/vm2.cr"

prog = Utils.get_input_file(Utils.cli_param_or_default(0,"day21/input.txt"))
vm = VM2.from_string(prog)

# The basic idea is to jump if any of the next three tiles are empty, AND the
# fourth tile (D) is solid
#
# First, OR together A, B, C into J
# Then use NOT D T/NOT T T to read D into T
p1_script = "\
NOT A J
NOT B T
OR T J
NOT C T
OR T J
NOT D T
NOT T T
AND T J
WALK
".chars.map(&.ord.to_i64)

vm.input = p1_script
vm.run

puts "Part 1: %i" % vm.output.last

# Same basic idea, but we have to check for the case where we have to make two
# jumps in succession, we look ahead using the new registers
p2_script = "\
NOT A J
NOT B T
OR T J
NOT C T
OR T J
NOT D T
NOT T T
AND T J
AND E T
OR H T
AND T J
RUN
".chars.map(&.ord.to_i64)

vm = VM2.from_string(prog)
vm.input = p2_script
vm.run

puts "Part 2: %i" % vm.output.last
