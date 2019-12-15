#!/usr/bin/env crystal
require "crt"
require "readline"
require "../lib/utils.cr"
require "../lib/vm2.cr"
require "../lib/display.cr"

class MapDisplay < Display
  BLANK = 0
  NORTH = 1
  SOUTH = 2
  WEST = 3
  EAST = 4
  FLOOR = 5
  WALL = 6
  DROID = 7
  STATION = 8
  OXYGEN = 10

  property segment : Int64

  def initialize(@width, @height, curses = false)
    @width = width
    @height = height
    @segment = 0
    @tiles = [] of Array(Int64)
    height.times { @tiles << [0_i64] * width }

    @crt = Crt::Window.new(height, width) if curses

    @colormap = {} of Int32 => Crt::ColorPair
    @tilemap = {
       BLANK => " ",
       NORTH => "^",
       SOUTH => "v",
       EAST => ">",
       WEST => "<",
       FLOOR => ".",
       WALL => "#",
       DROID => "@",
       STATION => "+",
       OXYGEN => "O",
      -1 => "?",
    }

    if curses
      @colormap = {
         1 => Crt::ColorPair.new(Crt::Color::Default, Crt::Color::Default),
         2 => Crt::ColorPair.new(Crt::Color::White, Crt::Color::Blue),
         3 => Crt::ColorPair.new(Crt::Color::Cyan, Crt::Color::Default),
         4 => Crt::ColorPair.new(Crt::Color::Cyan, Crt::Color::Default),
         BLANK => Crt::ColorPair.new(Crt::Color::Default, Crt::Color::Default),
         FLOOR => Crt::ColorPair.new(Crt::Color::Default, Crt::Color::Default),
         WALL => Crt::ColorPair.new(Crt::Color::White, Crt::Color::Yellow),
         DROID => Crt::ColorPair.new(Crt::Color::White, Crt::Color::Blue),
         STATION => Crt::ColorPair.new(Crt::Color::White, Crt::Color::Red),
         4 => Crt::ColorPair.new(Crt::Color::White, Crt::Color::Cyan),
         5 => Crt::ColorPair.new(Crt::Color::White, Crt::Color::Blue),
        -1 => Crt::ColorPair.new(Crt::Color::White, Crt::Color::Red),
      }
    end
  end

  def set(x, y, val)
    if x < 0
      # segment display
      @segment = val.to_i64
    else
      if val == WALL && @tiles[y][x] != 0 && @tiles[y][x] != val
        raise "TRIED TO PUT A WALL ON SOMETHING THAT SHOULDN'T BE A WALL"
      end
      @tiles[y][x] = val.to_i64
      @crt.try { |crt|
        #crt.attribute_on colormap(val)
        crt.print(y.to_i32, x.to_i32, tilemap(val))
        crt.refresh
      }
    end
  end

  def print_display
    if !@crt
      @tiles.flat_map { |row| row }.map_with_index { |tile, i|
        print "\n" if i % @width == 0
        print tilemap(tile)
      }
      puts ""
    else
      @crt.try { |crt|
        crt.attribute_on colormap(0)
        crt.attribute_on Crt::Attribute::Bold
        crt.print(@height - 1, 0, "SCORE: %i" % segment)
        crt.attribute_off Crt::Attribute::Bold
        crt.refresh
      }
    end
  end

  def colormap(val)
    @colormap[val.to_i32]? || @colormap[-1]
  end

  def tilemap(val)
    @tilemap[val.to_i32] || @tilemap[-1]
  end

  def rgbmap(val)
    case val
    when 1 then {255,255,255}
    when 2 then {255,255,0}
    when 3 then {0,255,0}
    when 4 then {0,0,255}
    else {0,0,0}
    end
  end
end

