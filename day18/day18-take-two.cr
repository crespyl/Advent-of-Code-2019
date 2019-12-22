#!/usr/bin/env crystal

require "../lib/utils.cr"
include Utils

input = Utils.get_input_file(Utils.cli_param_or_default(0,"day18/sample2.txt"))

map = Map.new(input.lines.map { |l| l.chars.to_a })

puts "Map loaded"
puts "Found start: #{map.start.to_s}"
puts "Found keys: #{map.keys.join}"
puts "Key Requirements: #{map.key_reqs}"
puts "Available Keys: #{map.available_keys(Set(Tile){'a'})}"

start_state = State.new(map.start, '@', Set(Tile).new)
paths = dijkstra(map, start_state) || raise "No solution found"

path, steps = paths.first
puts "Dijkstra ended, result: #{format_path(path)}, #{steps}"

def format_path(path : Array(State))
  {path.map { |s| s.tile }.join}
end

def dijkstra(map : Map, start : State)
  solutions = [] of Array(State)
  best_solution = Int32::MAX

  open = PQueue(State).new
  open.insert(start, 0)

  dist = Hash(State, Int32).new(Int32::MAX)
  prev = Hash(State, State).new

  dist[start] = 0

  while !open.empty?
    state = open.pop_min

    available_moves(map, state).each do |move|
      #puts "Check available move: #{move}"
      alt = dist[state] + (map.path_distance(state.loc, move.loc))
      next if alt > best_solution

      if alt < dist[move]
        dist[move] = alt
        prev[move] = state
        open.insert_or_update(move, alt)
      end
    end

    if state.inventory == map.keys
      best_solution = dist[state] if dist[state] < best_solution

      path = [state]
      while (state = prev[state]?)
        path << state
      end
      solutions << path.reverse
      puts "Found possible solution (#{dist[path.first]}) #{format_path(solutions.last)}"
    end
  end

  return solutions.sort_by { |path| dist[path.last] }.map { |path| {path, dist[path.last]} }
end

def available_moves(map : Map, state : State)
  # each available key is a move we can take
  moves = map.available_keys(state.inventory).map { |k,loc|
    State.new(loc,
              k,
              state.inventory + Set{k})
  }

  # moves = moves.map { |new_state|
  #   keys_on_path = bfs_path(state.loc, new_state.loc)
  # }
  # any move that involves walking over a key should pick up that key
end

struct State
  property inventory : Set(Tile)
  property loc : Vec2
  property tile : Tile
  def initialize(@loc, @tile, @inventory) end
end

alias Tile = Char

DIRS = [Vec2.new(0,-1), Vec2.new(1,0), Vec2.new(0,1), Vec2.new(-1,0)]

class Map
  property tiles : Array(Array(Tile))
  property keys : Set(Tile)
  property key_reqs : Hash(Tile, Set(Tile))
  property start : Vec2

  def initialize(tiles)
    @tiles = tiles
    @keys = tiles
            .flat_map{ |row| row }
            .select{ |t| t.ascii_lowercase? }
            .to_set
    @key_reqs = Hash(Tile, Set(Tile)).new

    @start = find_loc('@') || raise "Could not find start position"

    precalculate_key_reqs
  end

  # Given the precalculated key requirements table, we can determine the set of
  # available keys from any set of currently held keys
  #
  # Returns a list of {Key, Loc} tuples
  def available_keys(held : Set(Tile)) : Array(Tuple(Tile, Vec2))
    key_reqs
      .reject { |k,_| held.includes? k }
      .map { |k,reqs| {k, reqs.all?{|r| held.includes?(r)}}  }
      .select { |pair| pair[1] }
      .map { |pair| {pair[0], find_loc(pair[0]) || Vec2.new(-1,-1)} }
  end

  # We know from the input that there is only ever one route from start to a
  # given key
  def precalculate_key_reqs
    @keys.each do |key|
      key_loc = find_loc(key) || raise "Key #{key} went missing"
      path = bfs_path(key_loc, @start)
      @key_reqs[key] = path
                       .map { |loc| get_tile(loc) }
                       .select { |c| c.ascii_uppercase? }
                       .map { |c| c.downcase }
                       .to_set
    end
  end

  # Search the map for the first location with the given target
  def find_loc(tgt : Tile) : Vec2 | Nil
    @tiles.each_with_index do |row, y|
      row.each_with_index do |tile, x|
        return Vec2.new(x,y) if tile == tgt
      end
    end
  end

  # Returns the distance of the path from start to goal, assuming no locked
  # doors
  PATH_DIST = Hash(Tuple(Vec2, Vec2), Int32).new
  def path_distance(start : Vec2, goal : Vec2) : Int32
    PATH_DIST[{start, goal}] ||= begin
                                   # -1 to # account for the path including the start # square
                                   bfs_path(start, goal).size - 1
                                 end
  end

  # Simple BFS search from start to goal, ignores doors/keys etc
  PATHS = Hash(Tuple(Vec2, Vec2), Array(Vec2)).new
  def bfs_path(start : Vec2, goal : Vec2) : Array(Vec2)
    PATHS[{start, goal}] ||= begin
                               open = [{start, [] of Vec2}]
                               visited = Set(Vec2).new

                               while !open.empty?
                                 loc, route = open.pop
                                 next if visited.includes? loc

                                 new_route = route.clone << loc
                                 if loc == goal
                                   return new_route
                                 end

                                 visited.add loc

                                 neighbors(loc).each do |n|
                                   next if get_tile(n) == '#'
                                   open << {n, new_route}
                                 end
                               end

                               return [] of Vec2
                             end
  end

  def neighbors(loc : Vec2)
    DIRS.map { |d| loc + d }
  end

  def get_tile(loc : Vec2)
    if @tiles.size > loc.y && @tiles[loc.y].size > loc.x
      @tiles[loc.y][loc.x]
    else
      '#'
    end
  end

end
