#!/usr/bin/env ruby
require "colorize"

#Intcode.set_debug(ENV.has_key?("AOC_DEBUG") ? ENV["AOC_DEBUG"] == "true" : false)
INPUT = ARGV.size > 0 ? ARGV[0] : "day8/input.txt"

# WIDTH  = 3
# HEIGHT = 2
# data = "123456789012"

WIDTH = 25
HEIGHT = 6
data = File.read(INPUT).strip

COLORS = {
  0 => :black,
  1 => :white,
  2 => :transparent
}

def split_layers(data, width, height)
  layers = []

  data.chars.each_slice(width * height) do |layer|
    layers << layer
             .reject {|c| c == nil}
             .map { |c| c.to_i }
  end

  return layers
end

def count_elem(data, target)
  data.reduce(0) { |count, item| count + (item == target ? 1 : 0) }
end

def layer_counts(layers)
  counts = {}

  layers.each_with_index do |layer, i|
    counts[i] = {}
    counts[i][0] = count_elem(layer, 0)
    counts[i][1] = count_elem(layer, 1)
    counts[i][2] = count_elem(layer, 2)
  end

  counts
end

def find_least_zeros(layer_counts)
  least_zs = 99999999
  least_i = 0

  layer_counts.each do |i, counts|
    if counts[0] < least_zs
      least_zs = counts[0]
      least_i = i
    end
  end

  return least_i
end

# Part 1
layers = split_layers(data, WIDTH, HEIGHT)
# puts "got #{layers.size} layers"
# puts layers[0]

counts = layer_counts(layers)

least_zs_i = find_least_zeros(counts)
# puts "layer #{least_zs_i}"

# puts layers[least_zs_i]

puts counts[least_zs_i][1] * counts[least_zs_i][2]

# Part 2
def flatten(layers)
  output = []
  layers.reverse.each do |layer|
    layer.each_with_index do |value, i|
      case value
      when 0 then output[i] = 0
      when 1 then output[i] = 1
      when 2 then output[i] = output[i] # transparent/noop
      end
    end
  end
  return output
end

flattened = flatten(layers)

flattened.each_with_index do |val, i|
  if i % WIDTH == 0
    print "\n"
  end

  color = COLORS[val]

  print " ".colorize(:background => color)
end
