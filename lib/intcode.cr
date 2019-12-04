# This module define the "Intcode" interpreter, operating on arrays of Integer
module Intcode
  @@DEBUG = false

  # This class is just a holder for information about an Opcode, including Proc
  # objects for the implementation and a debug/display function
  class Opcode
    property sym : Symbol
    property size : Int32
    property impl : Proc(VM, Int32)
    property disasm : Proc(VM, String)

    def initialize(@sym, @size, @impl, @disasm)
    end

    # Execute this opcode inside this VM
    def exec(vm)
      impl.call(vm)
    end

    # Attempt to produce a debug string for this opcode
    def debug(vm)
      disasm.call(vm)
    end
  end

  # This class holds the current state of a running interpreter: the memory
  # (Array(Int32)), the program counter, and a "halted/running" flag
  class VM
    property mem : Array(Int32)
    property pc : Int32
    property halted : Bool

    def initialize(@mem)
      @pc = 0
      @halted = false
    end

    def self.from_file(filename)
      VM.new(load_file(filename))
    end

    def self.from_string(str)
      VM.new(read_intcode(str))
    end

    def run
      while !@halted && @pc < mem.size
        opcode = OPCODES[mem[pc]]
        if opcode == nil
          raise "INVALID OPCODE AT #{pc}: #{mem[pc]}"
        end

        Intcode.log("%4i: %s" % [pc, opcode.debug(self)])
        opcode.exec(self)
      end
    end
  end

  # Here we define the mapping from integer to opcode, along with the actual
  # implementation of each, as Proc objects that get bound to the Opcode
  # instance during execution
  OPCODES = {
    1 => Opcode.new(:add,
                    4,
                    ->(vm: VM) {
                      x = vm.mem[vm.pc+1]
                      y = vm.mem[vm.pc+2]
                      dest = vm.mem[vm.pc+3]
                      vm.mem[dest] = vm.mem[x] + vm.mem[y]
                      vm.pc += 4
                    },
                    ->(vm: VM) {
                      "ADD %i %i %i" % [vm.mem[vm.pc+1], vm.mem[vm.pc+2], vm.mem[vm.pc+3]]
                    }),
    2 => Opcode.new(:mul,
                    4,
                    ->(vm: VM) {
                      x = vm.mem[vm.pc+1]
                      y = vm.mem[vm.pc+2]
                      dest = vm.mem[vm.pc+3]
                      vm.mem[dest] = vm.mem[x] * vm.mem[y]
                      vm.pc += 4
                    },
                    ->(vm: VM) {
                      "MUL %i %i %i" % [vm.mem[vm.pc+1], vm.mem[vm.pc+2], vm.mem[vm.pc+3]]
                    }),
    99 => Opcode.new(:halt,
                     1,
                     ->(vm: VM) {
                       vm.halted = true
                       1
                     },
                     ->(vm: VM) {
                       "HALT"
                     }),
  }

  # Parse the input string into an array of integers
  def self.read_intcode(str)
    str.split(',')
      .map { |s| s.to_i }
      .reject { |x| !x.is_a? Integer }
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
