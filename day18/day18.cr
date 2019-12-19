#!/usr/bin/env crystal

require "../lib/utils.cr"
include Utils

input = Utils.get_input_file(Utils.cli_param_or_default(0,"day18/input.txt"))

map = Map.new(input.lines.map { |l| l.chars.to_a })

# up, right, down, left
DIRS = [Vec2.new(0,-1), Vec2.new(1,0), Vec2.new(0,1), Vec2.new(-1,0)]

# #puts input
map.print_map

start = map.find('@')
#puts "Start: %s" % start.to_s

#start_state = {Set{'a', 'b'}, start, 0, ['a', 'b']}
start_state = {Set(Tile).new, start, 0, [] of Tile}
#puts "Available Moves: #{available_moves(map, start_state)}"

# 2000 < x > 6116
paths = dijkstra_moves(map, start_state)
# puts "Possible Paths: "
# paths.each do |p|
#   puts p
# end

# sort by distance covered
paths = paths.to_a.sort_by { |p| p[2] }

if paths.size > 0
  puts "solution: #{fmt_step(paths[0])}"
  puts "Part 1: %s" % paths[0][2]
else
  puts "no solution found!" unless paths.size > 0
end

if ARGV.includes? "p2"
  # input replace to separate map into sub-grids
  input2 = input.lines.map { |l| l.chars.to_a }
  input2[40][40] = '#'
  input2[40][39] = '#'
  input2[40][41] = '#'
  input2[39][40] = '#'
  input2[41][40] = '#'
  input2[39][39] = '@'
  input2[39][41] = '@'
  input2[41][39] = '@'
  input2[41][41] = '@'

  map1 = input2[..40].map { |row| row[..40] }
  map2 = input2[..40].map { |row| row[40..] }
  map3 = input2[40..].map { |row| row[0..40] }
  map4 = input2[40..].map { |row| row[40..] }

  # cheeky hack solution to solve each quadrant indepantly, just ignore the walls
  # we can't pass
  p2 = [map1, map2, map3, map4].reduce(0) { |sum, m|
    m.each do |row|
      row.each_with_index do |tile, idx|
        if tile.ascii_uppercase?
          row[idx] = '.'
        end
      end
    end
    sub_map = Map.new(m)

    start = sub_map.find('@')
    start_state = {Set(Tile).new, start, 0, [] of Tile}
    paths = dijkstra_moves(sub_map, start_state).to_a.sort_by { |p| p[2] }

    sum + paths[0][2]
  }

  puts "Part 2: %s" % p2
end

alias Tile = Char

# owned keys, current location, pedometer
alias State = Tuple(Set(Tile), Vec2, Int32, Array(Tile))

def fmt_step(s : State)
  "<take %s : %5i : %s>" % [s[3].last, s[2], s[3].join]
end

def dijkstra_moves(map, start : State, limit=6347)
  KEYS_MEMO.clear
  KEYPATH_MEMO.clear
  PATH_MEMO.clear
 
  iterations = 0
  open = PQueue(State).new
  open.insert(start, 0)
  dist = Hash(Tuple(Set(Tile), Vec2), Int32).new(Int32::MAX)
  prev = Hash(Set(Tile), Set(Tile)).new
  solutions = Set(State).new

  dist[{start[3].to_set, start[1]}] = 0

  while ! open.empty?
    iterations+=1
    state = open.pop_min
    next if state[2] > limit

    #puts "%10i (%3i, %3i, %3i) : checking %s" % [iterations, open.size, dist.size, prev.size, fmt_step(state)] if iterations % 100000 == 0

    if state[0] == map.all_keys && state[2] < limit
      #puts "Found possible solution: %s" % fmt_step(state)
      limit = state[2] if state[2] < limit
      solutions.add state
    end

    available_moves(map, state).each do |move|
      #alt = dist[state] + (move[2] - state[2])
      sset = {state[3].to_set, state[1]}
      mset = {move[3].to_set, move[1]}
      alt = dist[sset] + estimate_max_state_dist(map, state, move)
      if alt < dist[mset]
        dist[mset] = alt
        prev[mset[0]] = sset[0]
        open.insert_or_update(move, alt)
      end
    end
  end

  puts "dijkstra_moves exited after #{iterations} iterations with #{solutions.size} solutions"

  return solutions

end

