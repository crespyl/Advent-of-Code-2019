#!/usr/bin/env crystal
require "colorize"
require "../lib/intcode.cr"
require "../lib/utils.cr"
require "../lib/vm2.cr"

Intcode.set_debug(Utils.enable_debug_output?)
INPUT = Utils.get_input_file(Utils.cli_param_or_default(0, "day7/input.txt"))

# Create 5 amplifier progras
def make_amps(phase_settings : Array(Int64), custom_prg = "")
  phase_settings.map_with_index { |phase_setting, i|
    if custom_prg.empty?
      vm = VM2.from_string(INPUT)
    else
      vm = VM2.from_string(custom_prg)
    end
    vm.name = colorize_name("Amp-#{i}")
    vm.debug = Utils.enable_debug_output?
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
          puts "   #{vm.name} <- #{vms[links[i]].name}" if Utils.enable_debug_output?
          while linked_output = vms[links[i]].read_output
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
  channels = vms.map { |vm| Channel(Int64).new(1) } # channels have a buffer so
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
            puts "   #{vm.name} <- #{vms[links[i]].name}" if Utils.enable_debug_output?
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
def find_best(inputs : Array(Int64), runner)
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
  find_best(inputs, ->(amps: Array(VM2::VM)) { run_async_vms(amps, links) })
end

def find_best_feedback(inputs)
  links = {0 => 4,
           1 => 0,
           2 => 1,
           3 => 2,
           4 => 3}
  find_best(inputs, ->(amps: Array(VM2::VM)) { run_async_vms(amps, links) })
end

puts "Part 1"
inputs = (0_i64..4_i64).to_a
best_settings, best_output = find_best_serial(inputs)
puts "Best Settings: #{best_settings}"
puts "Best Output: #{best_output}"

puts "\n Part 2"
inputs = (5_i64..9_i64).to_a
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
