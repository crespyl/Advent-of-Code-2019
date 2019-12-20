#!/usr/bin/env crystal
require "colorize"
require "../lib/utils.cr"
include Utils

input = File.read(Utils.cli_param_or_default(0,"day20/sample.txt"))

grid = input.lines.map { |l| l.chars.to_a }

map = Map.new(grid)
map.print_map

path = bfs_path(->(loc : Vec2) { map.walkable_neighbors(loc) },
                map.start,
                map.goal)

map.print_map_path(path)
puts "Part 1: %i\n" % (path.size-1) # -1 to exclude the starting tile

path = astar_path(->(loc : Vec3) { map.recursive_walkable_neighbors(loc) },
                  ->(loc : Vec3) { loc.dist(map.goal) },
                  Vec3.new(map.start),
                  Vec3.new(map.goal))

map.print_map_path(path)
puts "Part 2: %i" % (path.size-1)

def bfs_path(neighbors : Proc(Vec2, Array(Vec2)), start : Vec2, goal : Vec2)
  open = Set(Tuple(Vec2, Array(Vec2))).new
  open.add({ start, [start] })
  visited = Set(Vec2).new

  iterations = 0
  while !open.empty?
    iterations += 1
    #puts "BFS Iterations: %i" % [iterations] if iterations % 100 == 0

    frontier = Set(Tuple(Vec2, Array(Vec2))).new

    open.each do |state|
      loc, path = state
      next if visited.includes? loc
      visited.add(loc)

      #map.print_map_path(path)

      return path if loc == goal

      neighbors.call(loc).each do |n|
        next if visited.includes? n
        frontier.add({n, path.clone << n})
      end
    end

    open = frontier
  end

  return [] of Vec2
end

def astar_path(get_neighbors : Proc(Vec3, Array(Vec3)), heuristic : Proc(Vec3, Int32), start : Vec3, goal : Vec3)
  open = Set(Vec3).new
  open.add(start)

  # map of the best known route to each node
  prev = Hash(Vec3, Vec3).new

  # distance from start to each node
  gscore = Hash(Vec3, Int32).new(Int32::MAX)
  gscore[start] = 0

  # heuristic scores for each node
  fscore = Hash(Vec3, Int32).new(Int32::MAX)
  fscore[start] = heuristic.call(start)

  # helper proc to produce an Array(Vec3) from the prev map
  reconstruct_path = ->(node : Vec3) {
    path = [node] of Vec3
    while (node = prev[node]?)
      path << node
    end
    return path
  }

  iterations = 0
  while !open.empty?
    iterations += 1

    # select the open node with the best heuristic score
    loc = open.min_by { |loc| fscore[loc] }
    open.delete(loc)

    # if iterations % 100000 == 0
    #   puts "A* Iterations: %i (%i)" % [iterations, open.size]
    #   map.print_map_path(reconstruct_path.call(loc))
    # end

    if loc == goal
      #puts "A* search ended: #{path}"
      return reconstruct_path.call(loc)
    end

    get_neighbors.call(loc).each do |n|
      # see if reaching n from this route is better than any previous route we
      # took to get here; if so, update the prev table and heuristic scores
      alt = gscore[loc] + loc.dist(n)
      if alt < gscore[n]
        prev[n] = loc
        gscore[n] = alt
        fscore[n] = gscore[n] + heuristic.call(n)

        open.add(n) unless open.includes? n
      end
    end
  end

  return [] of Vec3
end

# up, right, down, left
DIRS = [Vec2.new(0,-1), Vec2.new(1,0), Vec2.new(0,1), Vec2.new(-1,0)]

alias Tile = Char

