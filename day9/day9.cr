#!/usr/bin/env crystal
require "../lib/intcode.cr"
require "../lib/utils.cr"

INPUT = Utils.get_input_file(Utils.cli_param_or_default(0, "day9/input.txt"))

Intcode.set_debug(Utils.enable_debug_output?)

# Part 1
vm = Intcode::VM.from_string(INPUT)
vm.send_input(1)
vm.run()
puts "Part 1: #{vm.read_output}"

# Part 2
s = Time.local
vm = Intcode::VM.from_string(INPUT)
vm.send_input(2)
vm.run()
puts "Part 2 (#{Time.local - s}s): #{vm.read_output}"