class Droid
  property cpu : VM2::VM
  property display : MapDisplay
  property x : Int32
  property y : Int32

  property station : Tuple(Int32, Int32)

  property last_move : Int32
  property move_count : Int32
  property state : Symbol
  property facing : Int64

  property min_pos : Tuple(Int32,Int32)
  property max_pos : Tuple(Int32,Int32)
  property start_pos : Tuple(Int32,Int32)

  property map : Hash(Tuple(Int32, Int32), Int32)

  @@DIRS = {
    0 => { 0, 0},
    1 => { 0,-1},
    2 => { 0, 1},
    3 => {-1, 0},
    4 => { 1, 0}
  }

  def initialize(cpu, curses = false)
    @cpu = cpu
    @display = MapDisplay.new(110, 40, curses)
    @x, @y = @display.width//2, @display.height//2
    @last_move = 0
    @move_count = 0
    @log_line = 0
    @state = :ok
    @facing = 4
    @station = {-1,-1}
    @map = Hash(Tuple(Int32, Int32), Int32).new { |h,k| h[k] = 9 }
    @start_pos = {@x,@y}

    @min_pos = {@x,@y}
    @max_pos = {@x,@y}

    @cpu.debug = false

    @display.set(@x,@y, @facing)
  end

  def log(msg,color=1)
    @log_line = @log_line + 1 % 25
    if Utils.enable_debug_output?
      @display.crt.try { |crt|
        if @log_line % @display.height == 0
          @display.height.times do |i|
            crt.attribute_on(@display.colormap(1))
            crt.print(i, 0, " " * 30)
            crt.attribute_off(@display.colormap(1))
          end
        end
        crt.attribute_on(@display.colormap(color))
        crt.print(@log_line % @display.height, 1, "%5i: %s" % [@log_line,msg.ljust(20)])
        crt.refresh
        crt.attribute_off(@display.colormap(color))
      }
    end
  end

  def coords_facing(dir)
    d = @@DIRS[dir]
    {@x+d[0],@y+d[1]}
  end

  def right_from(facing)
    case facing
    when 1 then 4_i64
    when 2 then 3_i64
    when 3 then 1_i64
    when 4 then 2_i64
    else raise "bad dir"
    end
  end

  def left_from(facing)
    case facing
    when 1 then 3_i64
    when 2 then 4_i64
    when 3 then 2_i64
    when 4 then 1_i64
    else raise "bad dir"
    end
  end

  def reverse(dir)
    case dir
    when 1 then 2
    when 2 then 1
    when 3 then 4
    when 4 then 3
    else raise "bad dir"
    end
  end

  def check_dir(d)
    log "check #{d}"
    log "send> #{d}", 4
    @cpu.send_input(d)
    @cpu.run
    res = @cpu.read_output
    log "recv> #{res}", 4
    case res
    when 1 # space ok, move back to where we started
      log "send> #{reverse(d)}", 4
      @cpu.send_input(reverse(d))
      @cpu.run
      raise "COULDN'T BACKTRACK !" if @cpu.read_output != 1
      log "check: open"
      return :ok
    when 0 # wall
      log "check: wall"
      return :wall
    when 2 # station
      log "check: station"
      return :station
    else raise "got bad output from cpu"
    end
  end

  def try_forward
    nx,ny = coords_facing(@facing)
    log "send> #{@facing}", 4
    @cpu.send_input(@facing)
    @cpu.run
    res = @cpu.read_output
    log "recv> #{res}", 4
    case res
    when 1
      @display.set(@x,@y, MapDisplay::FLOOR)
      @map[{@x,@y}] = 1
      @x, @y = nx, ny
      @display.set(@x,@y, @facing)
      @move_count += 1
      :ok
    when 0
      @display.set(nx,ny, MapDisplay::WALL)
      @map[{nx,ny}] = 9
      :wall
    when 2
      @map[{nx,ny}] = 0
      @display.set(nx,ny, MapDisplay::STATION)
      @station = {nx,ny}
      @x, @y = nx, ny
      :station
    else raise "got bad output form cpu"
    end
  end

  def turn_left
    @facing = left_from(@facing)
    @display.set(@x,@y, @facing)
    log "l: new facing: #{@facing}", 2
  end

  def turn_right
    @facing = right_from(@facing)
    @display.set(@x,@y, @facing)
    log "r: new facing: #{@facing}", 2
  end

  def run
    state = :look
    mode = :left
    skip = 0

    while true

      case state
      when :move
        log "(move)", 2
        state = :look
        nx,ny = coords_facing(@facing)
        case try_forward
        when :ok
          log "moved forward"
        when :wall
          log "hit wall", 2
          mode == :left ? turn_right : turn_left
        when :station
          log "reached station after #{@move_count} moves", -1
          #break
          @display.set(nx,ny, MapDisplay::STATION)
        end
      when :look
        log "(look)", 1
        state = :move
        lx,ly = mode == :left ? coords_facing(left_from(@facing)) : coords_facing(right_from(@facing))
        d = mode == :left ? left_from(@facing) : right_from(@facing)
        case check_dir(d)
        when :ok
          @display.set(lx,ly, MapDisplay::FLOOR)
          @map[{lx,ly}] = 1
          mode == :left ? turn_left : turn_right
        when :wall # go forward
          @display.set(lx,ly, MapDisplay::WALL)
          @map[{lx,ly}] = 9
        when :station # end
          log "station!"
          @map[{lx,ly}] = 0
          @display.set(lx,ly, MapDisplay::STATION)
        end
      end

      # @display.set(-1,0, @move_count)
      # @display.print_display

      # check min/max
      min_x, min_y = @min_pos
      max_x, max_y = @max_pos

      min_x = @x if @x < min_x
      max_x = @x if @x > max_x

      min_y = @y if @y < min_y
      max_y = @y if @y > max_y

      @min_pos = {min_x,min_y}
      @max_pos = {max_x,max_y}

      if skip == 0
        ch = 'q'
        if @display.crt
          @display.crt.try { |crt| ch = crt.getch.chr }
        else
          #ch = Readline.readline("> ", true).try { |l| l.chars.first }
          ch = 'S'
        end

        case ch
        when nil, 'q' then break
        when 's' then skip=10
        when 'S' then skip=100
        when 't' then mode = mode == :left ? :right : :left
        when '?'
          log "query: #{[@x,@y].join(',')}: #{@facing}; #{mode}"
        end
        if ch.nil? || ch == 'q'
          break
        end
      else
        skip -= 1
      end

      break if @move_count > 3000

    end
  end
