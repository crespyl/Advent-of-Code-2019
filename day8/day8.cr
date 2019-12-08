#!/usr/bin/env crystal
require "colorize"
require "../lib/utils.cr"

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

def flatten(layers)
  layers.reverse.reduce(Array(Int32).new(WIDTH*HEIGHT,2)) do |output, layer|
    layer.each_with_index do |v, i|
      output[i] = v unless v == 2
    end
    output
  end
end

COLORS = {
  0 => :black,
  1 => :white,
  2 => :transparent
}

WIDTH = 25
HEIGHT = 6

input = Utils.get_input_file(Utils.cli_param_or_default(0, "day8/input.txt"))
layers = split_layers(input, WIDTH, HEIGHT)

# Part 1
layer_counts = find_layer_with_least(layer_counts(layers))
puts "Part 1: %i" % (layer_counts[1] * layer_counts[2])

# Part 2
print "Part 2:"
flatten(layers).map { |v| COLORS[v] }.each_with_index do |color, i|
  i % WIDTH == 0 && print '\n'
  print " ".colorize.back(color)
end
print '\n'
