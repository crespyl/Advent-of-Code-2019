#!/usr/bin/env ruby
require_relative "../lib/intcode.rb"

# The puzzle requires us to set a few addresses to a particular value before
# execution
def init_puzzle(mem, noun=12, verb=2)
  mem[1] = noun
  mem[2] = verb
end

# The above is sufficient to solve part 1, part 2 requires us to find the
# parameters to init_puzzle ("noun" and "verb", in the range 0-99) that produce
# the output 19690720
#
# The puzzle asks the question "what is 100 * noun + verb"
def search(filename="input.txt")
  mem = [0]
  results = {noun: 0, verb: 0, output: 0}

  (0..99).each do |noun|
    (0.99).each do |verb|
      mem = load_file(filename)
      init_puzzle(mem, noun, verb)
      exec_intcode(mem)
      if mem[0] == 19690720 || (noun > 99 && verb > 99)
        results = {noun: noun, verb: verb, output: mem[0]}
        return results
      end
    end
  end

  return results
end

# Do this stuff if running from the command line
# ==============================================
if ARGV.size <= 0 || ARGV[0] == nil
  puts "usage: ./day2 <input filename>"
  exit 1
end

Intcode.set_debug(ENV.has_key?("AOC_DEBUG") ? ENV["AOC_DEBUG"] == "true" : false)

puts "Part 1"
vm = Intcode::VM.from_file(ARGV[0])
init_puzzle(vm.mem)
vm.run
puts "Output: #{vm.mem[0]}"
puts "\n"

def search_vm(filename="input.txt")
  vm = nil
  results = {noun: 0, verb: 0, output: 0}

  (0..99).each do |noun|
    (0..99).each do |verb|
      vm = Intcode::VM.from_file(filename)
      init_puzzle(vm.mem, noun, verb)
      vm.run
      if vm.mem[0] == 19690720 || (noun > 99 && verb > 99)
        results = {noun: noun, verb: verb, output: vm.mem[0]}
        return results
      end
    end
  end

  return results
end

puts "Part 2"
puts "searching..."
t_start = Time.now
results = search_vm(ARGV[0])
puts "search completed in %s" % (Time.now - t_start).to_s
puts "  output: #{results[:output]}"
puts "    noun: #{results[:noun]}"
puts "    verb: #{results[:verb]}"
puts "solution: #{100 * results[:noun] + results[:verb]}"
