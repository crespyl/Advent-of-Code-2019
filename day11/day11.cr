#!/usr/bin/env crystal
require "colorize"
require "../lib/utils.cr"
require "../lib/vm2.cr"

DIRECTIONS = [{0,-1}, {1,0}, {0,1}, {-1,0}]

class Map
  property tiles : Array(Array(Symbol))

  def initialize(width, height)
    @tiles = [] of Array(Symbol)
    height.times do
      @tiles << [] of Symbol
      width.times do
        @tiles.last << :blank
      end
    end
  end

  def get(x,y)
    @tiles[y][x]
  end

  def set(x,y,val)
    @tiles[y][x] = val
  end

  def count_painted(color=nil)
    @tiles.reduce(0) { |sum, row|
      sum + row.reduce(0) { |rsum, tile|
        if (color && tile == color) || tile != :blank
          rsum + 1
        else rsum end
      }
    }
  end
end


class Robot
  property cpu : VM2::VM
  property map : Map

  property x : Int32
  property y : Int32

  property facing : Int32

  property paint_count : Int32

  property state : Symbol

  def initialize(map, program)
    @x, @y = 0,0
    @facing = 0
    @state = :wait_for_paint
    @paint_count = 0

    @map = map

    @cpu = VM2.from_string(program)
    @cpu.debug = false
    @cpu.input_fn = ->() { read_camera }
    @cpu.output_fn = ->(x: Int64) { do_action(x) }
  end

  def move_forward
    @x += DIRECTIONS[@facing][0]
    @y += DIRECTIONS[@facing][1]
  end

  def read_camera : Int64
    input = map.get(x,y)

    if Utils.enable_debug_output?
      puts "robot #{@state} sees #{input} @ #{x},#{y}"
      puts
      print_map_robot(map, self)
      puts
    end

    case input
    when :white then 1_i64
    when :black then 0_i64
    when :blank then 0_i64
    else raise "can't send input: #{input}"
    end
  end

  def do_action(a : Int64) : Nil
    log "robot #{@state} does action #{a} @ #{@x},#{@y}"
    case @state
    when :wait_for_move
      log "  do move #{a}"
      case a
      when 0 then @facing = (@facing - 1) % 4
      when 1 then @facing = (@facing + 1) % 4
      else raise "robot can't handle move output #{a}"
      end
      move_forward
      @state = :wait_for_paint
    when :wait_for_paint
      log "  do paint #{a}"
      case a
      when 0 then map.set(x,y,:black)
      when 1 then map.set(x,y,:white)
      else raise "robot can't handle paint output #{a}"
      end
      @paint_count += 1
      @state = :wait_for_move
    end
  end

  def run
    log "robot run"
    cpu.run
    log "robot stop"
  end
end

def print_map_robot(map, robot)
  map.tiles.each_with_index do |row,y|
    row.each_with_index do |tile,x|
      if robot.x == x && robot.y == y
        print "@@"
      else
        case tile
        when :blank then print "  "
        when :black then print "  ".colorize.back(:black)
        when :white then print "##".colorize.back(:white)
        else print "??".colorize.back(:red)
        end
      end
    end
    print "\n"
  end
end

def log(msg)
  if Utils.enable_debug_output?
    puts msg
  end
end


INPUT = Utils.get_input_file(Utils.cli_param_or_default(0, "day11/input.txt"))

# part 1
width,height = 100,100
map = Map.new(width,height) # big enough I guess
robot = Robot.new(map, INPUT)
robot.x = width//2
robot.y = height//2

robot.run

#print_map_robot(map, robot)
pixels = map.tiles.flatten.map { |tile| case tile
                                        when :black then {0,0,0}
                                        when :white then {255,255,255}
                                        else {50,50,50}
                                        end }
Utils.write_ppm(width,height, pixels, "day11/output-p1.ppm")

puts "Robot stopped at: #{robot.x}, #{robot.y} (cpu: #{robot.cpu.status}, #{robot.cpu.cycles} cycles)"
puts "Part 1: %i" % map.count_painted

# part 2
width,height = 50,10
map = Map.new(width,height)
robot = Robot.new(map, INPUT)
robot.x = 2
robot.y = 2

map.set(robot.x,robot.y, :white)
robot.run

puts "Robot stopped at: #{robot.x}, #{robot.y}"
puts "Part 2"
print_map_robot(map, robot)

pixels = map.tiles.flatten.map { |tile| case tile
                                        when :black then {0,0,0}
                                        when :white then {255,255,255}
                                        else {50,50,50}
                                        end }
Utils.write_ppm(width,height, pixels, "day11/output-p2.ppm")
