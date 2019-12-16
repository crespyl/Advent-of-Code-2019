#!/usr/bin/env crystal
require "../lib/utils.cr"

def split(str)
  str.chars.map { |c| c.to_i }
end

def fft_base_pattern(n) # return an interator
  base = [0,1,0,-1]
  base.map { |b| [b] * (n + 1) }.flatten.cycle.skip(1)
end

# take a list of digits, for each digit, compute the sum of the following digits % 10
def precompute_sums(list)
  list.map_with_index { |i,idx|
    list.skip(idx).sum % 10
  }
end

def fft_phases(list : Array(Int32), n)
  n.times do
    precomputed = precompute_sums(list[(list.size//2)..])
    list = list.map_with_index { |v, idx|
      if idx > list.size//2
        precomputed[idx-list.size//2]
      else
        list.zip(fft_base_pattern(idx)).map { |pair|
          l, p = pair
          l * p
        }.sum.abs % 10
      end
    }
  end
  list.join[0..7]
end

# p1
input = split(Utils.get_input_file("day16/input.txt"))
puts "Part 1: %i (input size %i)" % [fft_phases(input, 100), input.size]

# p2

#input = split("03036732577212944063491565474664") * 10000
input = split(Utils.get_input_file("day16/input.txt")) * 10000
offset = input[0...7].join.to_i
puts "Offset: %i" % offset

# because of how the base pattern expands, beyond the halfway point the pattern
# for every digit n will be n-1 0s followed by 1s for the rest of the list. This
# means that the transformation for a digit n (n > size/2) is simply the sum of
# the following digits.

def p2_fast_fft_offset(numbers, offset)

  100.times do |phase|
    puts "> #{phase}" if phase % 10 == 0

    # the list of sums will the same for each digit, so we can save some time by
    # precomputing
    #
    # precomputed = numbers[offset...].map_with_index { |n,i| numbers[offset+i...].sum }
    #
    # however even precomputing like this is slow, we can do it faster in
    # reverse since that allows us to easily peek at the most recently computed value
    precomputed = [numbers.last]
    numbers[offset...numbers.size-1].reverse.each do |n|
      precomputed << precomputed.last + n
    end
    precomputed.reverse!

    next_phase = numbers[0...offset] + numbers[offset...].map_with_index { |n,i| precomputed[i] % 10 }

    numbers = next_phase
  end

  numbers[offset...offset+8].join
end

puts "Part 2: %i" % p2_fast_fft_offset(input, offset)

# print pattern table
#
# 10.times do |i|
#   pattern = fft_base_pattern(i)
#   puts pattern.first(10).map { |i| "%2i" % i }.join(", ")
# end
#
# past n/2 the first half of the pattern is all 0, the second half is all 1;
# this should hold for all n; meaning that for any given digit, the value for
# the next phase will just be the sum of all the following digits
#
# 1,  0, -1,  0,  1,  0, -1,  0,  1,  0 #  1
# 0,  1,  1,  0,  0, -1, -1,  0,  0,  1 #  2
# 0,  0,  1,  1,  1,  0,  0,  0, -1, -1 #  3
# 0,  0,  0,  1,  1,  1,  1,  0,  0,  0 #  4
# 0,  0,  0,  0,  1,  1,  1,  1,  1,  0 #  5
# 0,  0,  0,  0,  0,  1,  1,  1,  1,  1 #  6  n/2
# 0,  0,  0,  0,  0,  0,  1,  1,  1,  1 #  7
# 0,  0,  0,  0,  0,  0,  0,  1,  1,  1 #  8
# 0,  0,  0,  0,  0,  0,  0,  0,  1,  1 #  9
# 0,  0,  0,  0,  0,  0,  0,  0,  0,  1 # 10
