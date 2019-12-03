#!/usr/bin/env ruby

# utility fn to make swapping point representation easier
def point(x,y)
  [x,y]
end

# manhattan distance between two points
def dist(a, b)
  ax, ay, _ = a
  bx, by, _ = b

  (ax-bx).abs + (ay-by).abs
end

class Wire
  attr_accessor :points
  attr_accessor :point_dists
  def initialize(points, point_dists)
    @points = points
    @point_dists = point_dists
  end
end

# We need to read a line of text, with comma separated wire vectors of the form
# "R37,D54,L39,U57" etc. Vectors are always prefixed by RLUD and may have 1 or
# more digits in the length part.
#
# This function will parse such a string into a list of (x,y) tuples for each
# point on the wire
def read_wire_points(str)
  points = []
  point_dists = {}
  x, y, len = 0, 0, 0

  str
    .split(',')
    .map { |s| m=s.match(/([LRUD])(\d+)/); point(m[1], m[2].to_i) }
    .each do |dir, dist|
    while dist > 0
      case dir
      when "L" then x -= 1
      when "R" then x += 1
      when "U" then y -= 1
      when "D" then y += 1
      end
      dist -= 1
      len += 1
      p = point(x,y)
      points << p
      point_dists[p] = len
    end
  end

  Wire.new(points, point_dists)
end

# Given to point lists, find the intersections
def intersections(list_a, list_b)
  list_a & list_b
end

# Given a list of intersection points, find the one closest to 0,0
def closest_to_center(list)
  list
    .sort_by { |point| dist(point, point(0,0)) }
    .first
end

if ARGV.size <= 0 || ARGV[0] == nil
  puts "usage: ./day3 <input filename>"
  exit 1
end

input = ARGV[0]
wires = File.readlines(input)
  .reject { |line| line.empty? }
  .map { |line| read_wire_points(line) }

i_pts = intersections(wires[0].points, wires[1].points)
result = closest_to_center(i_pts)

puts "Part 1"
puts dist(result, point(0,0))

# Part 2 requires us to sort the intersections by the shortest combined lengths
result = i_pts
  .map { |point| wires[0].point_dists[point] + wires[1].point_dists[point] }
  .sort
  .first

puts "Part 2"
puts result
