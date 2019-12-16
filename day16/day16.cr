#!/usr/bin/env crystal
require "../lib/utils.cr"

def split(n : Int32)
  n.to_s.chars.map { |c| c.to_i }
end

def split(str)
  str.chars.map { |c| c.to_i }
end

def fft_base_pattern(n)
  base = [0,1,0,-1]
  base = base.map { |b| [b] * (n + 1) }.flatten.cycle.skip(1)
  base
end

def p1_fft_phases(list : Array(Int32), n)
  n.times do
    list = list.map_with_index { |v, idx|
      pattern = fft_base_pattern(idx)
      z = list.zip(pattern).map { |pair|
        l, p = pair
        l * p
      }.sum.abs % 10
    }
  end
  list.join[0..7]
end

puts "Part 1: %i" % p1_fft_phases(split(Utils.get_input_file("day16/input.txt")), 100)
