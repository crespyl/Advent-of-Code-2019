#!/usr/bin/env crystal
require "colorize"

INPUT = ARGV.size > 0 ? ARGV[0] : "day8/input.txt"
data = File.read(INPUT).strip

WIDTH = 25
HEIGHT = 6

COLORS = {
  0 => :black,
  1 => :white,
  2 => :transparent
}

def split_layers(data, width, height)
  data
    .chars
    .in_groups_of(width * height, '-')
    .reduce([] of Array(Int32)) do |layers, layer|
    layers << layer
             .reject { |c| ! c.number? }
             .map { |c| c.to_i }
  end
end

def layer_counts(layers)
  layers.reduce(Array(Hash(Int32,Int32)).new) do |layer_counts, layer|
    layer_counts << (0..2).each_with_object({} of Int32 => Int32) { |i,h| h[i] = layer.count(i) }
  end
end

def find_layer_with_least(layer_counts, val=0)
  layer_counts.reduce(layer_counts[0]) { |best, cur|
    cur[val] < best[val] ? cur : best
  }
end

# Part 1
layers = split_layers(data, WIDTH, HEIGHT)
counts = layer_counts(layers)

least_zs = find_layer_with_least(counts, 0)
puts "Part 1: %i" % (least_zs[1] * least_zs[2])

# Part 2
def flatten(layers)
  layers.reverse.reduce(Array(Int32).new(WIDTH*HEIGHT,2)) do |output, layer|
    layer.each_with_index do |v, i|
      output[i] = v unless v == 2
    end
    output
  end
end

print "Part 2:"
flattened = flatten(layers)
flattened.each_with_index do |val, i|
  if i % WIDTH == 0
    print '\n'
  end

  color = COLORS[val]

  print " ".colorize.back(color)
end
print '\n'
