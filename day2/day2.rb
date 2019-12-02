#!/usr/bin/env ruby

# Day 2 has us implementing an "Intcode" VM
#
# The only defined opcodes are as follows:
#   1: ADD $addr_a $addr_b $dest
#   2: MUL $addr_a $addr_b $dest
#  99: HALT

# First task it to parse the input string into an array of integers
def read_intcode(str)
  str.split(',')
    .map { |s| s.to_i }
    .reject { |x| !x.is_a? Integer }
end

# Map from an integer to an opcode symbol
def get_opcode(int)
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
def exec_intcode(mem)
  pc = 0
  while (current_opcode = get_opcode(mem[pc])) != :invalid
    case current_opcode
    when :add
      # puts("got :add at #{pc}")
      x = mem[pc+1]
      y = mem[pc+2]
      dest = mem[pc+3]
      # puts("    add #{x} #{y}, #{dest}")
      mem[dest] = mem[x] + mem[y]
      pc += 4
    when :mul
      # puts("got :mul at #{pc}")
      x = mem[pc+1]
      y = mem[pc+2]
      dest = mem[pc+3]
      # puts("    mul #{x} #{y}, #{dest}")
      mem[dest] = mem[x] * mem[y]
      pc += 4
    when :halt
      # puts("got :halt at #{pc}")
      break
    else
      puts "Invalid opcode at #{pc}: #{mem[pc]}"
      break
    end
  end
end

# The puzzle requires us to set a few addresses to a particular value before
# execution
def init_puzzle(mem, noun=12, verb=2)
  mem[1] = noun
  mem[2] = verb
end

# Load an Intcode program from a filename
def load_file(filename)
  read_intcode(File.read(filename))
end

# The above is sufficient to solve part 1, part 2 requires us to find the
# parameters to init_puzzle ("noun" and "verb", in the range 0-99) that produce
# the output 19690720
#
# The puzzle asks the question "what is 100 * noun + verb"
def search(filename="input.txt")
  mem = [0]
  results = {noun: 0, verb: 0, output: 0}

  catch (:done) do
    for noun in 0..99
      for verb in 0..99
        mem = load_file(filename)
        init_puzzle(mem, noun, verb)
        exec_intcode(mem)
        if mem[0] == 19690720 || (noun > 99 && verb > 99)
          results = {noun: noun, verb: verb, output: mem[0]}
          break;
        end
      end
    end
  end

  return results
end

# Do this stuff if running from the command line
# ==============================================
if ARGV[0] == nil
  puts "usage: ./day2.rb <input filename>"
  exit 1
end

puts "Part 1"
mem = load_file(ARGV[0])
init_puzzle(mem)
exec_intcode(mem)
puts "Output: #{mem[0]}"

puts "\n"
puts "Part 2"
puts "searching..."
t_start = Time.now
results = search(ARGV[0])
t_end = Time.now
puts "search completed in %0.2fs" % (t_end - t_start)
puts "  output: #{results[:output]}"
puts "    noun: #{results[:noun]}"
puts "    verb: #{results[:verb]}"
puts "solution: #{100 * results[:noun] + results[:verb]}"
