#!/usr/bin/env ruby
require "colorize"
require_relative "../lib/utils.rb"
require_relative "../lib/vm2.rb"

def log(msg)
  if Utils.enable_debug_output?
    puts msg
  end
end

class Map
  attr_accessor :tiles

  def initialize(width, height)
    @tiles = []
    height.times do
      @tiles << []
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
    count = 0
    @tiles.each do |row|
      row.each do |tile|
        if (color && tile == color) || tile != :blank
          count += 1
        end
      end
    end
    count
  end
end


class Robot
  attr_accessor :cpu
  attr_accessor :map

  attr_accessor :x
  attr_accessor :y

  attr_accessor :facing

  attr_accessor :paint_count

  attr_accessor :state

  def initialize(map, program)
    @x, @y = 0,0
    @facing = :up
    @state = :wait_for_paint
    @paint_count = 0

    @map = map

    @cpu = VM2.from_string(program)
    @cpu.debug = false
    @cpu.input_fn = ->() { do_camera }
    @cpu.output_fn = ->(x) { do_action(x) }
  end

  def rotate_left
    case @facing
    when :up then @facing = :left
    when :left then @facing = :down
    when :down then @facing = :right
    when :right then @facing = :up
    else raise "can't rotate left from #{facing}"
    end
  end

  def rotate_right
    case @facing
    when :up then @facing = :right
    when :right then @facing = :down
    when :down then @facing = :left
    when :left then @facing = :up
    else raise "can't rotate right from #{@facing}"
    end
  end

  def move_forward
    case @facing
    when :up then @y -= 1
    when :right then @x += 1
    when :down then @y += 1
    when :left then @x -= 1
    else raise "can't move forward from #{@facing}"
    end
  end

  def do_camera
    input = map.get(x,y)

    if Utils.enable_debug_output?
      puts "robot #{@state} sees #{input} @ #{x},#{y}"
      puts
      print_map_robot(map, self)
      puts
    end

    case input
    when :white then 1
    when :black then 0
    when :blank then 0
    else raise "can't send input: #{input}"
    end
  end

  def do_action(a)
    log "robot #{@state} does action #{a} @ #{@x},#{@y}"
    case @state
    when :wait_for_move
      log "  do move #{a}"
      case a
      when 0 then rotate_left
      when 1 then rotate_right
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
    return nil
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
        print '@'
      else
        case tile
        when :blank then print " ".colorize(:background => :black)
        when :black then print " "
        when :white then print "#".colorize(:background => :white)
        else print "?".colorize(:background => :red)
        end
      end
    end
    print "\n"
  end
end


INPUT = Utils.get_input_file(Utils.cli_param_or_default(0, "day11/input.txt"))

# part 1
map = Map.new(100,100) # big enough I guess
robot = Robot.new(map, INPUT)
robot.x = 50
robot.y = 50

robot.run

#print_map_robot(map, robot)
puts "Robot stopped at: #{robot.x}, #{robot.y}"
puts "Part 1: %i" % map.count_painted

# part 2
map = Map.new(50,10)
robot = Robot.new(map, INPUT)
robot.x = 2
robot.y = 2

map.set(robot.x,robot.y, :white)
robot.run

puts "Robot stopped at: #{robot.x}, #{robot.y}"
puts "Part 2"
print_map_robot(map, robot)