class Map
  property grid : Array(Array(Tile))
  property portals : Hash(Vec2, Vec2)
  property start : Vec2
  property goal : Vec2
  property width : Int32
  property height : Int32

  def initialize(grid)
    @depth = 0
    @grid = grid
    @portals = Hash(Vec2, Vec2).new
    @start = Vec2.new(0,0)
    @goal = Vec2.new(0,0)

    @height = @grid.size
    @width = @grid.map{ |row| row.size }.max # width calc is trickier since the
                                             # padding whitespace gets in the
                                             # way

    parse_portal_locs

    #puts "Map Ready (#{@width}x#{@height})"
  end

  def parse_portal_locs
    found_labels = Array(Tuple(String, Vec2)).new

    each_loc do |loc, tile|
      next unless tile.ascii_uppercase?
      # we found part of a portal, we need to find the upper-case neighbor,
      # and the attached actual grid point

      portal_loc = loc
      other_tile = tile

      normal_neighbors(loc).each do |neighbor|
        tile_neighbor = get(neighbor)
        #puts "   neighbor: #{tile_neighbor} (#{neighbor})"

        if tile_neighbor == '.'
          portal_loc = neighbor
        end

        next unless tile_neighbor.ascii_uppercase?

        other_tile = tile_neighbor
        #puts "   Tile Pair #{tile}, #{other_tile}; #{loc}"
      end

      if portal_loc != loc
        name = [tile, other_tile].sort.join
        found_labels << { name, portal_loc }
        #puts "Found Portal #{name} at #{portal_loc}"
      end
    end

    while !found_labels.empty?
      name, loc = found_labels.pop

      if name == "AA"
        @start = loc
        next
      elsif name == "ZZ"
        @goal = loc
        next
      end

      # find the other end
      other = found_labels.find { |pair| pair[0] == name }
      raise "Couldn't find other end of portal #{name}!" unless other

      # remove the other end from our set
      found_labels.reject!(other)
      _, other_loc = other

      @portals[loc] = other_loc
      @portals[other_loc] = loc
      #puts "Registered portal %s: %s -- %s" % [name, loc.to_s, other_loc.to_s]
    end
  end

  def each_loc(&block)
    @grid.each_with_index do |row, y|
      row.each_with_index do |tile, x|
        yield(Vec2.new(x,y),tile)
      end
    end
  end

  def walkable_neighbors(loc : Vec2) : Array(Vec2)
    portal_neighbors(loc).select { |l| get(l) == '.' }
  end

  def recursive_walkable_neighbors(loc : Vec3)
    recursive_portal_neighbors(loc).select { |l| get(l.xy) == '.' }
  end

  # n/e/s/w neighbors, but also check for portals
  def portal_neighbors(loc : Vec2)
    normal_neighbors(loc) + [@portals[loc]?].compact
  end

  # n/e/s/w neighbors and portals, but portals lead one layer in or out (z-axis)
  def recursive_portal_neighbors(loc : Vec3)
    neighbors = normal_neighbors(loc)

    if portal = @portals[loc.xy]?
      # inner or outer portal?
      if (loc.x > 2 && loc.y > 2 && loc.x < (@width-3) && loc.y < (@height-3))
        neighbors << Vec3.new(portal.x, portal.y, loc.z + 1)
      elsif loc.z > 0 && (loc.x <= 2 || loc.y <= 2 || loc.x >= @width-3 || loc.y >= @height-3)
        neighbors << Vec3.new(portal.x, portal.y, loc.z - 1)
      end

    end
    return neighbors
  end

  # n/e/s/w neighbors, ignoring portals
  def normal_neighbors(loc : Vec2)
    DIRS.map { |d| d + loc }
  end

  # "3d" neighbors, same z
  def normal_neighbors(loc : Vec3)
    DIRS.map { |d| Vec3.new(d.x+loc.x, d.y+loc.y, loc.z) }
  end

  def get(loc : Vec2)
    get_grid(loc.x, loc.y)
  end

  def get_grid(x, y) : Tile
    if @grid.size > y && y >= 0
      if @grid[y].size > x && x >= 0
        return @grid[y][x]
      end
    end
    return ' '
  end

  def print_map
    @grid.each_with_index do |row, y|
      row.each_with_index do |tile, x|
        if tile == '#'
          print tile.to_s.colorize(:red).mode(:dim)
        else
          print tile
        end
      end
      print "\n"
    end
  end

  def print_map_path(path : Array(Vec2))
    print_map_path(path.map { |l| Vec3.new(l) })
  end

  def print_map_path(path : Array(Vec3))
    @grid.each_with_index do |row, y|
      row.each_with_index do |tile, x|
        if l = path.find { |l| l.x == x && l.y == y }
          print ("%i" % (l.z % 10)).colorize(:green).mode(:bright)
        elsif tile == '#'
          print "#".colorize(:red).mode(:dim)
        else
          print tile
        end
      end
      print "\n"
    end
  end
end
