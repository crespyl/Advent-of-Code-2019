# This module define the "Intcode" interpreter, operating on arrays of Integer
require "io/console"

module Intcode
  @@DEBUG = false

  # This class is just a holder for information about an Opcode, including Proc
  # objects for the implementation and a debug/display function
  class Opcode
    property sym : Symbol
    property size : Int32
    property impl : Proc(VM, Int32, Int32)
    property disasm : Proc(VM, Int32, String)

    def initialize(@sym, @size, @impl, @disasm)
    end

    # Execute this opcode inside this VM (we pass the actual instruction as well
    # so that the opcode can parse out its addressing modes)
    def exec(vm, instr)
      impl.call(vm, instr)
    end

    # Attempt to produce a debug string for this opcode
    def debug(vm, instr)
      disasm.call(vm, instr)
    end

    # Lookup the correct registered Opcode from an instruction
    def self.from_instruction(instr)
      OPCODES[instr % 100]
    end

    # Get the addressing mode for the nth parameter from an instruction (2+nth digit)
    #
    # Mode 0 is "position", should treat the parameter as an address
    # Mode 1 is immediate, should treat the parameter as a literal
    def self.get_addressing_mode_for_param(instr, param_idx)
      case instr // 10**(param_idx+1) % 10
      when 0 then :position
      when 1 then :literal
      else
        raise "Unsupported addressing mod #{instr}: #{param_idx}"
      end
    end

    # Given a VM and instruction, decode the given parameter
    def self.get_parameter(vm, instr, param)
      mode = get_addressing_mode_for_param(instr, param)
      val = vm.mem[vm.pc + param]
      Parameter.new(mode, val)
    end

    def self.get_parameters(vm, instr, n_params)
      (1..n_params).map { |i| get_parameter(vm, instr, i) }
    end
    def self.debug_parameters(vm, instr, n_params)
      get_parameters(vm, instr, n_params).map { |p| p.debug }
    end
  end

  # Represents an encoded parameter and its addressing mode
  class Parameter
    property val : Int32 # the original value in memory
    property mode : Symbol

    def initialize(@mode, @val) end

    def debug
      case mode
      when :position then "@#{val}"
      when :literal then "val"
      else
        "??"
      end
    end
  end

  # This class holds the current state of a running interpreter: the memory
  # (Array(Int32)), the program counter, and a "halted/running" flag
  class VM
    property mem : Array(Int32)
    property pc : Int32
    property halted : Bool

    def initialize(mem)
      @pc = 0
      @halted = false
      @mem = Array.new(4096, 0)
      mem.each_with_index do |v, i|
        @mem[i] = v
      end
    end

    def self.from_file(filename)
      VM.new(Intcode.load_file(filename))
    end

    def self.from_string(str)
      VM.new(Intcode.read_intcode(str))
    end

    # Get the value of the provided parameter
    def read_param(p : Parameter)
      case p.mode
      when :position then mem[p.val]
      when :literal then p.val
      else
        raise "Unsupported addressing mode for #{p}"
      end
    end

    # Set the address indicated by the parameter to the given value
    def write_param_value(p : Parameter, val : Int32)
      case p.mode
      when :position then mem[p.val] = val
      when :literal then raise "Cannot write to literal"
      else
        raise "Unsupported addressing mode for #{p}"
      end
    end

    def run
      while !@halted && @pc < mem.size
        instr = mem[pc]
        begin
        opcode = Opcode.from_instruction(instr)
        rescue
          raise "INVALID OPCODE AT #{pc}: #{mem[pc]}"
        end
        if opcode == nil
        end

        Intcode.log("%4i:%04i: %s" % [pc, mem[pc], opcode.debug(self, instr)])
        opcode.exec(self, instr)
      end
    end

    def get_input
      input = STDIN.read_line.to_i
      puts "GOT INPUT #{input}"
      input
    end

    def write_output(val)
      puts "                                     GOT OUTPUT #{val}"
    end
  end

  # Here we define the mapping from integer to opcode, along with the actual
  # implementation of each, as Proc objects that get bound to the Opcode
  # instance during execution
  OPCODES = {
    1 => Opcode.new(:add,
                    4,
                    ->(vm: VM, instr: Int32) {
                      x, y, dest = Opcode.get_parameters(vm, instr, 3)
                      vm.write_param_value(dest, vm.read_param(x) + vm.read_param(y))
                      vm.pc += 4
                    },
                    ->(vm: VM, instr: Int32) {
                      "ADD %4s, %4s -> %4s" % Opcode.debug_parameters(vm, instr, 3)
                    }),
    2 => Opcode.new(:mul,
                    4,
                    ->(vm: VM, instr: Int32) {
                      x, y, dest = Opcode.get_parameters(vm, instr, 3)
                      vm.write_param_value(dest, vm.read_param(x) * vm.read_param(y))
                      vm.pc += 4
                    },
                    ->(vm: VM, instr: Int32) {
                      "MUL %4s, %4s -> %4s" % Opcode.debug_parameters(vm, instr, 3)
                    }),
    3 => Opcode.new(:input,
                    2,
                    ->(vm: VM, instr: Int32) {
                      dest = Opcode.get_parameter(vm, instr, 1)
                      vm.write_param_value(dest, vm.get_input)
                      vm.pc += 2
                    },
                    ->(vm: VM, instr: Int32) {
                      "INPUT -> %4s" % Opcode.debug_parameters(vm, instr, 1)
                    }),
    4 => Opcode.new(:output,
                    2,
                    ->(vm: VM, instr: Int32) {
                      x = Opcode.get_parameter(vm, instr, 1)
                      vm.write_output(vm.read_param(x))
                      vm.pc += 2
                    },
                    ->(vm: VM, instr: Int32) {
                      "OUTPUT %4s" % Opcode.debug_parameters(vm, instr, 1)
                    }),
    5 => Opcode.new(:jt,
                    3,
                    ->(vm: VM, instr: Int32) {
                      x, dest = Opcode.get_parameters(vm, instr, 2)
                      if vm.read_param(x) != 0
                        vm.pc = vm.read_param(dest)
                      else
                        vm.pc += 3
                      end
                    },
                    ->(vm: VM, instr: Int32) {
                      "JT  %4s, %4s" % Opcode.debug_parameters(vm, instr, 2)
                    }),
    6 => Opcode.new(:jf,
                    3,
                    ->(vm: VM, instr: Int32) {
                      x, dest = Opcode.get_parameters(vm, instr, 2)
                      if vm.read_param(x) == 0
                        vm.pc = vm.read_param(dest)
                      else
                        vm.pc += 3
                      end
                    },
                    ->(vm: VM, instr: Int32) {
                      "JF  %4s, %4s" % Opcode.debug_parameters(vm, instr, 2)
                    }),
    7 => Opcode.new(:lt,
                    4,
                    ->(vm: VM, instr: Int32) {
                      x, y, dest = Opcode.get_parameters(vm, instr, 3)
                      if vm.read_param(x) < vm.read_param(y)
                        vm.write_param_value(dest, 1)
                      else
                        vm.write_param_value(dest, 0)
                      end
                      vm.pc += 4
                    },
                    ->(vm: VM, instr: Int32) {
                      "LT  %4s, %4s -> %4s" % Opcode.debug_parameters(vm, instr, 3)
                    }),
    8 => Opcode.new(:eq,
                    4,
                    ->(vm: VM, instr: Int32) {
                      x, y, dest = Opcode.get_parameters(vm, instr, 3)
                      if vm.read_param(x) == vm.read_param(y)
                        vm.write_param_value(dest, 1)
                      else
                        vm.write_param_value(dest, 0)
                      end
                      vm.pc += 4
                    },
                    ->(vm: VM, instr: Int32) {
                      "EQ  %4s, %4s -> %4s" % Opcode.debug_parameters(vm, instr, 3)
                    }),
    99 => Opcode.new(:halt,
                     1,
                     ->(vm: VM, instr: Int32) {
                       vm.halted = true
                       1
                     },
                     ->(vm: VM, instr: Int32) {
                       "HALT"
                     }),
  }

  # Parse the input string into an array of integers
  def self.read_intcode(str)
    str.split(',')
      .map { |s| s.to_i }
      .reject { |x| !x.is_a? Int32 }
  end

  # Load an Intcode program from a filename, returned as an array of Integers
  def self.load_file(filename)
    read_intcode(File.read(filename))
  end

  # Load an Intcode VM from a string
  def self.load_vm_from_string(str)
    mem = read_intcode(str)
    VM.new(mem)
  end

  # Load an Intcode VM from a file
  def self.load_vm_from_file(filename)
    mem = load_file(filename)
    VM.new(mem)
  end

  # Enable or disable verbose debug logging during execution
  def self.set_debug(enable_debug)
    @@DEBUG = enable_debug
  end

  def self.log(msg)
    puts msg if @@DEBUG
  end
end