class PQueue(T)
  def initialize()
    @queue = Array(Tuple(T,Int32)).new
  end

  def size
    @queue.size
  end

  def empty?
    @queue.empty?
  end

  def insert(val : T, p : Int32)
    @queue.push({val, p})
    idx = 0
    while idx < @queue.size
      if (pair = @queue[idx]) && pair[1] > p
        break
      end
      idx += 1
    end
    @queue.insert(idx, {val, p})
  end

  def insert_or_update(val : T, p : Int32)
    if idx = @queue.index { |pair| pair[0] == val }
      @queue.update(idx) { {val, p} }
    else
      @queue.push({val, p})
    end
  end

  def pop_min
    @queue.pop()[0]
  end

  def pop_max
    @queue.shift()[0]
  end
end

#DIST_MEMO = Hash(Tuple(Set(Tile), Set(Tile)), Int32).new
def estimate_max_state_dist(map, a : State, b : State) : Int32
  #DIST_MEMO[{a[0],b[0]}]? || begin
                              d = if a[0].superset? b[0]
                                    0
                                  else
                                    b[2] - a[2]
                                  end
                               #DIST_MEMO[{a[0],b[0]}] = d
                               d
                             #end
end

def dfs_moves(map, start : State, limit=6116)
  iterations = 0
  end_states = Set(State).new

  open = [start]
  visited = Set(State).new

  while !open.empty?
    iterations += 1
    state = open.pop
    puts "iter: #{iterations}: open states: #{open.size}\n current state: #{fmt_step(state)}" if iterations % 100000 == 0

    next if visited.includes? state || state[2] > limit
    #puts "check state: %s" % fmt_step(state)

    if state[0].superset? map.all_keys
      end_states.add state
      limit = state[2] if state[2] < limit
      puts "found possible end: #{state}"
    end

    visited.add(state)
    #puts "check: #{fmt_step(state)}"

    # get available moves and sort by closest key first
    moves = available_moves(map, state).to_a.sort_by { |move|
      _, n_loc, _, n_hist = move
      {-map.key_difficulty(n_hist.last), map.get_distance_for(n_hist.last, state[1])}
    }.reverse

    moves.each do |n|
      next if n[2] > limit
      next if visited.includes? n || n[2] > limit
      #puts "   found possible move:  #{fmt_step(n)}"
      open << n
    end
  end

  return end_states
end


def bfs_moves(map, start : State, limit=6116, frontier_cap=10000000)
  end_states = Set(State).new
  shortest_win = limit
  iterations = 0

  open = Set{start}
  visited = Set(State).new

  while !open.empty?
    iterations += 1
    puts "iter: #{iterations}: open states: #{open.size}" if true || iterations % 100 == 0
    frontier = Set(State).new

    open.each do |state|
      next if state[2] > shortest_win
      next if visited.includes? state
      #puts "check state: %s" % fmt_step(state)

      if state[0].superset? map.all_keys
        end_states.add state
        if state[2] < shortest_win
          shortest_win = state[2]
        end
        puts "found possible end: #{state}"
      end

      visited.add(state)

      available_moves(map, state).each do |n|
        next if n[2] > shortest_win
        #next if n[2] >= limit
        next if visited.includes? n
        next if frontier.size > frontier_cap
        #puts "found possible move: #{fmt_step(n)}"
        frontier.add(n)
      end
    end

    open = frontier
  end

  return end_states
end

# MOVES_MEMO = Hash(State, Set(State)).new
def available_moves(map, state : State) : Set(State)
  # MOVES_MEMO[state]? || begin
                          owned, loc, steps, seq = state
                          keys = available_keys(map, owned)

                          states = keys.map { |k|
                            {owned + Set{k}, map.key_loc(k), steps + map.get_distance_for(k, loc), seq.clone << k}
                          }.to_set

                          moves = states.map { |state|
                            _, new_loc, new_dist, new_seq = state

                            on_the_way = keys_on_path(map, loc, new_loc).reject { |k| owned.includes? k }

                            if on_the_way.size > 1
                              # replace this with a new state that includes the pickup
                              {owned + on_the_way.to_set, new_loc, new_dist, seq.clone.concat on_the_way}
                            else
                              state
                            end
                          }

                          moves = moves.to_set

                          # MOVES_MEMO[state] = moves
                          # MOVES_MEMO[state]
                        #end
end

