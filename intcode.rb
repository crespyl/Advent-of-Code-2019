# This module define the "Intcode" interpreter, operating on arrays of Integer
module Intcode
  @@DEBUG = false

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

  # Map from an Integer to an opcode symbol
  def self.get_opcode(int)
    case int
    when 1 then :add
    when 2 then :mul
    when 99 then :halt
    else :invalid
    end
  end

  # This is the actual interpreter; given an Intcode machine state (an array of
  # integers), we start at index 0 and attempt to process each opcode in turn
  # until we reach a HALT, then return the final state of the machine
  def self.exec_intcode(mem)
    pc = 0
    while (current_opcode = get_opcode(mem[pc])) != :invalid
      case current_opcode
      when :add
        log("got :add at #{pc}")
        x = mem[pc+1]
        y = mem[pc+2]
        dest = mem[pc+3]
        log("    add #{x} #{y}, #{dest}")
        mem[dest] = mem[x] + mem[y]
        pc += 4
      when :mul
        log("got :mul at #{pc}")
        x = mem[pc+1]
        y = mem[pc+2]
        dest = mem[pc+3]
        log("    mul #{x} #{y}, #{dest}")
        mem[dest] = mem[x] * mem[y]
        pc += 4
      when :halt
        log("got :halt at #{pc}")
        break
      else
        log("Invalid opcode at #{pc}: #{mem[pc]}")
        break
      end
    end
  end

  def self.set_debug_log(enable_debug)
    @@DEBUG = enable_debug
  end

  private

  def self.log(msg)
    puts msg if @@DEBUG
  end
end
