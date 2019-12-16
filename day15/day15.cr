#!/usr/bin/env crystal
require "../lib/utils.cr"
require "../lib/vm2.cr"
require "../lib/display.cr"

class MapDisplay < Display::MapDisplay
  def tilemap(v)
    case v
    when 0 then " "
    when 1 then "."
    when 2 then "@"
    when 3 then ">"
    when 4 then "O"
    when 9 then "#"
    when 10 then " "
    else "*"
    end
  end

  def colormap(val)
    case val
    when  0 then {Termbox::COLOR_DEFAULT, Termbox::COLOR_DEFAULT}
    when  1 then {Termbox::COLOR_WHITE, Termbox::COLOR_BLACK}
    when  2 then {Termbox::COLOR_CYAN | Termbox::ATTR_BOLD, Termbox::COLOR_BLACK}
    when  3 then {Termbox::COLOR_GREEN, Termbox::COLOR_BLACK}
    when  4 then {Termbox::COLOR_BLUE | Termbox::ATTR_BOLD, Termbox::COLOR_BLACK}
    when  9 then {Termbox::COLOR_WHITE, Termbox::COLOR_BLACK}
    when 10 then {Termbox::COLOR_DEFAULT, Termbox::COLOR_DEFAULT}
    else {Termbox::COLOR_CYAN, Termbox::COLOR_BLACK}
    end
  end

  def rgbmap(val)
    case val
    when 1 then {25, 25, 25}
    when 2 then {0, 0, 255}
    when 3 then {0, 255, 0}
    when 4 then {41, 139, 132}
    when 9 then {139, 50, 23}
    when 10 then {0, 0, 0}
    else {255, 255, 127}
    end
  end

  def dump_frame
    @frame = 0 unless @frame
    @frame = @frame.try { |f| f+1}
    pixels = self.to_pixels
    Utils.write_ppm(@width, @height, pixels, "frames/d15-%08d.ppm" % @frame)
  end
end