KEYS_MEMO = Hash(Set(Tile), Set(Tile)).new
def available_keys(map, owned_keys : Set(Tile))
  KEYS_MEMO[owned_keys]? || begin
                              available = Set(Tile).new
                              map.keys.each do |k,reqs|
                                available.add(k) if reqs.all? { |r| owned_keys.includes? r }
                              end
                              keys = available.reject { |k| owned_keys.includes? k }.to_set
                              KEYS_MEMO[owned_keys] = keys
                            end
end

KEYPATH_MEMO = Hash(Tuple(Vec2,Vec2), Set(Tile)).new
def keys_on_path(map, start : Vec2, goal : Vec2)
  KEYPATH_MEMO[{start,goal}]? || begin
                                   KEYPATH_MEMO[{start,goal}] = find_path(map, start, goal)
                                                                .map { |l| map.get(l) }
                                                                .select(&.ascii_lowercase?)
                                                                .to_set
                                 end
end

PATH_MEMO = Hash(Tuple(Vec2,Vec2), Array(Vec2)).new
def find_path(map : Map, start : Vec2, goal : Vec2) : Array(Vec2)
  PATH_MEMO[{start,goal}]? || begin
                                open = [{start, [] of Vec2, 0}]
                                visited = Set(Vec2).new

                                while !open.empty?
                                  loc, route, len = open.pop
                                  next if visited.includes? loc

                                  new_route = route + [loc]
                                  if loc == goal
                                    PATH_MEMO[{start,goal}] = new_route
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
end

class Map
  property tiles : Array(Array(Tile))
  property all_keys : Set(Tile)
  property keys : Hash(Tile, Array(Tile))
  property key_locs : Hash(Tile, Vec2)
  property distances : Hash(Tile, Array(Int32))

  def initialize(tiles)
    @tiles = tiles
    @all_keys = Set(Tile).new
    @keys = Hash(Tile, Array(Tile)).new([] of Tile)
    @key_locs = Hash(Tile, Vec2).new
    @distances = Hash(Tile, Array(Int32)).new

    # find the keys and their requirements
    hero_loc = find('@')
    self.each_tile do |x,y,tile|
      if tile.ascii_lowercase?
        @all_keys.add tile
        @keys[tile] += find_path(self, hero_loc, Vec2.new(x,y))
                      .map { |loc| get(loc) }
                      .select { |t| t.ascii_uppercase? }
                      .map { |k| k.downcase }
        @key_locs[tile] = Vec2.new(x,y)


        @distances[tile] = calc_dmap_for(Vec2.new(x,y))
      end
    end
  end

  def key_difficulty(key : Tile)
    @keys[key].size
  end

  def key_loc(key : Tile)
    @key_locs[key]
  end

  def calc_dmap_for(loc : Vec2)
    dmap = Array(Int32).new(width*height, 9999999)
    bfs(loc) do |bfs_pos, steps|
      dmap[bfs_pos.y * width + bfs_pos.x] = steps
    end
    dmap
  end

  def get_distance_for(key : Tile, loc : Vec2)
    return Int32::MAX unless dmap = @distances[key]?
    dmap[loc.y * width + loc.x]
  end

  # bfs non-wall tiles, yield location and step count for each
  def bfs(start : Vec2, &block)
    open = Set{start}
    visited = Set(Vec2).new
    steps = 0

    while !open.empty?
      frontier = Set(Vec2).new

      open.each do |loc|
        next if visited.includes? loc

        yield(loc, steps)
        visited.add(loc)

        neighbors(loc).each do |n|
          frontier.add(n) if walkable?(n)
        end
      end

      open = frontier
      steps += 1
    end
  end

  def walkable?(t : Tile)
    case t
    when '#' then false
    else true
    end
  end

  def walkable?(l : Vec2)
    walkable?(get(l))
  end

  def width
    @tiles[0].size
  end

  def height
    @tiles.size
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

  def print_map
    @tiles.each do |row|
      row.each do |tile|
        print tile
      end
      print '\n'
    end
  end

  def print_dmap_for(key : Tile)
    dmap_tiles = "0123456789abcdefghijklmnopqrstuvwxyz".chars.to_a
    @tiles.each_with_index do |row, y|
      row.each_with_index do |tile, x|
        if walkable?(tile)
          print dmap_tiles[get_distance_for(key, Vec2.new(x,y)) % dmap_tiles.size]
        else
          print tile
        end
      end
      print '\n'
    end
  end
end

def neighbors(loc : Vec2)
  DIRS.map { |d| loc + d }
end
