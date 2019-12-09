require "./intcode.cr"

module Intcode
  # Each supported opcode is represented as instance of the Opcode class, with
  # the implementation attached as a Proc, along with a function to generate
  # simplistic human-readable string for debugging
  class Opcode
    property sym : Symbol
    property size : Int32
    property impl : Proc(VM, Array(Parameter), Int64)
    property disasm : Proc(VM, Array(Parameter), String)

    def initialize(@sym, @size, @impl, @disasm)
    end

    # We use opcode size to indicate both how far the PC should move after
    # execution and the number of parameters. Number of parameters is always
    # `size-1` since size includes the instruction itself.
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

    # Returns a tuple with the `Opcode` corresponding to the instruction at the
    # *address* and an array holding the `Parameter`s that follow it
    def self.get_opcode_and_params(vm : VM, address : Int64)
      instr = vm.mem[address]
      opcode, modes = get_opcode_and_modes(instr)
      {opcode, modes.map_with_index { |m,i| Parameter.new(m, vm.mem[address + i + 1]) }}
    end

    # Get the opcode and addressing modes for a given instruction, returns a
    # tuple with the `Opcode` instance and an array of addressing mode symbols
    private def self.get_opcode_and_modes(instr : Int64)
      opcode = OPCODES[instr % 100]
      modes = [] of Symbol

      instr //= 100 # cut off the opcode so we're left with just the mode part
      while modes.size < opcode.num_params
        modes << Intcode.lookup_addressing_mode(instr % 10)
        instr //= 10
      end

      {opcode, modes}
    end

  end

  # Map from addressing mode digit to symbol
  protected def self.lookup_addressing_mode(m)
    case m
    when 0 then :position
    when 1 then :literal
    when 2 then :relative
    else raise "Unsupported addressing mode #{m}"
    end
  end

  # Here we define the mapping from integer to `Opcode`, along with the actual
  # implementation of each as a `Proc`
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
                        0_i64
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
    9 => Opcode.new(:adj_rel_base,
                    2,
                    ->(vm: VM, params: Array(Parameter)) {
                      x = params.first
                      vm.rel_base += vm.read_param(x)
                      vm.pc += 2
                    },
                    ->(vm: VM, params: Array(Parameter)) {
                      "REL %5s" % params.map { |p| p.debug }
                    }),
    99 => Opcode.new(:halt, 1,
                     ->(vm: VM, params : Array(Parameter)) {
                       vm.halted = true
                       1_i64
                     },
                     ->(vm: VM, params : Array(Parameter)) {
                       "HALT"
                     }),
  }

end
