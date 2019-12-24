#!/usr/bin/env crystal

require "../lib/utils.cr"

input = Utils.get_input_file(Utils.cli_param_or_default(0,"day24/sample.txt"))

map = input.lines.map { |l| l.chars.to_a }
history = [] of Array(Array(Char))
history << map

steps = 0
while true
  puts "Step #{steps}:"
  print_map map
  map = step(map)
  steps += 1
  if history.any? { |m| m == map }
    break
  end
  history << map
end

puts "Cycle after #{steps} steps:"
print_map map
puts "Score: #{score(map)}"

def score(map)
  map.flat_map { |row| row }
    .map_with_index { |tile, idx| {tile, idx} }
    .reduce(0) { |sum, pair| sum + (pair[0] == '#' ? 2**pair[1] : 0) }
end

def step(map)
  new_map = map.clone
  map.each_with_index do |row, y|
    row.each_with_index do |tile, x|
      bugs = count_neighbor_bugs(map, {x,y})
      new_map[y][x] = case tile
                      when '#'
                        if bugs == 1
                          '#'
                        else
                          '.'
                        end
                      when '.'
                        if bugs == 1 || bugs == 2
                          '#'
                        else
                          '.'
                        end
                      else tile
                      end
    end
  end
  return new_map
end

def count_neighbor_bugs(map, loc)
  neighbors(loc[0], loc[1]).reduce(0) { |sum, n| sum + (get(map, n) == '#' ? 1 : 0) }
end

def neighbors(x,y)
  [{0,-1}, {1,0}, {0,1}, {-1,0}].map { |n| {x+n[0], y+n[1]} }
end

def get(map, loc : Tuple(Int32, Int32))
  get(map, loc[0], loc[1])
end

def get(map, x, y)
  if x >= 0 && y >= 0 && map.size > y && map[0].size > x
    map[y][x]
  else
    '.'
  end
end

def print_map(map)
  map.each do |row|
    row.each do |tile|
      print tile
    end
    print '\n'
  end
  print '\n'
end
