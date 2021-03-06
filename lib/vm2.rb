module VM2

  class VM
    attr_accessor :name
    attr_accessor :debug

    attr_accessor :mem
    attr_accessor :pc
    attr_accessor :rel_base

    attr_accessor :status

    attr_accessor :input
    attr_accessor :output

    attr_accessor :input_fn
    attr_accessor :output_fn

    def initialize(mem)
      @name = "VM"
      @debug = false
      @pc = 0
      @rel_base = 0
      @status = :ok
      @mem = mem
      @input = []
      @output = []
    end

    def send_input(val)
      @input << val
      @status = :ok if @status == :needs_input
    end

    def read_output
      @output.shift
    end

    def read_input
      if @input_fn
        @input_fn.call()
      elsif ! @input.empty?
        @input.shift
      else
        @status = :needs_input
        nil
      end
    end

    def write_output(val)
      if @output_fn
        @output_fn.call(val)
      else
        @output << val
      end
    end

    def read_mem(address)
      (address-mem.size+1).times { |_| mem << 0 } if mem.size <= address
      mem[address]
    end

    def write_mem(address, val)
      (address-mem.size+1).times { |_| mem << 0 } if mem.size <= address
      mem[address] = val
    end

    def read_p(p)
      case p[0]
      when :position then read_mem(p[1])
      when :literal then p[1]
      when :relative then read_mem(rel_base + p[1])
      else raise "Unsupported addressing mode for read #{p}"
      end
    end

    def write_p(p, val)
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
      instr = mem[pc]
      opcode = instr % 100

      instr /= 100
      [opcode,
       (1..n_params).map { |i| m = mode(instr % 10); instr /= 10; [m, read_mem(pc + i)] }
      ]
    end

    def exec
      opcode, params = decode()
      log "%5i : %05i : %s" % [pc, mem[pc], VM2.disasm(opcode, params)]

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
        raise "invalid opcode at #{pc}"
      end

    end

    def run
      while status != :halted && status != :needs_input && pc < mem.size
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
                 when  1 then [" ADD",  3]
                 when  2 then [" MUL",  3]
                 when  3 then ["  IN",  1]
                 when  4 then [" OUT",  1]
                 when  5 then ["  JT",  2]
                 when  6 then ["  JF",  2]
                 when  7 then ["  LT",  3]
                 when  8 then ["  EQ",  3]
                 when  9 then [" REL",  1]
                 when 99 then ["HALT",  0]
                 else ["???", 3]
                 end
    "%3s: %s" % [name, params[0..args].map { |p| case p[0]
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
    mem = str.chomp.split(',').map(&:to_i)
    VM.new(mem)
  end

end
