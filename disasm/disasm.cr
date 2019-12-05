#!/usr/bin/env crystal
require "../lib/intcode.cr"
require "../lib/disasm.cr"

result = Disasm.intcode_to_str(Intcode.load_file(ARGV[0]))

puts result
