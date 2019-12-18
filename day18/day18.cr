#!/usr/bin/env crystal

require "../lib/utils.cr"
include Utils

input = Utils.get_input_file(Utils.cli_param_or_default(0,"day18/input.txt"))

map = Map.new(input.lines.map { |l| l.chars.to_a })

# up, right, down, left
DIRS = [Vec2.new(0,-1), Vec2.new(1,0), Vec2.new(0,1), Vec2.new(-1,0)]

puts input

puts "Start: %s" % map.find('@').to_s

start = map.find('@')
hero = Hero.new(map, start)

hero.select_long_term_goal

while !hero.satisfied?
  goal = hero.select_next_goal
  puts "goal: #{goal}"
  puts "go there"
  hero.walk_to(goal)
  puts "arrived, total steps: #{hero.pedometer}"
end

puts "Sequence: #{hero.history}"

puts "Part 1: %s" % hero.pedometer
puts "Part 2: %s" % 0

alias Tile = Char

# return the list of doors on that path
def find_reqs_for_pos(map : Map, start : Vec2, goal : Vec2)
  find_path(map, start, goal).map { |loc| map.get(loc) }.reject { |tile| !tile.ascii_uppercase? }
end

def find_path(map : Map, start : Vec2, goal : Vec2) : Array(Vec2)
  open = [{start, [] of Vec2, 0}]
  visited = Set(Vec2).new

  while !open.empty?
    loc, route, len = open.pop
    next if visited.includes? loc

    new_route = route + [loc]
    if loc == goal
      return new_route
    end

    visited.add(loc)

    neighbors(loc).each do |n|
      next if map.get(n) == '#'
      open << {n, new_route, len+1}
    end
  end

  return [] of Vec2
end

class Map
  property tiles : Array(Array(Tile))
  property keys : Array(Tuple(Vec2, Tile))

  def initialize(tiles)
    @tiles = tiles
    @keys = [] of Tuple(Vec2, Tile)
    self.each_tile do |x,y,tile|
      if tile.ascii_lowercase?
        keys << {Vec2.new(x,y), tile}
      end
    end
  end

  def each_tile(&block)
    @tiles.each_with_index do |row, y|
      row.each_with_index do |tile, x|
        yield(x,y,tile)
      end
    end
  end

  def path_dist(src : Vec2, dst : Vec2)
    find_path(self, src, dst).size-1 # -1 since path from A=>A returns [A]
  end

  def find(tgt : Tile) : Vec2
    @tiles.each_with_index do |row, y|
      row.each_with_index do |tile, x|
        if tile == tgt
          return Vec2.new(x,y)
        end
      end
    end
    return Vec2.new(-1,-1)
  end

  def get(loc : Vec2) : Tile
    get(loc[0], loc[1])
  end

  def get(x, y) : Tile
    if @tiles.size > y && y >= 0
      if @tiles[y].size > x && x >= 0
        return @tiles[y][x]
      end
    end
    return '#'
  end
end

struct Hero
  property map : Map
  property loc : Vec2
  property inv : Set(Tile)
  property pedometer : Int32
  property long_term_goal : Tile
  property history : Array(Tile)

  def initialize(map : Map, loc : Vec2)
    @map = map
    @loc = loc
    @inv = Set(Tile).new
    @pedometer = 0
    @long_term_goal = '-'
    @history = [] of Tile
  end

  def satisfied?
    want = [] of Tile

    map.keys.each do |k|
      if ! @inv.includes? k[1]
        want << k[1]
      end
    end

    puts "I WANT: #{want}"

    return want.empty?
  end

  def walk_to(dest : Tile)
    walk_to(map.find(dest))
  end

  def walk_to(dest : Vec2)
    return unless dest != @loc

    path = find_path(@map, @loc, dest)

    # skip the first step since that's where we are now
    path.skip(1).each do |step|
      tile = @map.get(step)
      raise "TRIED TO DO THE IMPASSIBLE: #{tile} : #{step}" unless can_pass? tile

      @pedometer += 1
      @loc = step

      puts "   ...walked to #{step}"

      if tile.ascii_lowercase?
        take_key(tile)
      end
    end
  end

  def take_key(key : Tile)
    return if @inv.includes? key
    puts "got key #{key}"
    @history << key
    @inv.add key
  end

  def select_next_goal
    reqs = find_reqs_for_keys

    if reqs[@long_term_goal]? == nil || @inv.includes? @long_term_goal
      select_long_term_goal
    end

    # find the next available pre-requisite for that key
    pre_reqs = reqs[@long_term_goal]
    next_goal = pre_reqs.empty? ? @long_term_goal : pre_reqs.sort_by { |k| value_key(k.downcase) }.last.downcase
    while !reqs[next_goal].empty?
      next_goal = reqs[next_goal].first.downcase
    end

    puts "selected next goal: #{next_goal}"

    return next_goal
  end

  # find the hardest key to go after
  #
  # we want the hardest key to be the last one we pick up, and therefore its
  # requirements should define the order of the other keys
  def select_long_term_goal
    reqs = find_reqs_for_keys

    # find the best key
    best = reqs.keys.sort_by { |k| {reqs[k].size, -@map.path_dist(@loc,@map.find(k))} }.last

    puts "selected long term goal: #{best}"
    @long_term_goal = best
  end

  # determine the value of a given key based on how many other keys it's a
  # requirement for
  def value_key(key : Tile)
    reqs = find_reqs_for_keys

    reqs.reduce(0) { |sum,kv| sum + (kv[1].includes?(key) ? 1 : 0) }
  end

  # find the requirements for all the keys in the @map (that we don't already
  # have), and excluding requirements (keys) we already have
  def find_reqs_for_keys
    reqs = {} of Tile => Array(Tile)
    @map.keys.each do |k|
      key_loc, key = k
      doors = find_reqs_for_pos(@map, key_loc, @loc).reject { |door| can_pass?(door) }
      reqs[key] = doors
    end
    reqs.reject { |k,v| @inv.includes? k }
  end

  def can_pass?(tile : Tile)
    case tile
    when '.' then true
    when '@' then true
    else
      if tile.ascii_lowercase?
        true
      elsif tile.ascii_uppercase?
        @inv.includes? tile.downcase
      else
        false
      end
    end
  end
end

def neighbors(loc : Vec2)
  DIRS.map { |d| loc + d }
end

# 7206 too high
