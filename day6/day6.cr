#!/usr/bin/env crystal

class Node
  property name : String
  property parent : Node | Nil

  def initialize(name, parent)
    @parent = parent
    @name = name
  end

  def is_root?
    parent == nil
  end

  def to_s
    name
  end

  # get depth to root
  def get_depth
    get_ancestors.size
  end

  def get_ancestors
    if is_root?
      [] of Node
    else
      parents = [] of Node

      p = parent
      while p != nil
        parents << p if p
        p = p.parent if p
      end

      parents
    end
  end
end

def find_or_make_node(map, name)
  if !map.has_key? name
    map[name] = Node.new(name, nil)
  end
  map[name]
end

def find_common_parent(map, node1, node2)
  node1_ps = node1.get_ancestors
  node2_ps = node2.get_ancestors

  common = node1_ps & node2_ps
  common.sort_by { |n| n.get_depth }

  common.first
end

# Build our map

nodes = {} of String => Node
nodes["COM"] = Node.new("COM", nil)

input = ARGV.size > 0 ? ARGV[0] : "day6/input.txt"
File.read_lines(input).each do |line|
  n1, n2 = line.split(")").map { |n| n.strip }
  node1 = find_or_make_node(nodes, n1)
  node2 = find_or_make_node(nodes, n2)
  node2.parent = node1
end

# Part 1, find and sum the depth of each node
puts "Part 1"
puts nodes.values.reduce(0) { |sum, node| sum + node.get_depth }

# Part 2, find the distance between YOU and SAN
puts "Part 2"
common = find_common_parent(nodes, nodes["YOU"], nodes["SAN"])
path_dist = (nodes["YOU"].get_depth - common.get_depth) + (nodes["SAN"].get_depth - common.get_depth)
puts path_dist - 2 # subtract two since we're counting *transfers*, we don't
# "transfer" from our start/end nodes
