#!/usr/bin/env crystal
require "../lib/utils.cr"
require "../lib/vm2.cr"

class Droid
  property cpu : VM2::VM

  property x : Int32
  property y : Int32
  property facing : Int64

  property move_count : Int32
  property start_pos : Tuple(Int32,Int32)
  property station : Tuple(Int32, Int32)

  property map : Hash(Tuple(Int32, Int32), Int32)

  DIRS = {
    0 => { 0, 0},
    1 => { 0,-1},
    2 => { 0, 1},
    3 => {-1, 0},
    4 => { 1, 0}
  }

  def initialize(cpu, curses = false)
    @cpu = cpu
    @x, @y = 0, 0
    @last_move = 0
    @move_count = 0
    @state = :ok
    @facing = 4
    @station = {-1,-1}
    @map = Hash(Tuple(Int32, Int32), Int32).new { |h,k| h[k] = 9 }
    @start_pos = {@x,@y}
  end

  def coords_facing(dir)
    d = DIRS[dir]
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
    nx,ny = coords_facing(@facing)
    @cpu.send_input(@facing)
    @cpu.run
    res = @cpu.read_output
    case res
    when 1
      @map[{@x,@y}] = 1
      @x, @y = nx, ny
      @move_count += 1
      :ok
    when 0
      @map[{nx,ny}] = 9
      :wall
    when 2
      @map[{nx,ny}] = 0
      @station = {nx,ny}
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

  def run
    state = :look
    while true
      case state
      when :move
        state = :look
        nx,ny = coords_facing(@facing)
        case try_forward
        when :ok
        when :wall
          turn_right
        when :station
          #break
        end
      when :look
        state = :move
        dir = left_from(@facing)
        lx,ly = coords_facing(dir)
        case check_dir(dir)
        when :ok
          @map[{lx,ly}] = 1
          turn_left
        when :wall # go forward
          @map[{lx,ly}] = 9
        when :station # end
          @map[{lx,ly}] = 0
        end
      end

      # 3k should be enough to map anything
      break if @move_count > 3000
    end
  end
end

# Extract map
prog = Utils.get_input_file(Utils.cli_param_or_default(0, "day15/input.txt"))
droid = Droid.new(VM2.from_string(prog))
droid.run

map = droid.map

# Use A* to map from droid.start_pos to droid.station

alias Pos = Tuple(Int32, Int32)

start = droid.start_pos
station = droid.station
solution = [] of Pos

visited = Set(Pos).new
open = [{start, [] of Pos, 1}]

def neighbors(loc) : Array(Pos)
  x,y = loc
  [{x-1,y}, {x+1,y}, {x,y+1}, {x, y-1}]
end

#puts "Start search..."

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
    visited.add(loc)
    neighbors(loc).each do |neighbor|
      frontier << neighbor if map[neighbor] == 1
    end
  end

  open = frontier
  steps += 1
end

puts "P2: %i" % (steps-2) # account for initial expand and final check
