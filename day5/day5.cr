#!/usr/bin/env crystal
require "../lib/intcode.cr"

puts "Part 1"
vm = Intcode::VM.from_file(ARGV[0])
Intcode.set_debug(true)
vm.run
puts "\n"
