#!/usr/bin/env crystal
require "colorize"
require "../lib/intcode.cr"

Intcode.set_debug(ENV.has_key?("AOC_DEBUG") ? ENV["AOC_DEBUG"] == "true" : false)

# Create 5 amplifier progras
def make_amps(phase_settings, custom_prg = "")
  phase_settings.map_with_index { |phase_setting, i|
    if custom_prg.empty?
      vm = Intcode::VM.from_file("day7/input.txt")
    else
      vm = Intcode::VM.from_string(custom_prg)
    end
    vm.name = colorize_name("Amp-#{i}")
    vm.send_input(phase_setting)
    vm
  }
end

# Utility fn to make colorized amp names for debugging
def colorize_name(name)
  r =  [rand(UInt8), UInt8.new(100)].max
  g =  [rand(UInt8), UInt8.new(100)].max
  b =  [rand(UInt8), UInt8.new(100)].max
  name.colorize(Colorize::ColorRGB.new(r,g,b)).to_s
end

# Run each vm and connects their outputs and inputs as indicated by the link
# pairs
#
# Each pair (x,y) indicates that vm X should read its input from the output of
# vm Y
#
# Returns the last output of the final vm
def run_linked_vms(vms, links : Hash(Int32,Int32))
  # vms can be halted, input blocked, or ready; we keep working until all have
  # halted
  while vms.any? { |vm| vm.status != :halted }
    vms.each_with_index() do |vm, i|

      case vm.status
      when :ok then vm.run
      when :needs_input  # see if its linked vm has output and copy it over
        if links[i]?
          linked_output = vms[links[i]].read_output
          if linked_output
            vm.send_input(linked_output)
            vm.run
          end
        end
      when :halted # nothing to do
      end
    end
  end

  return vms.last.read_output
end

# Run each vm in an async Fiber and connects their outputs and inputs as
# indicated by the link pairs
#
# Each pair (x,y) indicates that vm X should read its input from the output of
# vm Y
#
# Returns the last output of the final vm
def run_async_vms(vms, links)
  halts = Channel(Bool).new
  channels = vms.map { |vm| Channel(Int32).new(1) } # channels have a buffer so
                                                    # that the final send
                                                    # doesn't block waiting for
                                                    # a halted machine to read
  vms.each_with_index do |vm,i|
    spawn {
      while true
        case vm.status
        when :ok
          vm.run
        when :needs_input
          if links[i]?
            vm.send_input(channels[links[i]].receive)
            vm.run
          else # needs input but there's no linked vm to read it from
            break
          end
        when :halted
          break
        end

        # send any output to the channel
        while output = vm.read_output
          channels[i].send(output)
        end
      end

      channels[i].close
      halts.send(true)
    }
  end

  # wait until all machines have halted
  (channels.size).times do
    halts.receive
  end

  channels.last.receive
end

# Test each permutation of an input set and find the best
def find_best(inputs, runner)
  best_settings, best_output = inputs, 0
  inputs.each_permutation do |p|
    amps = make_amps(p)
    amps[0].send_input(0)
    output = runner.call(amps)
    #output = amps.last.read_output
    if output && output > best_output
      best_output = output
      best_settings = p
    end
  end
  return best_settings, best_output
end

def find_best_serial(inputs)
  links = {1 => 0,
           2 => 1,
           3 => 2,
           4 => 3}
  find_best(inputs, ->(amps: Array(Intcode::VM)) { run_async_vms(amps, links) })
end

def find_best_feedback(inputs)
  links = {0 => 4,
           1 => 0,
           2 => 1,
           3 => 2,
           4 => 3}
  find_best(inputs, ->(amps: Array(Intcode::VM)) { run_async_vms(amps, links) })
end

puts "Part 1"
inputs = [0,1,2,3,4]
best_settings, best_output = find_best_serial(inputs)
puts "Best Settings: #{best_settings}"
puts "Best Output: #{best_output}"

puts "\n Part 2"
inputs = [5,6,7,8,9]
best_settings, best_output = find_best_feedback(inputs)
puts "Best Settings: #{best_settings}"
puts "Best Output: #{best_output}"

# links = {0 => 4,
#          1 => 0,
#          2 => 1,
#          3 => 2,
#          4 => 3}
# amps = make_amps([5, 8, 9, 7, 6])
# amps[0].send_input(0)
# puts run_async_vms(amps, links)
