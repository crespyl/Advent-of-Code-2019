#!/usr/bin/env crystal
require "colorize"
require "../lib/utils.cr"
require "../lib/vm2.cr"
require "../lib/display.cr"

DIRECTIONS = [{0,-1}, {1,0}, {0,1}, {-1,0}]

class MapDisplay < Display::Display
  property tiles : Array(Array(Int64))
  property width : Int32
  property height : Int32

  def initialize(@width, @height)
    @tiles = [] of Array(Int64)
    height.times do
      @tiles << [-1_i64] * width
    end
  end

  def count_painted(color=nil)
    @tiles.reduce(0) { |sum, row|
      sum + row.reduce(0) { |rsum, tile|
        if (color && tile == color) || tile != -1
          rsum + 1
        else rsum end
      }
    }
  end

  def rgbmap(val)
    case val
    when  1 then {255,255,255}
    when  0 then {0,0,0}
    else {10,10,10}
    end
  end

  def tilemap(val)
    case val
    when -1 then " "
    when  0 then " "
    when  1 then "#"
    else "?"
    end
  end
end


class Robot
  property cpu : VM2::VM
  property map : MapDisplay

  property x : Int32
  property y : Int32

  property facing : Int32

  property paint_count : Int32

  property state : Symbol
  property print_frames : Bool

  def initialize(map, program)
    @x, @y = 0,0
    @facing = 0
    @state = :wait_for_paint
    @paint_count = 0
    @print_frames = false

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

    input < 0 ? 0_i64 : input
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
      map.set(x,y,a)
      @paint_count += 1
      if @print_frames
        @frame = @frame ? @frame.try{ |f| f+1 } : 0
        pixels = @map.to_pixels
        Utils.write_ppm(@map.width, @map.height, pixels, "frames/d11-%08i.ppm" % @frame)
      end
      @state = :wait_for_move
    end
  end

  def run
    log "robot run"
    cpu.run
    log "robot stop"
  end
end

def log(msg)
  if Utils.enable_debug_output?
    puts msg
  end
end


INPUT = Utils.get_input_file(Utils.cli_param_or_default(0, "day11/input.txt"))

# part 1
width,height = 200,200
map = MapDisplay.new(width,height) # big enough I guess
robot = Robot.new(map, INPUT)
robot.x = width//2
robot.y = height//2

#robot.print_frames = true
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
map = MapDisplay.new(width,height)
robot = Robot.new(map, INPUT)
robot.x = 2
robot.y = 2

map.set(robot.x,robot.y, 1)

robot.run

puts "Robot stopped at: #{robot.x}, #{robot.y}"
puts "Part 2"
map.print_display

pixels = map.tiles.flatten.map { |tile| case tile
                                        when :black then {0,0,0}
                                        when :white then {255,255,255}
                                        else {50,50,50}
                                        end }
Utils.write_ppm(width,height, pixels, "day11/output-p2.ppm")

