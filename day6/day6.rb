#!/usr/bin/env ruby

class Node
  attr_accessor :name
  attr_accessor :parent

  def initialize(name, parent)
    @parent = parent
    @name = name
  end

  def is_root?
    parent == nil
  end

  def to_s
    if self.is_root?
      "COM"
    else
      "%s)%s" % [parent.name, name]
    end
  end

  # get depth to root
  def get_depth
    if self.is_root?
      return 0
    else
      return 1 + parent.get_depth
    end
  end

  def get_parents
    if is_root?
      []
    else
      parents = []

      p = parent
      while p != nil
        parents << p
        p = p.parent
      end

      parents
    end
  end
end

def find_or_make_node(map, name)
  if ! map.has_key? name
    map[name] = Node.new(name, nil)
  end
  map[name]
end

def count_orbits(map)
  nodes.values.reduce(0) { |sum,node| sum + node.get_depth }
end

def find_common_parent(map, node1, node2)
  node1_ps = node1.get_parents
  node2_ps = node2.get_parents

  common = node1_ps & node2_ps
  common.sort_by { |n| n.get_depth }

  common.first
end

nodes = {}
nodes["COM"] = Node.new("COM", nil)

input = ARGV.size > 0 ? ARGV[0] : "day5/sample.txt"

File.readlines(input).each do |line|
  n1, n2 = line.split(")").map{ |n| n.strip }
  node1 = find_or_make_node(nodes, n1)
  node2 = find_or_make_node(nodes, n2)
  node2.parent = node1
end

common = find_common_parent(nodes, nodes["YOU"], nodes["SAN"])
path_dist = (nodes["YOU"].get_depth - common.get_depth) + (nodes["SAN"].get_depth - common.get_depth)
puts path_dist-2

puts "!"
