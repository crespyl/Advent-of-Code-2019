#!/usr/bin/env crystal

require "../lib/vm2.cr"
require "../lib/utils.cr"

prog = Utils.get_input_file(Utils.cli_param_or_default(0,"day17/input.txt"))

vm = VM2.from_string(prog)
vm.run

map = vm.output.map(&.chr).join.split('\n').map { |l| l.chars.to_a }
def safe_get_xy(map,x,y)
  if map.size > y && y >= 0
    if map[y].size > x && x >= 0
      return map[y][x]
    end
  end
  return '.'
end

# find intersections
intersections = Hash(Tuple(Int32,Int32), Bool).new(false)
map.each_with_index do |row,y|
  row.each_with_index do |tile,x|
    # check each direction to see if all 4 are #s
    up = safe_get_xy(map, x, y-1)
    down = safe_get_xy(map, x, y+1)
    left = safe_get_xy(map, x-1, y)
    right = safe_get_xy(map, x+1, y)

    if [tile, up,down,left,right].all?('#')
      intersections[{x,y}] = true
    end

  end
end

puts "Part 1: %i" % intersections.keys.map { |i| i[0] * i[1] }.sum

# P2 by manual examination
script = "\
A,B,A,C,B,A,C,B,A,C
L,12,L,12,L,6,L,6
R,8,R,4,L,12
L,12,L,6,R,12,R,8
n
".chars.map(&.ord.to_i64)

vm = VM2.from_string(prog)
vm.mem[0] = 2
vm.input = script
vm.run
puts "Part 2: %i" % vm.output.last
