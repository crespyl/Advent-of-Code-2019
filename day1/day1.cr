#!/usr/bin/env crystal

require "big"

if ARGV.size <= 0 || ARGV[0] == nil
  puts "usage: ./day1 <input filename>"
  exit 1
end

# expect input file as first parameter
input = ARGV[0]

# Read each line from input and sum the fuel costs
puts "Part 1"
puts File.read(input)
  .chomp
  .split('\n')
  .map { |l| l.to_i }
  .reduce(0) { |s, m| s + m // 3 - 2 }

# Part 2 requires us to do this fuel calculation recursively
def fuel_for_mass_recursive(mass)
  fuel = mass // 3 - 2
  extra = fuel // 3 - 2
  while extra > 0
    fuel += extra
    extra = extra // 3 - 2
  end
  return fuel
end

puts "\nPart 2"
t_start = Time.local
puts File.read_lines(input)
  .reject { |line| line.empty? }
  .reduce(0) { |sum, line| sum + fuel_for_mass_recursive(line.to_i) }
puts "  completed in %s" % (Time.local - t_start).to_s
