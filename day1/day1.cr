#!/usr/bin/env crystal

require "big"

if ARGV.size <= 0 || ARGV[0] == nil
  puts "usage: ./day1 <input filename>"
  exit 1
end

# expect input file as first parameter
input = ARGV[0]

# Per Day 1, we get the amount of fuel for a given mass:
#   divide by 3, round down, then subtract 2
def fuel_for_mass(mass) : BigInt
  fuel = (mass // 3) - 2
  return BigInt.new(fuel)
end

# Read each line from input and sum the fuel costs
puts "Part 1"
puts File.read_lines(input)
  .reject{ |line| line.empty? }
  .reduce(BigInt.new(0)) { |sum, line| sum + fuel_for_mass(line.to_f) }

# Part 2 requires us to do this fuel calculation recursively
def fuel_for_mass_recursive(mass) : BigInt
  fuel = fuel_for_mass(mass)
  extra = fuel_for_mass(fuel)
  while extra > 0
    fuel += extra
    extra = fuel_for_mass(extra)
  end
  return fuel
end

puts "\nPart 2"
t_start = Time.local
puts File.read_lines(input)
  .reject { |line| line.empty? }
  .reduce(0) { |sum, line| sum + fuel_for_mass_recursive(line.to_f) }
puts "  completed in %s" % (Time.local - t_start).to_s


puts "\nPart 2 - fibers"
t_start = Time.local

jobs = 0

results = Channel(BigInt).new(100)
queue = Channel(String | Nil).new(100)

# spawn workers
8.times do
  spawn {
    puts "\nworker entering\n"
    loop do
      val = queue.receive
      if val.nil?
        puts "\nworker exiting\n"
        break
      else
        results.send(fuel_for_mass_recursive(BigInt.new(val)))
      end
    end
  }
end
puts "  done spawning workers"

File.read_lines(input)
  .reject { |line| line.empty? }
  .in_groups_of(1000) { |group|
    to_send = group.reject { |l| l.nil? }
    jobs += to_send.size
    spawn do
      to_send.each { |l| queue.send(l) }
    end
  }

puts "  done enqueuing lines"

sum = BigInt.new(0)
jobs.times do
  sum += results.receive
end

puts sum
puts "  completed in %s" % (Time.local - t_start).to_s
