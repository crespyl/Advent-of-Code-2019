# This module defines the "Intcode" interpreter and several utility functions
# for dealing with opcodes and parameter handling
module Intcode
  @@DEBUG = false

  # Each supported opcode is represented as instance of the Opcode class, with
  # the implementation attached as a Proc, along with a function to generate
  # simplistic human-readable string for debugging
  class Opcode
    property sym : Symbol
    property size : Int32
    property impl : Proc(VM, Array(Parameter), Int32)
    property disasm : Proc(VM, Array(Parameter), String)

    def initialize(@sym, @size, @impl, @disasm)
    end

    # We use opcode size to indicate both how far the PC should move after
    # execution and the number of parameters. Number of parameters is always
    # size-1 since size includes the instruction itself.
    def num_params
      size - 1
    end

    # Execute this opcode in the context of the given VM, with the provided
    # params.  Delagates to the attached Proc.
    def exec(vm, params)
      impl.call(vm, params)
    end

    # Return a (more or less) human-readable string describing this instruction
    def debug(vm, params)
      disasm.call(vm, params)
    end

    # Get the opcode and addressing modes for a given instruction, returns a
    # tuple with the Opcode instance and an array of addressing mode symbols
    def self.get_opcode_and_modes(instr : Int32)
      opcode = OPCODES[instr % 100]
      modes = [] of Symbol

      instr //= 100 # cut off the opcode so we're left with just the mode part
      while modes.size < opcode.num_params
        modes << Intcode.lookup_addressing_mode(instr % 10)
        instr //= 10
      end

      {opcode, modes}
    end

    # Get the opcode and parameters at the given address. Same as
    # Opcode::get_opcode_and_modes, but parses out the actual parameters from
    # the VM memory.
    def self.get_opcode_and_params(vm : VM, address : Int32)
      instr = vm.mem[address]
      opcode, modes = get_opcode_and_modes(instr)
      {opcode, modes.map_with_index { |m,i| Parameter.new(m, vm.mem[address + i + 1]) }}
    end
  end

  # Represents an encoded parameter and its addressing mode
  struct Parameter
    property val : Int32   # The original value in memory
    property mode : Symbol # The addressing mode

    def initialize(@mode, @val) end

    # Return a debug string indicating the mode and value, used for debug and
    # disasm
    def debug
      case mode
      when :position then "@#{val}"
      when :literal then "#{val}"
      else
        "?#{mode}:#{val}"
      end
    end
  end

  # This class holds the current state of a running interpreter: the memory
  # (Array(Int32)), the program counter, and a "halted/running" flag, and
  # buffers for input/output values.
  class VM
    # Memory
    property mem : Array(Int32)

    # Registers
    property pc : Int32

    # Status flags
    property halted : Bool
    property needs_input : Bool

    # I/O Buffers
    property inputs : Array(Int32)
    property outputs : Array(Int32)

    def initialize(mem)
      @pc = 0
      @halted = false
      @needs_input = false
      @mem = mem #Array.new(4096, 0)
      @inputs = [] of Int32
      @outputs = [] of Int32
    end

    # Get the value of the provided parameter, based on the addressing mode
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

    # Run the machine until it stops for some reason
    #
    # Returns the reason why it stopped:
    #
    #   :halted       Executed a HALT instruction
    #
    #   :needs_input  Executed an INPUT instruction, but the input buffer was
    #                 empty, fill the input buffer with send_input and call run
    #                 again to resume
    #
    #   :pc_range_err PC was moved out of the valid memory range
    def run
      while !@halted && !@needs_input && @pc < mem.size
        # fetch the next Opcode and its Parameters
        opcode, params = Opcode.get_opcode_and_params(self, pc)
        raise "INVALID OPCODE AT #{pc}: #{mem[pc]}" unless opcode

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

    # Add a value to the back of the input buffer
    def send_input(val : Int32)
      inputs << val
      @needs_input = false
    end

    # Remove and return a value from the front of the input buffer.
    #
    # If the input buffer is empty, sets the appropriate flag and returns nil
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

    def write_output(val)
      outputs << val
      Intcode.log "%50s" % "> #{val}"
    end

    def self.from_file(filename)
      VM.new(Intcode.load_file(filename))
    end

    def self.from_string(str)
      VM.new(Intcode.read_intcode(str))
    end
  end

  # Map from addressing mode digit to symbol
  def self.lookup_addressing_mode(m)
    case m
    when 0 then :position
    when 1 then :literal
    else raise "Unsupported addressing mode #{m}"
    end
  end

  # Here we define the mapping from integer to Opcode, along with the actual
  # implementation of each as a Proc
  OPCODES = {
    1 => Opcode.new(:add, 4,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, y, dest = params
                      vm.write_param_value(dest, vm.read_param(x) + vm.read_param(y))
                      vm.pc += params.size+1
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "ADD %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    2 => Opcode.new(:mul, 4,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, y, dest = params
                      vm.write_param_value(dest, vm.read_param(x) * vm.read_param(y))
                      vm.pc += params.size+1
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "MUL %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    3 => Opcode.new(:input, 2,
                    ->(vm: VM, params: Array(Parameter)) {
                      dest = params.first
                      if input = vm.get_input
                        vm.write_param_value(dest, input)
                        vm.pc += params.size+1
                      else
                        0
                      end
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "IN  -> %5s" % params.map { |p| p.debug }
                    }),
    4 => Opcode.new(:output, 2,
                    ->(vm: VM, params: Array(Parameter)) {
                      x = params.first
                      vm.write_output(vm.read_param(x))
                      vm.pc += params.size+1
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "OUT %5s" % params.map { |p| p.debug }
                    }),
    5 => Opcode.new(:jt, 3,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, dest = params
                      if vm.read_param(x) != 0
                        vm.pc = vm.read_param(dest)
                      else
                        vm.pc += params.size+1
                      end
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "JT  %5s, %5s" % params.map { |p| p.debug }
                    }),
    6 => Opcode.new(:jf, 3,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, dest = params
                      if vm.read_param(x) == 0
                        vm.pc = vm.read_param(dest)
                      else
                        vm.pc += params.size+1
                      end
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "JF  %5s, %5s" % params.map { |p| p.debug }
                    }),
    7 => Opcode.new(:lt, 4,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, y, dest = params
                      if vm.read_param(x) < vm.read_param(y)
                        vm.write_param_value(dest, 1)
                      else
                        vm.write_param_value(dest, 0)
                      end
                      vm.pc += params.size+1
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "LT  %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    8 => Opcode.new(:eq, 4,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, y, dest = params
                      if vm.read_param(x) == vm.read_param(y)
                        vm.write_param_value(dest, 1)
                      else
                        vm.write_param_value(dest, 0)
                      end
                      vm.pc += 4
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "EQ  %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    99 => Opcode.new(:halt, 1,
                     ->(vm: VM, params : Array(Parameter)) {
                       vm.halted = true
                       1
                     },
                     ->(vm: VM, params : Array(Parameter)) {
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

  # Enable or disable verbose debug logging during execution
  def self.set_debug(enable_debug)
    @@DEBUG = enable_debug
  end

  def self.log(msg)
    puts msg if @@DEBUG
  end
end
