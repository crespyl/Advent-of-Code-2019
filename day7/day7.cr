#!/usr/bin/env crystal
require "../lib/intcode.cr"

Intcode.set_debug(ENV.has_key?("AOC_DEBUG") ? ENV["AOC_DEBUG"] == "true" : false)

puts "Part 1"

# Create 5 amplifier progras
def make_amps(phase_settings)
  phase_settings.map { |phase_setting|
    vm = Intcode::VM.from_file("day7/input.txt")
    #vm = Intcode::VM.from_string("3,23,3,24,1002,24,10,24,1002,23,-1,23,101,5,23,23,1,24,23,23,4,23,99,0,0")
    vm.send_input(phase_setting)
    vm
  }
end

# Run each vm and feed its first output to the next machines input
def run_serial(amps)
  puts "Running amps serial: #{amps.size}"
  amps.size.times do |i|
    puts "Running Amp #{i}"
    amps[i].run
    puts "  done: #{amps[i].outputs}"
    output = amps[i].outputs.first
    puts "  got #{output}"
    if amps.size > i+1
      amps[i+1].send_input(output)
    end
  end
  return amps.last.outputs.empty? ? 0 : amps.last.outputs.first
end

# Test each permutation of an input set and find the best
def find_best(inputs)
  best_settings, best_output = inputs, 0
  inputs.each_permutation do |p|
    amps = make_amps(p)
    amps[0].send_input(0)
    output = run_serial(amps)
    if output > best_output
      best_output = output
      best_settings = p
    end
  end
  return best_settings, best_output
end

inputs = [0,1,2,3,4]
best_settings, best_output = find_best(inputs)

puts "\n"
puts "Best Settings: #{best_settings}"
puts "Best Output: #{best_output}"
