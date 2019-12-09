# This module define the "Intcode" interpreter, operating on arrays of Integer

module Intcode
  @@DEBUG = false

  # This class is just a holder for information about an Opcode, including Proc
  # objects for the implementation and a debug/display function
  class Opcode
    attr_accessor :sym
    attr_accessor :size
    attr_accessor :impl
    attr_accessor :disasm

    def initialize(sym, size, impl, disasm)
      @sym = sym
      @size = size
      @impl = impl
      @disasm = disasm
    end

    def num_params
      size - 1
    end

    # Execute this opcode inside this VM (we pass the actual instruction as well
    # so that the opcode can parse out its addressing modes)
    def exec(vm, params)
      impl.call(vm, params)
    end

    # Attempt to produce a debug string for this opcode
    def debug(vm, params)
      disasm.call(vm, params)
    end

    # Map from mode number to symbols
    def self.lookup_addressing_mode(m)
      case m
      when 0 then :position
      when 1 then :literal
      when 2 then :relative
      else raise "Unsupported addressing mode #{m}"
      end
    end

    # Get the opcode and parameters at the given address
    def self.get_opcode_and_params(vm, address)
      instr = vm.mem[address]
      opcode, modes = get_opcode_and_modes(instr)
      [opcode, modes.each_with_index.map { |m,i| Parameter.new(m, vm.mem[address + i + 1]) }]
    end

    # Get the opcode and addressing modes for a given instruction
    def self.get_opcode_and_modes(instr)
      opcode = OPCODES[instr % 100]
      modes = []

      instr /= 100 # cut off the opcode so we're left with just the mode part
      while modes.size < opcode.num_params
        modes << lookup_addressing_mode(instr % 10)
        instr /= 10
      end

      [opcode, modes]
    end
  end

  # Represents an encoded parameter and its addressing mode
  class Parameter
    attr_accessor :val # the original value in memory
    attr_accessor :mode

    def initialize(mode, val)
      @mode = mode
      @val = val
    end

    def debug
      case mode
      when :position then "@#{val}"
      when :literal then "#{val}"
      else
        "??"
      end
    end
  end

  # This class holds the current state of a running interpreter: the memory
  # (Array(Int32)), the program counter, and a "halted/running" flag
  class VM
    # Name
    attr_accessor :name

    # Memory
    attr_accessor :mem

    # Registers
    attr_accessor :pc

    # Status flags
    attr_accessor :halted
    attr_accessor :needs_input

    # I/O Buffers
    attr_accessor :inputs
    attr_accessor :outputs

    # relative base
    attr_accessor :rel_base


    def initialize(mem,name="VM")
      @name = name
      @pc = 0
      @rel_base = 0
      @halted = false
      @needs_input = false
      @mem = 4096.times.collect { |i| mem[i] || 0 }
      @inputs = []
      @outputs = []
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
    def read_param(p)
      case p.mode
      when :position then mem[p.val]
      when :literal then p.val
      when :relative then mem[@rel_base + p.val]
      else
        raise "Unsupported addressing mode for #{p}"
      end
    end

    # Set the address indicated by the parameter to the given value
    def write_param_value(p, val)
      case p.mode
      when :position then mem[p.val] = val
      when :literal then raise "Cannot write to literal"
      when :relative then mem[@rel_base + p.val] = val
      else
        raise "Unsupported addressing mode for #{p}"
      end
    end

    # Run the machine until it stops for some reason
    #
    # Returns the reason why it stopped:
    #
    #   :halted       Executed a HALT instruction
    #
    #   :needs_input  Executed an INPUT instruction, but the input buffer was
    #                 empty, fill the input buffer and call run again to resume
    #
    #   :pc_range_err PC was moved out of the valid memory range
    def run
      while !@halted && !@needs_input && @pc < mem.size
        opcode, params = Opcode.get_opcode_and_params(self, pc)
        if opcode == nil
        end

        Intcode.log("%5i %05i: %s" % [pc, mem[pc], opcode.debug(self, params)])
        opcode.exec(self, params)
      end

      if @halted
        return :halted
      elsif @needs_input
        return :needs_input
      elsif @pc >= mem.size
        return :pc_range_err
      end
    end

    # Get the status of the VM
    def status
      if @halted
        :halted
      elsif @needs_input
        :needs_input
      elsif @pc >= @mem.size
        :pc_range_err
      else
        :ok
      end
    end

    def send_input(val)
      inputs << val
      @needs_input = false
    end

    def get_input
      if inputs.size > 0
        input = inputs.shift
        Intcode.log "%50s" % "< #{input}"
        return input
      else
        @needs_input = true
        Intcode.log "NEED INPUT"
        return nil
      end
    end

    # Read a value from the amps output buffer, or 0 if the buffer is empty
    def read_output()
      if outputs.size > 0
        outputs.shift
      else
        nil
      end
    end

    def write_output(val)
      outputs << val
      Intcode.log "%50s" % "> #{val}"
    end
  end

  # Here we define the mapping from integer to opcode, along with the actual
  # implementation of each, as Proc objects that get bound to the Opcode
  # instance during execution
  OPCODES = {
    1 => Opcode.new(:add,
                    4,
                    ->(vm, params) {
                      x, y, dest = params
                      vm.write_param_value(dest, vm.read_param(x) + vm.read_param(y))
                      vm.pc += 4
                    },
                    ->(vm, params) {
                      "ADD %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    2 => Opcode.new(:mul,
                    4,
                    ->(vm, params) {
                      x, y, dest = params
                      vm.write_param_value(dest, vm.read_param(x) * vm.read_param(y))
                      vm.pc += 4
                    },
                    ->(vm, params) {
                      "MUL %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    3 => Opcode.new(:input,
                    2,
                    ->(vm, params) {
                      dest = params.first
                      if input = vm.get_input
                        vm.write_param_value(dest, input)
                        vm.pc += 2
                      else
                        0
                      end
                    },
                    ->(vm, params) {
                      "IN  -> %5s" % params.map { |p| p.debug }
                    }),
    4 => Opcode.new(:output,
                    2,
                    ->(vm, params) {
                      x = params.first
                      vm.write_output(vm.read_param(x))
                      vm.pc += 2
                    },
                    ->(vm, params) {
                      "OUT %5s" % params.map { |p| p.debug }
                    }),
    5 => Opcode.new(:jt,
                    3,
                    ->(vm, params) {
                      x, dest = params
                      if vm.read_param(x) != 0
                        vm.pc = vm.read_param(dest)
                      else
                        vm.pc += 3
                      end
                    },
                    ->(vm, params) {
                      "JT  %5s, %5s" % params.map { |p| p.debug }
                    }),
    6 => Opcode.new(:jf,
                    3,
                    ->(vm, params) {
                      x, dest = params
                      if vm.read_param(x) == 0
                        vm.pc = vm.read_param(dest)
                      else
                        vm.pc += 3
                      end
                    },
                    ->(vm, params) {
                      "JF  %5s, %5s" % params.map { |p| p.debug }
                    }),
    7 => Opcode.new(:lt,
                    4,
                    ->(vm, params) {
                      x, y, dest = params
                      if vm.read_param(x) < vm.read_param(y)
                        vm.write_param_value(dest, 1)
                      else
                        vm.write_param_value(dest, 0)
                      end
                      vm.pc += 4
                    },
                    ->(vm, params) {
                      "LT  %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    8 => Opcode.new(:eq,
                    4,
                    ->(vm, params) {
                      x, y, dest = params
                      if vm.read_param(x) == vm.read_param(y)
                        vm.write_param_value(dest, 1)
                      else
                        vm.write_param_value(dest, 0)
                      end
                      vm.pc += 4
                    },
                    ->(vm, params) {
                      "EQ  %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    9 => Opcode.new(:adj_rel_base,
                    2,
                    ->(vm, params) {
                      x = params.first
                      vm.rel_base += vm.read_param(x)
                      vm.pc += 2
                    },
                    ->(vm, params) {
                      "REL  %5s" % params.map { |p| p.debug }
                    }),
    99 => Opcode.new(:halt,
                     1,
                     ->(vm, params) {
                       vm.halted = true
                       1
                     },
                     ->(vm, params) {
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
