#!/usr/bin/env ruby

RANGE_MIN = 171309
RANGE_MAX = 643603

def check_digits(n)
  n.to_s.size == 6
end

def check_range(n)
  n >= RANGE_MIN && n <= RANGE_MAX
end

def check_adjacency(n)
  result = false
  n.to_s.chars.reduce('0') { |prev, char|
    if prev == char
      result = true
    end
    char
  }
  return result
end

def check_increase(n)
  result = true
  n.to_s.chars.reduce('0') { |prev, char|
    if prev.to_i > char.to_i
      result = false
    end
    char
  }
  return result
end

def check_adjacency_p2(n)
  n.to_s.chars.group_by { |c| c }.any? { |k,v| v.length == 2 }
end

def check(n)
  check_digits(n) && check_range(n) && check_increase(n) && check_adjacency(n)
end

def check_p2(n)
  check_digits(n) && check_range(n) && check_increase(n) && check_adjacency_p2(n)
end

def check_test(n)
  check_digits(n) && check_adjacency_p2(n) && check_increase(n)
end

puts "Part 1"
matches = 0
for i in RANGE_MIN..RANGE_MAX
  matches += 1 if check(i)
end
puts matches

puts "\nPart 2"
matches = 0
for i in RANGE_MIN..RANGE_MAX
  matches += 1 if check_p2(i)
end
puts matches
