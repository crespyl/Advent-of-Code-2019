# This module define the "Intcode" interpreter, operating on arrays of Integer
module Intcode
  @@DEBUG = false

  # This class is just a holder for information about an Opcode, including Proc
  # objects for the implementation and a debug/display function
  class Opcode
    attr_reader :sym, :size, :impl, :disasm
    def initialize(sym, size, impl, disasm)
      @sym = sym
      @size = size
      @impl = impl
      @disasm = disasm
    end

    # Execute this opcode inside this VM
    def exec(vm)
      self.instance_exec(vm, &impl)
    end

    # Attempt to produce a debug string for this opcode
    def debug(vm)
      self.instance_exec(vm, &disasm)
    end
  end

  class VM
    attr_accessor :mem
    attr_accessor :pc
    attr_accessor :halted

    def initialize(mem)
      @mem = mem
      @pc = 0
      @halted = false
    end

    def self.from_file(filename)
      VM.new(Intcode::load_file(filename))
    end

    def self.from_string(str)
      VM.new(Intcode::read_intcode(str))
    end

    def run
      while !@halted && @pc < mem.length
        opcode = OPCODES[mem[pc]]
        if opcode == nil
          raise "INVALID OPCODE AT #{pc}: #{mem[pc]}"
        end

        Intcode::log("%4i: %s" % [pc, opcode.debug(self)])
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
                    Proc.new { |vm|
                      x = vm.mem[vm.pc+1]
                      y = vm.mem[vm.pc+2]
                      dest = vm.mem[vm.pc+3]
                      vm.mem[dest] = vm.mem[x] + vm.mem[y]
                      vm.pc += self.size
                    },
                    Proc.new { |vm|
                      "ADD %i %i %i" % [vm.mem[vm.pc+1], vm.mem[vm.pc+2], vm.mem[vm.pc+3]]
                    }),
    2 => Opcode.new(:mul,
                    4,
                    Proc.new { |vm|
                      x = vm.mem[vm.pc+1]
                      y = vm.mem[vm.pc+2]
                      dest = vm.mem[vm.pc+3]
                      vm.mem[dest] = vm.mem[x] * vm.mem[y]
                      vm.pc += self.size
                    },
                    Proc.new { |vm|
                      "MUL %i %i %i" % [vm.mem[vm.pc+1], vm.mem[vm.pc+2], vm.mem[vm.pc+3]]
                    }),
    99 => Opcode.new(:halt,
                     1,
                     Proc.new { |vm|
                       vm.halted = true
                     },
                     Proc.new { |vm|
                       "HALT"
                     }),
  }

  public

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
    VM::from_string(str)
  end

  # Load an Intcode VM from a file
  def self.load_vm_from_file(filename)
    VM::from_file(filename)
  end

  # Enable or disable verbose debug logging during execution
  def self.set_debug(enable_debug)
    @@DEBUG = enable_debug
  end

  private

  def self.log(msg)
    puts msg if @@DEBUG
  end
end
