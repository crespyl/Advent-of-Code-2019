#!/usr/bin/env crystal

# expect input file as first parameter
input = ARGV[0]

# Per Day 1, we get the amount of fuel for a given mass:
#   divide by 3, round down, then subtract 2
def fuel_for_mass(mass)
  fuel = (mass.to_f / 3.0) - 2.0
  return fuel.to_i
end

# Read each line from input and sum the fuel costs
puts "Part 1"
puts File.read_lines(input)
  .reject{ |line| line.empty? }
  .reduce(0) { |sum, line| sum + fuel_for_mass(line.to_f) }

# Part 2 requires us to do this fuel calculation recursively
def fuel_for_mass_recursive(mass)
  fuel = fuel_for_mass(mass)
  extra = fuel_for_mass(fuel)
  while extra > 0
    fuel += extra
    extra = fuel_for_mass(extra)
  end
  return fuel
end

puts "\nPart 2"
puts File.read_lines(input)
  .reject { |line| line.empty? }
  .reduce(0) { |sum, line| sum + fuel_for_mass_recursive(line.to_f) }
