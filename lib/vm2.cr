module VM2

  class VM
    property name : String
    property debug : Bool

    property mem : Array(Int64)
    property pc : Int64
    property rel_base : Int64

    property status : Symbol
    property error : String | Nil

    property cycles : Int64

    property input : Array(Int64)
    property output : Array(Int64)

    property input_fn : Proc(Int64) | Nil
    property output_fn : Proc(Int64, Nil) | Nil
    property exec_hook_fn : Proc(VM, Nil) | Nil

    def initialize(mem : Array(Int64))
      @name = "VM"
      @debug = false
      @pc = 0
      @rel_base = 0
      @cycles = 0
      @status = :ok
      @mem = mem
      @input = [] of Int64
      @output = [] of Int64
    end

    def clone
      new_vm = VM.new(@mem)
      new_vm.debug = @debug
      new_vm.pc = @pc
      new_vm.rel_base = @rel_base
      new_vm.cycles = @cycles
      new_vm.status = @status
      new_vm.mem = @mem.clone
      new_vm.input = @input
      new_vm.output = @output
      new_vm.input_fn = @input_fn
      new_vm.output_fn = @output_fn
      new_vm.exec_hook_fn = @exec_hook_fn
      new_vm
    end

    def send_input(val : Int64)
      @input << val
      @status = :ok if @status == :needs_input
    end

    def send_input(val : Int32)
      send_input(val.to_i64)
    end

    def read_output
      @output.shift?
    end

    def read_output_or_raise : Int64
      @output.shift? || raise "#{name} tried to read from empty output buffer"
    end

    def read_input
      if @input_fn
        @input_fn.try { |f| f.call() }
      elsif ! @input.empty?
        @input.shift
      else
        @status = :needs_input
        nil
      end
    end

    def write_output(val)
      if @output_fn
        @output_fn.try { |f| f.call(val) }
      else
        @output << val
      end
    end

    def read_mem(address)
      @mem[address]? || 0_i64
    end

    def write_mem(address, val)
      @mem += [0_i64] * (address-@mem.size+1) if @mem.size <= address
      @mem[address] = val
    end

    def read_p(p)
      case p[0]
      when :position then read_mem(p[1])
      when :relative then read_mem(rel_base + p[1])
      when :literal then p[1]
      else raise "Unsupported addressing mode for read #{p}"
      end
    end

    def write_p(p, val : Int64)
      case p[0]
      when :position then write_mem(p[1], val)
      when :relative then write_mem(rel_base + p[1], val)
      when :literal then raise "Cannot write to literal #{p} #{val}"
      end
    end

    def mode(m)
      case m
      when 0 then :position
      when 1 then :literal
      when 2 then :relative
      else raise "Unsupported addressing mode #{m}"
      end
    end

    def decode(n_params=3)
      instr = read_mem(pc)
      opcode = instr % 100

      instr //= 100
      {opcode,
       (1..n_params).map { |i| m = mode(instr % 10); instr //= 10; {m, read_mem(pc + i)} }
      }
    end

    def exec
      @exec_hook_fn.try { |fn| fn.call(self) }
      @cycles += 1
      opcode, params = decode
      log "%5i : %05i : %s" % [pc, read_mem(pc), VM2.disasm(opcode, params)]

      case opcode
      when 1 # add
        write_p(params[2], read_p(params[0]) + read_p(params[1]))
        @pc += 4
      when 2 # mul
        write_p(params[2], read_p(params[0]) * read_p(params[1]))
        @pc += 4
      when 3 # input
        if i = read_input
          write_p(params[0], i)
          @pc += 2
        else
          return :needs_input
        end
      when 4 # output
        write_output(read_p(params[0]))
        @pc += 2
      when 5 # jt
        if read_p(params[0]) != 0
          @pc = read_p(params[1])
        else
          @pc += 3
        end
      when 6 # jf
        if read_p(params[0]) == 0
          @pc = read_p(params[1])
        else
          @pc += 3
        end
      when 7 # lt
        if read_p(params[0]) < read_p(params[1])
          write_p(params[2], 1)
        else
          write_p(params[2], 0)
        end
        @pc += 4
      when 8 # eq
        if read_p(params[0]) == read_p(params[1])
          write_p(params[2], 1)
        else
          write_p(params[2], 0)
        end
        @pc += 4
      when 9 # rel
        @rel_base += read_p(params[0])
        @pc += 2
      when 99
        @status = :halted
        @pc += 1
      else
        @status = :halted
        @error = "invalid opcode at #{pc}"
      end

    end

    def run
      while status != :halted && status != :needs_input && pc < mem.size
        exec
      end
      return status
    end

    def run_until_io
      puts "run start"
      while status != :halted && status != :needs_input && output.size == 0
        exec
      end
      return status
    end

    def log(msg)
      puts "(#{name}) #{msg}" if @debug
    end

  end

  def self.disasm(opcode, params)
    name, args = case opcode
                 when  1 then {" ADD",  3}
                 when  2 then {" MUL",  3}
                 when  3 then {"  IN",  1}
                 when  4 then {" OUT",  1}
                 when  5 then {"  JT",  2}
                 when  6 then {"  JF",  2}
                 when  7 then {"  LT",  3}
                 when  8 then {"  EQ",  3}
                 when  9 then {" REL",  1}
                 when 99 then {"HALT",  0}
                 else {"???", 3}
                 end
    "%3s: %s" % [name, params.first(args).map { |p| case p[0]
                                                when :literal then p[1]
                                                when :position then "@%i" % p[1]
                                                when :relative then "$%i" % p[1]
                                                else "?%i" % p[1]
                                                end }.join(", ")]
  end

  def self.from_file(filename)
    from_string(File.read(filename))
  end

  def self.from_string(str)
    mem = str.chomp.split(',').map{ |s| s.to_i64 }
    VM.new(mem)
  end

end
