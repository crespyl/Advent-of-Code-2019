#!/usr/bin/env crystal

require "colorize"
require "../lib/utils.cr"
require "../lib/vm2.cr"

INPUT = Utils.get_input_file(Utils.cli_param_or_default(0, "day23/input.txt"))

vms = make_vms(INPUT, 50)
run_networked_vms(vms)

def make_vms(program : String, n : Int32)
  (0...n).map do |n|
    vm = VM2.from_string(program)
    vm.send_input(n)
    vm.name = colorize_name("VM-%i" % n)
    vm
  end
end

def colorize_name(name)
  r = [rand(UInt8), UInt8.new(100)].max
  g = [rand(UInt8), UInt8.new(100)].max
  b = [rand(UInt8), UInt8.new(100)].max
  name.colorize(Colorize::ColorRGB.new(r, g, b)).to_s
end

def run_networked_vms(vms : Array(VM2::VM))
  idle_vms = Array(Bool).new(vms.size, false)

  first_nat = true
  nat_write = false
  nat_x, nat_y = Int64::MAX, Int64::MAX

  last_y = Int64::MAX
  last_x = Int64::MAX

  while vms.any? { |vm| vm.status != :halted }
    vms.each_with_index do |vm, idx|
      # first check the output queue for packets and deliver them
      if vm.output.size >= 3
        idle_vms[idx] = false

        dest, x, y = vm.read_output_or_raise(),
                     vm.read_output_or_raise(),
                     vm.read_output_or_raise()

        if dest == 255
          # write to nat
          puts "%s -> 255: X = %i, Y = %i" % [vm.name, x, y] if Utils.enable_debug_output?
          if first_nat
            first_nat = false
            puts "Part 1: %i" % y
          end
          nat_write = true
          nat_x = x
          nat_y = y
        else
          vms[dest].send_input(x)
          vms[dest].send_input(y)
          puts "%s -> %s: (x: %i, y: %i)" % [vm.name, vms[dest].name, x, y] if Utils.enable_debug_output?
        end

      end

      case vm.status
      when :ok
        vm.run
      when :needs_input
        # the vms have their own input buffers, if we get here it means that we
        # haven't delivered any packets, so it should just receive the
        # non-blocking default indicator of -1
        vm.send_input(-1)
        idle_vms[idx] = true
      when :halted
      end
    end

    # check to see if all vms are "idle"
    if idle_vms.all?(true) && nat_write
      puts "Network Idle, NAT transmitting:" if Utils.enable_debug_output?
      puts "NAT -> 0: X = %i, Y = %i" % [nat_x, nat_y] if Utils.enable_debug_output?
      vms[0].send_input(nat_x)
      vms[0].send_input(nat_y)
      if last_y == nat_y
        puts "Part 2: %i" % last_y
        break
      end
      last_x = nat_x
      last_y = nat_y
      nat_write = false
    end

  end
end
