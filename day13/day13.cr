#!/usr/bin/env crystal
require "colorize"
require "readline"
require "../lib/utils.cr"
require "../lib/vm2.cr"

class Display
  property tiles : Array(Array(Int64))
  property width : Int32
  property height : Int32

  property segment : Int64

  def initialize(width, height)
    @width = width
    @height = height
    @segment = 0
    @tiles = [] of Array(Int64)
    height.times do
      @tiles << [] of Int64
      width.times do
        @tiles.last << 0
      end
    end
  end

  def get(x,y)
    @tiles[y][x]
  end

  def set(x,y,val)
    if x < 0
      # segment display
      @segment = val
    else
      @tiles[y][x] = val
    end
  end

  def count_painted(color=nil)
    @tiles.flat_map { |row| row }.reduce(0) { |sum,tile|
      if color
        tile == color ? sum + 1 : sum
      else
        tile != 0 ? sum + 1 : sum
      end
    }
  end

  def print_display
    @tiles.each_with_index do |row,y|
      row.each_with_index do |tile,x|

        case tile
        when 0 then print " " #.colorize.back(:black)
        when 1 then print " ".colorize.back(:white)
        when 2 then print "=".colorize(:white)
        when 3 then print "-".colorize(:green)
        when 4 then print "o".colorize(:white)
        else print "?".colorize.back(:red)
        end

      end
      print "\n"
    end
    puts "SCORE: %i" % @segment
    puts ""
  end

end

class ArcadeCabinet
  property cpu : VM2::VM
  property display : Display
  property always_print : Bool
  property draw_buffer : Array(Int64)
  property do_hack : Bool

  def initialize(cpu, display)
    @cpu = cpu
    @display = display
    @always_print = false
    @do_hack = false
    @draw_buffer = [] of Int64

    @cpu.debug = false
    @cpu.output_fn = ->(x: Int64) { proccess_output(x) }
    @cpu.input_fn = ->() { get_input }
    #@cpu.exec_hook_fn = ->(vm: VM2::VM) { do_haxx }
  end

  def set_free_play
    @cpu.write_mem(0,2_i64)
  end

  def proccess_output(val : Int64)
    @draw_buffer << val
    if @draw_buffer.size >= 3
      x,y,id = @draw_buffer.shift(3)

      @display.set(x,y,id)
      @display.print_display if @always_print
    end
  end

  def get_input(display=true) : Int64
    @display.print_display
    input = Readline.readline("> ", true)
    case input
    when "h" then -1_i64
    when "l" then 1_i64
    when "?"
      puts "PC: %i" % @cpu.pc
      puts "paddle: %i" % @cpu.read_mem(392)
      puts "ballx: %i" % @cpu.read_mem(388)
      puts "bally: %i" % @cpu.read_mem(389)
      get_input(false)
    else
      if @do_hack
        if @cpu.read_mem(392) < @cpu.read_mem(388)
          puts "go right"
          1_i64
        elsif @cpu.read_mem(392) > @cpu.read_mem(388)
          puts "go left"
          -1_i64
        else
          puts "stay put"
          0_i64
        end
      else
        0_i64
      end
    end
  end

  def log(msg)
    puts msg
  end

  def run
    @cpu.run
  end

end


INPUT = Utils.get_input_file(Utils.cli_param_or_default(0, "day13/input.txt"))

cpu = VM2.from_string(INPUT)
display = Display.new(45,25)
cab = ArcadeCabinet.new(cpu, display)

cab.always_print = false
cab.set_free_play
cab.do_hack = true
cab.run

# p1
#
# display.print_display
# puts cab.draw_buffer
# puts display.count_painted(2)

#puts display.tiles.flat_map { |row| row }.reduce(0) { |sum,tile| tile == 3 ? sum + 1 : sum }
