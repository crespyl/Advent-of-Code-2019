#!/usr/bin/env ruby
require "set"

Point = Struct.new(:x, :y)
def dist(a, b)
  (a.x - b.x).abs + (a.y - b.y).abs
end

# part 1
input = File.read("day10/input.txt").strip
map = input.lines.map { |l| l.chars.select{ |c| c == '.' || c == '#'}.to_a }.reject(&:empty?)

# find all the asteroids
rocks = {}
for y in (0..map.size-1)
  for x in (0..map[y].size-1)
    # for each asteroid, make a set to hold the angles to the other rocks note
    #  that asteroids are essentially sizeless, and only block if the angle is
    #  *exactly* the same
    set = {}
    set.default = [] # we use a hashmap instead of Set here so that we can map
                     # angles to the number of rocks at that angle
    rocks[Point.new(x,y)] = set if map[y][x] == '#'
  end
end

# for each rock, for each other rock
for a,_ in rocks
  for b,_ in rocks
    if a != b
      # add the angle from rock a to rock b to our set
      theta = Math.atan2(a.y - b.y, a.x - b.x)
      rocks[a][theta] = rocks[theta]? rocks[theta] << b : [b]
    end
  end
end

best = rocks.max_by { |p, s| s.size } # count how many unique rock-angles there are
puts "Part 1"
puts best[0], best[1].size

# part 2
# we need to find the order of laser hits
base = best[0] # grab the laser base station from p1
to_hit = best[1] # map of angles to hit and matching rocks
#puts best[1]

angles = to_hit.keys
# ensure we have our start angle of pi/2
angles << Math::PI/2 if ! angles.member? Math::PI/2
angles = angles.sort

start = angles.index(Math::PI/2)
count = 1

for theta in angles.rotate(start)
  to_hit[theta] = to_hit[theta].sort_by { |p| dist(base, p) }
  #puts "%5f => %i" % [theta, to_hit[theta].size]
  puts "    hit %i = %s" % [count, to_hit[theta].first] if count == 200
  to_hit[theta] = to_hit[theta].drop(1)
  count += 1
end

#puts "#{to_hit.keys.sort}"
