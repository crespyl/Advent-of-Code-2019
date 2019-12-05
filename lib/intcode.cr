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
      instr // 10**(param_idx+1) % 10
    end

    # Given a VM and instruction, decode the given value
    def self.get_read_parameter_value(vm, instr, param)
      case Opcode.get_addressing_mode_for_param(instr, param)
      when 0 # position mode
        vm.mem[vm.mem[vm.pc + param]]
      when 1 # literal mode
        vm.mem[vm.pc + param]
      else
        raise "Unsupported addressing mode #{instr}, #{param}"
      end
    end

    # Given a VM and instruction, find the correct address to write to
    def self.get_write_parameter_address(vm, instr, param)
      case Opcode.get_addressing_mode_for_param(instr, param)
      when 0 # position mode, write to this address
        vm.mem[vm.pc + param]
      when 1 # literal mode
        raise "Attempted to write to literal value at #{vm.pc}: #{instr}, #{param}"
      else
        raise "Unsupported addressing mode #{instr}, #{param}"
      end
    end

    def self.debug_parameter_value(vm, instr, param)
      case Opcode.get_addressing_mode_for_param(instr, param)
      when 0 # position mode
        "@#{vm.mem[vm.pc + param]}"
      when 1 # literal mode
        "#{vm.mem[vm.pc + param]}"
      else
        raise "Unsupported addressing mode #{instr}, #{param}"
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

    def run
      while !@halted && @pc < mem.size
        instr = mem[pc]
        opcode = Opcode.from_instruction(instr)
        if opcode == nil
          raise "INVALID OPCODE AT #{pc}: #{mem[pc]}"
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
                      x = Opcode.get_read_parameter_value(vm, instr, 1)
                      y = Opcode.get_read_parameter_value(vm, instr, 2)
                      dest = Opcode.get_write_parameter_address(vm, instr, 3)
                      vm.mem[dest] = x + y
                      vm.pc += 4
                    },
                    ->(vm: VM, instr: Int32) {
                      "ADD %4s, %4s -> %4s" % [Opcode.debug_parameter_value(vm, instr, 1),
                                               Opcode.debug_parameter_value(vm, instr, 2),
                                               Opcode.debug_parameter_value(vm, instr, 3)]
                    }),
    2 => Opcode.new(:mul,
                    4,
                    ->(vm: VM, instr: Int32) {
                      x = Opcode.get_read_parameter_value(vm, instr, 1)
                      y = Opcode.get_read_parameter_value(vm, instr, 2)
                      dest = Opcode.get_write_parameter_address(vm, instr, 3)
                      vm.mem[dest] = x * y
                      vm.pc += 4
                    },
                    ->(vm: VM, instr: Int32) {
                      "MUL %4s, %4s -> %4s" % [Opcode.debug_parameter_value(vm, instr, 1),
                                               Opcode.debug_parameter_value(vm, instr, 2),
                                               Opcode.debug_parameter_value(vm, instr, 3)]
                    }),
    3 => Opcode.new(:input,
                    2,
                    ->(vm: VM, instr: Int32) {
                      dest = Opcode.get_write_parameter_address(vm, instr, 1)
                      vm.mem[dest] = vm.get_input
                      vm.pc += 2
                    },
                    ->(vm: VM, instr: Int32) {
                      "INPUT -> %4s" % [vm.mem[vm.pc+1]]
                    }),
    4 => Opcode.new(:output,
                    2,
                    ->(vm: VM, instr: Int32) {
                      x = Opcode.get_read_parameter_value(vm, instr, 1)
                      vm.write_output(x)
                      vm.pc += 2
                    },
                    ->(vm: VM, instr: Int32) {
                      "OUTPUT %4s" % [Opcode.debug_parameter_value(vm, instr, 1)]
                    }),
    5 => Opcode.new(:jt,
                    3,
                    ->(vm: VM, instr: Int32) {
                      x = Opcode.get_read_parameter_value(vm, instr, 1)
                      dest = Opcode.get_read_parameter_value(vm, instr, 2)
                      if x != 0
                        vm.pc = dest
                      else
                        vm.pc += 3
                      end
                    },
                    ->(vm: VM, instr: Int32) {
                      "JT  %4s, %4s" % [Opcode.debug_parameter_value(vm, instr, 1),
                                        Opcode.debug_parameter_value(vm, instr, 2)]
                    }),
    6 => Opcode.new(:jf,
                    3,
                    ->(vm: VM, instr: Int32) {
                      x = Opcode.get_read_parameter_value(vm, instr, 1)
                      dest = Opcode.get_read_parameter_value(vm, instr, 2)
                      if x == 0
                        vm.pc = dest
                      else
                        vm.pc += 3
                      end
                    },
                    ->(vm: VM, instr: Int32) {
                      "JF  %4s, %4s" % [Opcode.debug_parameter_value(vm, instr, 1),
                                        Opcode.debug_parameter_value(vm, instr, 2)]
                    }),
    7 => Opcode.new(:lt,
                    4,
                    ->(vm: VM, instr: Int32) {
                      x = Opcode.get_read_parameter_value(vm, instr, 1)
                      y = Opcode.get_read_parameter_value(vm, instr, 2)
                      dest = Opcode.get_write_parameter_address(vm, instr, 3)
                      if x < y
                        vm.mem[dest] = 1
                      else
                        vm.mem[dest] = 0
                      end
                      vm.pc += 4
                    },
                    ->(vm: VM, instr: Int32) {
                      "LT  %4s, %4s -> %4s" % [Opcode.debug_parameter_value(vm, instr, 1),
                                               Opcode.debug_parameter_value(vm, instr, 2),
                                               Opcode.debug_parameter_value(vm, instr, 3)]
                    }),
    8 => Opcode.new(:eq,
                    4,
                    ->(vm: VM, instr: Int32) {
                      x = Opcode.get_read_parameter_value(vm, instr, 1)
                      y = Opcode.get_read_parameter_value(vm, instr, 2)
                      dest = Opcode.get_write_parameter_address(vm, instr, 3)
                      if x == y
                        vm.mem[dest] = 1
                      else
                        vm.mem[dest] = 0
                      end
                      vm.pc += 4
                    },
                    ->(vm: VM, instr: Int32) {
                      "EQ  %4s, %4s -> %4s" % [Opcode.debug_parameter_value(vm, instr, 1),
                                               Opcode.debug_parameter_value(vm, instr, 2),
                                               Opcode.debug_parameter_value(vm, instr, 3)]
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
