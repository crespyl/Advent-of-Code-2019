#!/usr/bin/env crystal
require "../lib/intcode.cr"

Intcode.set_debug(ENV.has_key?("AOC_DEBUG") ? ENV["AOC_DEBUG"] == "true" : false)

puts "Part 1"

# Create 5 amplifier progras
def make_amps(phase_settings, custom_prg = "")
  phase_settings.map { |phase_setting|
    if custom_prg.empty?
      vm = Intcode::VM.from_file("day7/input.txt")
    else
      vm = Intcode::VM.from_string(custom_prg)
    end
    vm.send_input(phase_setting)
    vm
  }
end

# Run each vm and feed its first output to the next machines input
def run_serial(amps)
  #puts "Running amps serial: #{amps.size}"
  amps.size.times do |i|
    # puts "Running Amp #{i}"
    amps[i].run
    # puts "  done: #{amps[i].outputs}"
    output = amps[i].outputs.first
    # puts "  got #{output}"
    if amps.size > i+1
      amps[i+1].send_input(output)
    end
  end
end

def run_feedback(amps)
  #puts "Running amps feedback: #{amps.size}"

  while amps.all? { |amp| amp.status != :halted }
    amps.each_with_index do |amp, i|
      case amp.status
      when :needs_input
        previous = amps[(i-1) % amps.size].read_output
        # if we don't get anything from the previous amp, just skip this for now
        if previous
          amp.send_input(previous)
          amp.run
        end
      when :ok
          amp.run
      end
    end
  end

  #puts "Feedback run complete: #{amps.map { |a| a.status }} \n#{amps.last.outputs}"
end

# Test each permutation of an input set and find the best
def find_best(inputs)
  best_settings, best_output = inputs, 0
  inputs.each_permutation do |p|
    amps = make_amps(p)
    amps[0].send_input(0)
    run_serial(amps)
    output = amps.last.read_output
    if output && output > best_output
      best_output = output
      best_settings = p
    end
  end
  return best_settings, best_output
end

def find_best_feedback(inputs)
  best_settings, best_output = inputs, 0
  inputs.each_permutation do |p|
    puts "  trying #{p}"
    amps = make_amps(p)
    amps[0].send_input(0)
    run_feedback(amps)
    output = amps.last.read_output
    puts "    got #{output}"
    if output && output > best_output
      best_output = output
      best_settings = p
    end
  end
  return best_settings, best_output
end

inputs = [0,1,2,3,4]
best_settings, best_output = find_best(inputs)

puts "Part 1"
puts "Best Settings: #{best_settings}"
puts "Best Output: #{best_output}"

# inputs = [9,8,7,6,5]
# amps = make_amps(inputs, "3,26,1001,26,-4,26,3,27,1002,27,2,27,1,27,26,27,4,27,1001,28,-1,28,1005,28,6,99,0,0,5")

# inputs = [9,7,8,5,6]
# amps = make_amps(inputs, "3,52,1001,52,-5,52,3,53,1,52,56,54,1007,54,5,55,1005,55,26,1001,54,
# -5,54,1105,1,12,1,53,54,53,1008,54,0,55,1001,55,1,55,2,53,55,53,4,
# 53,1001,56,-1,56,1005,56,6,99,0,0,0,0,10")

# amps[0].send_input(0)
# run_feedback(amps)
# puts amps.last.read_output

puts "\n Part 2"
inputs = [5,6,7,8,9]
best_settings, best_output = find_best_feedback(inputs)
puts "Best Settings: #{best_settings}"
puts "Best Output: #{best_output}"
