#!/usr/bin/env ruby

require "colorize"
require_relative "../lib/intcode.rb"
#require_relative "../lib/utils.rb"

INPUT = File.read("day9/input.txt").chomp  #Utils.get_input_file(Utils.cli_param_or_default(0, "day9/input.txt"))

#Intcode.set_debug(true)
vm = Intcode::VM.from_string(INPUT)
#vm = Intcode::VM.from_string("109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99")
#vm = Intcode::VM.from_string("1102,34915192,34915192,7,4,7,99,0")
#vm = Intcode::VM.from_string("104,1125899906842624,99")

# part 1
vm.send_input(1)
vm.run()
puts "Part 1: #{vm.read_output}"

# part 2
vm = Intcode::VM.from_string(INPUT)
vm.send_input(2)
s = Time.now
vm.run
puts "Part 2 (#{Time.now - s}s): #{vm.read_output}"
