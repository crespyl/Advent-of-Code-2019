#!/usr/bin/env ruby
require_relative "../lib/intcode.rb"

Intcode.set_debug(ENV.has_key?("AOC_DEBUG") ? ENV["AOC_DEBUG"] == "true" : false)

puts "Part 1"
vm = Intcode::VM.from_file(ARGV[0])
vm.inputs = [1]
vm.run
puts "\n"
puts "Outputs: #{vm.outputs}"

puts "\nPart 2"
vm = Intcode::VM.from_file(ARGV[0])
vm.inputs = ARGV.size > 1 ? [ARGV[1].to_i] : [5]
vm.run
puts "\n"
puts "Outputs: #{vm.outputs}"
