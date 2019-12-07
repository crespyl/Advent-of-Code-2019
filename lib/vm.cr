require "./intcode.cr"

module Intcode
  # This class holds the current state of a running interpreter: the memory
  # (Array(Int32)), the program counter, and a "halted/running" flag, and
  # buffers for input/output values.
  class VM
    # Name for debugging
    property name : String

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
      @name = "VM"
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
      log("Running...")

      while !@halted && !@needs_input && @pc < mem.size
        # fetch the next Opcode and its Parameters
        opcode, params = Opcode.get_opcode_and_params(self, pc)
        raise "INVALID OPCODE AT #{pc}: #{mem[pc]}" unless opcode

        log("%5i %05i: %s" % [pc, mem[pc], opcode.debug(self, params)])
        opcode.exec(self, params)
      end

      log("Stopped")
      return status
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

    # Add a value to the back of the input buffer
    def send_input(val : Int32)
      inputs << val
      @needs_input = false
    end

    # Read a value from the amps output buffer, or 0 if the buffer is empty
    def read_output()
      if outputs.size > 0
        outputs.shift
      else
        nil
      end
    end

    # Remove and return a value from the front of the input buffer.
    #
    # If the input buffer is empty, sets the appropriate flag and returns nil
    def get_input
      if inputs.size > 0
        input = inputs.shift
        log "%50s" % "< #{input}"
        return input
      else
        @needs_input = true
        log "NEED INPUT"
        return nil
      end
    end

    def write_output(val)
      outputs << val
      log "%50s" % "> #{val}"
    end

    def log(msg)
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
