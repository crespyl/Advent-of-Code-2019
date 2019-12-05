# This module define the "Intcode" interpreter, operating on arrays of Integer

module Intcode
  @@DEBUG = false

  # This class is just a holder for information about an Opcode, including Proc
  # objects for the implementation and a debug/display function
  class Opcode
    property sym : Symbol
    property size : Int32
    property impl : Proc(VM, Array(Parameter), Int32)
    property disasm : Proc(VM, Array(Parameter), String)

    def initialize(@sym, @size, @impl : Proc(VM, Array(Parameter), Int32), @disasm)
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
      else raise "Unsupported addressing mode #{m}"
      end
    end

    # Get the opcode and parameters at the given address
    def self.get_opcode_and_params(vm, address)
      instr = vm.mem[address]
      opcode, modes = get_opcode_and_modes(instr)
      {opcode, modes.map_with_index { |m,i| Parameter.new(m, vm.mem[address + i + 1]) }}
    end

    # Get the opcode and addressing modes for a given instruction
    def self.get_opcode_and_modes(instr)
      opcode = OPCODES[instr % 100]
      modes = [] of Symbol

      instr //= 100 # cut off the opcode so we're left with just the mode part
      while modes.size < opcode.num_params
        modes << lookup_addressing_mode(instr % 10)
        instr //= 10
      end

      {opcode, modes}
    end
  end

  # Represents an encoded parameter and its addressing mode
  struct Parameter
    property val : Int32 # the original value in memory
    property mode : Symbol

    def initialize(@mode, @val)
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
        begin
          opcode, params = Opcode.get_opcode_and_params(self, pc)
        rescue
          raise "INVALID OPCODE AT #{pc}: #{mem[pc]}"
        end
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

    def send_input(val : Int32)
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
                    ->(vm: VM, params: Array(Parameter)) {
                      x, y, dest = params
                      vm.write_param_value(dest, vm.read_param(x) + vm.read_param(y))
                      vm.pc += 4
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "ADD %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    2 => Opcode.new(:mul,
                    4,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, y, dest = params
                      vm.write_param_value(dest, vm.read_param(x) * vm.read_param(y))
                      vm.pc += 4
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "MUL %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    3 => Opcode.new(:input,
                    2,
                    ->(vm: VM, params: Array(Parameter)) {
                      dest = params.first
                      if input = vm.get_input
                        vm.write_param_value(dest, input)
                        vm.pc += 2
                      else
                        0
                      end
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "IN  -> %5s" % params.map { |p| p.debug }
                    }),
    4 => Opcode.new(:output,
                    2,
                    ->(vm: VM, params: Array(Parameter)) {
                      x = params.first
                      vm.write_output(vm.read_param(x))
                      vm.pc += 2
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "OUT %5s" % params.map { |p| p.debug }
                    }),
    5 => Opcode.new(:jt,
                    3,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, dest = params
                      if vm.read_param(x) != 0
                        vm.pc = vm.read_param(dest)
                      else
                        vm.pc += 3
                      end
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "JT  %5s, %5s" % params.map { |p| p.debug }
                    }),
    6 => Opcode.new(:jf,
                    3,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, dest = params
                      if vm.read_param(x) == 0
                        vm.pc = vm.read_param(dest)
                      else
                        vm.pc += 3
                      end
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "JF  %5s, %5s" % params.map { |p| p.debug }
                    }),
    7 => Opcode.new(:lt,
                    4,
                    ->(vm: VM, params: Array(Parameter)) {
                      x, y, dest = params
                      if vm.read_param(x) < vm.read_param(y)
                        vm.write_param_value(dest, 1)
                      else
                        vm.write_param_value(dest, 0)
                      end
                      vm.pc += 4
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "LT  %5s, %5s -> %5s" % params.map { |p| p.debug }
                    }),
    8 => Opcode.new(:eq,
                    4,
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
    99 => Opcode.new(:halt,
                     1,
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