end

# Extract map
prog = Utils.get_input_file(Utils.cli_param_or_default(0, "day15/input.txt"))

# Crt.init
# Crt.start_color
# Crt.raw

crt = false
droid = Droid.new(VM2.from_string(prog), crt)
droid.display.set(droid.x,droid.y, droid.facing)

droid.run

# Crt.done

droid.display.print_display

puts "start: ", droid.start_pos
puts "station: ", droid.station
puts "min: ", droid.min_pos
puts "max: ", droid.max_pos
puts "moves: ", droid.move_count

# Use A* to map from droid.start_pos to droid.station

alias Pos = Tuple(Int32, Int32)
alias Route = Array(Pos)

map = droid.map
start = droid.start_pos
station = droid.station
solution = [] of Pos

visited = Set(Pos).new
open = [{start, [] of Pos, 1}]

def dist(a,b)
  Math.sqrt( (a[0]-b[0])*(a[0]-b[0]) + ((a[1]-b[1])*(a[1]-b[1])) )
end

def neighbors(loc) : Array(Pos)
  x,y = loc
  [{x-1,y}, {x+1,y}, {x,y+1}, {x, y-1}]
end

puts "Start search..."

cycles = 0
while !open.empty?
  cycles += 1

  if cycles % 1000 == 0
    puts "cycle #{cycles}; open set: #{open.size}"
  end

  loc, route, cost = open.pop
  next if visited.includes? loc

  new_route = [route, loc].flatten
  if loc == station
    solution = new_route.flatten
    break
  end

  visited.add(loc)

  neighbors(loc).each do |neighbor|
    next if map[neighbor]? == 9 || visited.includes? neighbor
    tile_cost = map[neighbor]? || 99
    new_cost = cost + tile_cost
    open << {neighbor, new_route, new_cost}
  end

  open = open.sort_by { |_,_,cost| cost }

end

puts "P1: %i" % (solution.size-1)

# Flood fill from station, count the steps

open = [station]
visited = Set(Pos).new
steps = 0

while !open.empty?

  frontier = [] of Pos

  open.each do |loc|
    next if visited.includes? loc

    droid.display.set(loc[0],loc[1],MapDisplay::OXYGEN)

    visited.add(loc)

    neighbors(loc).each do |neighbor|
      frontier << neighbor if map[neighbor] == 1
    end
  end

  open = frontier
  break if open.empty?

  if steps % 100 == 0 && Utils.enable_debug_output?
    droid.display.print_display
    puts "step #{steps}; open set: #{open.size}"
  end

  steps += 1
end


puts "P2: %i" % (steps-1) # -1 for the initial expand
