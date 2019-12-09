require "./intcode.cr"

module Intcode
  # This class holds the current state of a running interpreter: the memory
  # (`Array(Int64)`), the program counter, and a "halted/running" flag, and
  # buffers for input/output values.
  class VM
    # Name for debugging
    property name : String

    # Memory
    property mem : Array(Int64)

    # Registers

    # The program counter, the address in memory to read the next instruction
    property pc : Int64

    # Relative base, used in opcode 9 and relative addressing
    property rel_base : Int64

    # Status flags

    # Indicates whether the machine has executed a HALT instruction
    property halted : Bool

    # Indicates whether the machine is blocked waiting on input
    property needs_input : Bool

    # Input buffer
    property inputs : Array(Int64)
    # Output buffer
    property outputs : Array(Int64)

    def initialize(mem : Array(Int64))
      @name = "VM"
      @pc = 0
      @rel_base = 0
      @halted = false
      @needs_input = false
      @mem = mem
      @inputs = [] of Int64
      @outputs = [] of Int64
    end

    def read_or_grow_mem(address)
      if mem.size <= address
        (address-mem.size+1).times { |_| mem << 0 }
      end
      mem[address]
    end

    def write_or_grow_mem(address, val)
      if mem.size <= address
        (address-mem.size+1).times { |_| mem << 0 }
      end
      mem[address] = val
    end

    # Get the value of the provided parameter, based on the addressing mode
    protected def read_param(p : Parameter)
      case p.mode
      when :position then read_or_grow_mem(p.val)
      when :relative then read_or_grow_mem(@rel_base + p.val)
      when :literal then p.val
      else
        raise "Unsupported addressing mode for #{p}"
      end
    end

    # Set the address indicated by the parameter to the given value
    protected def write_param_value(p : Parameter, val : Int64)
      case p.mode
      when :position then write_or_grow_mem(p.val, val)
      when :relative then write_or_grow_mem(@rel_base + p.val, val)
      when :literal then raise "Cannot write to literal"
      else
        raise "Unsupported addressing mode for #{p}"
      end
    end

    # Run the machine until it stops for some reason
    #
    # Returns a Symbol with the machine status after execution stops for any
    # reason, see `VM#status` for details
    def run
      log("Running...") if status == :ok

      while status == :ok
        # fetch the next Opcode and its Parameters
        opcode, params = Opcode.get_opcode_and_params(self, pc)
        raise "INVALID OPCODE AT #{pc}: #{mem[pc]}" unless opcode

        log("%5i %05i: %s" % [pc, mem[pc], opcode.debug(self, params)])
        opcode.exec(self, params)
      end

      log("Stopped (#{status})")
      return status
    end

    # Get the status of the VM
    #
    # Result can be any of the following
    #
    #   `:halted` => the machine executed a HALT instruction and will not run any
    #   further
    #
    #   `:needs_input` => the machine attempted to execut an INPUT instruction
    #   while the input buffer was empty. The machine can be resumed after
    #   adding input to the buffer with `VM#send_input`
    #
    #   `:pc_range_err` => the program counter ran past the end of the machines
    #   memory
    #
    #   `:ok` => the machine is ready to execute
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

    # Add a value to the back of the input buffer
    def send_input(val : Int64)
      inputs << val
      @needs_input = false
    end

    # Read a value from the amps output buffer, or nil if the buffer is empty
    def read_output()
      outputs.shift?
    end

    # Remove and return a value from the front of the input buffer.
    #
    # If the input buffer is empty, sets the appropriate flag and returns nil
    protected def get_input
      if input = inputs.shift?
        log "%50s" % "< #{input}"
        return input
      else
        @needs_input = true
        return nil
      end
    end

    # Add a value to the output buffer
    protected def write_output(val)
      outputs << val
      log "%50s" % "> #{val}"
    end

    private def log(msg)
      Intcode.log("(#{name}) #{msg}")
    end

    def self.from_file(filename)
      VM.new(Intcode.load_file(filename))
    end

    def self.from_string(str)
      VM.new(Intcode.read_intcode(str))
    end
  end

end
