#!/usr/bin/env crystal
require "../lib/intcode.cr"

Intcode.set_debug(ENV.has_key?("AOC_DEBUG") ? ENV["AOC_DEBUG"] == "true" : false)

puts "Part 1"
vm = Intcode::VM.from_file(ARGV[0])
vm.inputs = [1_i64]
vm.run
puts "\n"
puts "Outputs: #{vm.outputs}"

puts "\nPart 2"
vm = Intcode::VM.from_file(ARGV[0])
vm.inputs = ARGV.size > 1 ? [Int64.new(ARGV[1])] : [5_i64]
vm.run
puts "\n"
puts "Outputs: #{vm.outputs}"