class Droid
  property cpu : VM2::VM

  property x : Int32
  property y : Int32
  property facing : Int64

  property move_count : Int32
  property start_pos : Tuple(Int32, Int32)
  property station : Tuple(Int32, Int32)

  property map : MapDisplay

  DIRS = {
    0 => {0, 0},
    1 => {0, -1},
    2 => {0, 1},
    3 => {-1, 0},
    4 => {1, 0},
  }

  def initialize(cpu, curses = false)
    @cpu = cpu
    @x, @y = 0, 0
    @last_move = 0
    @move_count = 0
    @state = :ok
    @facing = 4
    @station = {-1, -1}
    @start_pos = {@x, @y}

    if curses
      @map = MapDisplay.new(`tput cols`.chomp.to_i, `tput lines`.chomp.to_i, 10, curses)
    else
      @map = MapDisplay.new(42, 42, 10, curses)
    end
    @map.set_offset(@map.width//-2, @map.height//-2)
  end

  def coords_facing(dir)
    d = DIRS[dir]
    {@x + d[0], @y + d[1]}
  end

  def right_from(facing)
    case facing
    when 1 then 4_i64
    when 2 then 3_i64
    when 3 then 1_i64
    when 4 then 2_i64
    else        raise "bad dir"
    end
  end

  def left_from(facing)
    case facing
    when 1 then 3_i64
    when 2 then 4_i64
    when 3 then 2_i64
    when 4 then 1_i64
    else        raise "bad dir"
    end
  end

  def check_dir(d)
    @cpu.send_input(d)
    @cpu.run
    res = @cpu.read_output
    case res
    when 1 # space ok, move back to where we started
      reverse = right_from(right_from(d))
      @cpu.send_input(reverse)
      @cpu.run
      raise "COULDN'T BACKTRACK !" if @cpu.read_output != 1
      :ok
    when 0 # wall
      :wall
    when 2 # station
      :station
    else raise "got bad output from cpu"
    end
  end

  def try_forward
    nx, ny = coords_facing(@facing)
    @cpu.send_input(@facing)
    @cpu.run
    res = @cpu.read_output
    case res
    when 1
      @map[{@x, @y}] = 1 unless map[{@x, @y}] == 3
      @x, @y = nx, ny
      @map[{@x, @y}] = 2
      @move_count += 1
      :ok
    when 0
      @map[{nx, ny}] = 9
      :wall
    when 2
      @map[{nx, ny}] = 3
      @station = {nx, ny}
      @x, @y = nx, ny
      :station
    else raise "got bad output form cpu"
    end
  end

  def turn_left
    @facing = left_from(@facing)
  end

  def turn_right
    @facing = right_from(@facing)
  end

  def update_vis
    @map.window.try { |w|
      @map.print_display

      sx, sy = @x - @map.offset_x, @y - @map.offset_y
      cx, cy = @map.width//2, @map.height//2

      min_x, max_x = 3, @map.width - 3
      min_y, max_y = 3, @map.height - 3

      ev = w.peek(5)
      if ev.ch.chr == 'q'
        return :stop
      elsif ev.ch.chr == 'c' || (sx < min_x || sx > max_x) || (sy < min_y || sy > max_y)
        @map.set_offset(@x - cx, @y - cy)
      end
    }
    if ENV["AOC_FRAMES"]? == "on"
      @map.dump_frame
    end
  end

  def run
    state = :look
    go = true
    while go
      case state
      when :move
        state = :look
        nx, ny = coords_facing(@facing)
        case try_forward
        when :ok
        when :wall
          turn_right
        when :station
          # break
        end
      when :look
        state = :move
        dir = left_from(@facing)
        lx, ly = coords_facing(dir)
        case check_dir(dir)
        when :ok
          @map[{lx, ly}] = 1
          turn_left
        when :wall # go forward
          @map[{lx, ly}] = 9
        when :station # end
          @map[{lx, ly}] = 3
        end
      end

      break if (@move_count > 0 && {@x,@y} == @start_pos) || update_vis == :stop

      # 3k should be enough to map anything
      break if @move_count > 3000
    end
  end
end

# Extract map
prog = Utils.get_input_file(Utils.cli_param_or_default(0,"day15/input.txt"))

curses = ARGV[1]? == "play"
droid = Droid.new(VM2.from_string(prog), curses)
droid.run

map = droid.map


map.set(droid.x,droid.y,1)
map[droid.start_pos] = 2
map.print_display

map.pause_for_input
map.dump_frame

# Use A* to map from droid.start_pos to droid.station

alias Pos = Tuple(Int32, Int32)

start = droid.start_pos
station = droid.station
solution = [] of Pos

visited = Set(Pos).new
open = [{start, [] of Pos, 1}]

def neighbors(loc) : Array(Pos)
  x, y = loc
  [{x - 1, y}, {x + 1, y}, {x, y + 1}, {x, y - 1}]
end

# P1
# puts "Start search..."

while !open.empty?
  loc, route, cost = open.pop
  next if visited.includes? loc

  new_route = [route, loc].flatten
  if loc == station
    solution = new_route.flatten
    break
  end

  visited.add(loc)

  neighbors(loc).each do |neighbor|
    next if map[neighbor]? == 9 || map[neighbor]? == 10 || visited.includes? neighbor
    tile_cost = map[neighbor]? || 99
    new_cost = cost + tile_cost
    open << {neighbor, new_route, new_cost}
  end

  open = open.sort_by { |_, _, cost| 0-cost }
end

if curses || ENV["AOC_FRAMES"]? == "on"
  map.set(droid.x,droid.y,1)
  map[droid.start_pos] = 2
  solution.shift
  stop = false
  solution.each_with_index do |loc, i|
    break if stop
    map[loc] = 11+i # use values over 10 to distinguish from walls/unexplored/etc
    map.print_display if curses
    map.dump_frame if ENV["AOC_FRAMES"]? == "on"

    map.window.try { |w|
      ev = w.peek(30)
      if ev.ch.chr == 'q'  || [Termbox::KEY_ESC, Termbox::KEY_CTRL_C].includes? ev.key
        stop = true
      elsif ev.ch.chr == 'c'
        map.set_offset(-21,-21)
      end
    }
  end

end

# P2
# Flood fill from station, count the steps

open = [station]
visited = Set(Pos).new
steps = 0

while !open.empty?
  frontier = [] of Pos
  open.each do |loc|
    next if visited.includes? loc
    visited.add(loc)

    map[loc] = 4
    map.dump_frame if ENV["AOC_FRAMES"]? == "on"

    neighbors(loc).each do |neighbor|
      frontier << neighbor if map[neighbor] != 9 && map[neighbor] != 10
    end
  end

  open = frontier
  steps += 1

  if curses
    map.print_display
    map.window.try { |w|
      ev = w.peek(15)
      if ev.ch.chr == 'q'
        open.clear
      elsif ev.ch.chr == 'c'
        map.set_offset(-21,-21)
      end
    }
  end
end

map.pause_for_input
map.shutdown_curses

puts "P1: %i" % (solution.size - 1)
puts "P2: %i" % (steps - 2) # account for initial expand and final check
