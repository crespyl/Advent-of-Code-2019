#!/usr/bin/env crystal
require "colorize"
require "../lib/utils.cr"

COLORS = {0 => :black, 1 => :white, 2 => :transparent}
WIDTH  = 25
HEIGHT =  6

input = Utils.get_input_file(Utils.cli_param_or_default(0, "day8/input.txt"))
layers = input.strip.chars
  .in_groups_of(WIDTH * HEIGHT, '-')
  .map { |l| l.select(&.number?).map(&.to_i) }
  .to_a

# Part 1
layer_least = layers.min_by { |l| l.count 0 }
puts "Part 1: %i" % (layer_least.count(1) * layer_least.count(2))

# Part 2
def flatten(layers)
  layers.reverse.reduce(Array(Int32).new(WIDTH*HEIGHT, 2)) do |output, layer|
    layer.each_with_index do |v, i|
      output[i] = v unless v == 2
    end
    output
  end
end

print "Part 2:"
flatten(layers)
  .map { |v| COLORS[v] }
  .each_with_index do |color, i|
    i % WIDTH == 0 && print '\n'
    print " ".colorize.back(color)
  end
print '\n'

filename = Utils.cli_param_or_default(1, "day8/output.ppm")
Utils.write_ppm(WIDTH, HEIGHT, flatten(layers).map { |v|
  case v
  when 0 then {0, 0, 0}
  when 1 then {255, 255, 255}
  else        {255, 0, 0}
  end
}, filename)
