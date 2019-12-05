#!/usr/bin/env crystal
require "../lib/intcode.cr"

Intcode.set_debug(true)

puts "Part 1"
vm = Intcode::VM.from_file(ARGV[0])
vm.inputs = [1]
vm.run
puts "\n"
puts "Outputs: #{vm.outputs}"

puts "\nPart 2"
vm = Intcode::VM.from_file(ARGV[0])
vm.inputs = [5]
vm.run
puts "\n"
puts "Outputs: #{vm.outputs}"
