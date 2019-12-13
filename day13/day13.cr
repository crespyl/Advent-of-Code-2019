#!/usr/bin/env crystal
require "crt"
require "readline"
require "../lib/utils.cr"
require "../lib/vm2.cr"

class Display
  property width : Int32
  property height : Int32
  property tiles : Array(Array(Int64))
  property segment : Int64

  property crt : Crt::Window | Nil


  def initialize(width, height, curses=false)
    @width = width
    @height = height
    @segment = 0
    @tiles = [] of Array(Int64)
    height.times { @tiles << [0_i64] * width }

    @colormap = {} of Int32 => Crt::ColorPair

    @tilemap = {
      0 => " ",
      1 => "#",
      2 => "=",
      3 => "@",
      4 => "o",
      -1 => "?"
    }

    if curses
      @colormap = {
        0 => Crt::ColorPair.new(Crt::Color::Default, Crt::Color::Default),
        1 => Crt::ColorPair.new(Crt::Color::White, Crt::Color::White),
        2 => Crt::ColorPair.new(Crt::Color::Cyan, Crt::Color::Cyan),
        3 => Crt::ColorPair.new(Crt::Color::Green, Crt::Color::Default),
        4 => Crt::ColorPair.new(Crt::Color::Blue, Crt::Color::Default),
        5 => Crt::ColorPair.new(Crt::Color::White, Crt::Color::Blue),
        -1 => Crt::ColorPair.new(Crt::Color::White, Crt::Color::Red),
      }

      @crt = Crt::Window.new(height,width)
    else @crt = nil
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
      @crt.try { |crt|
        crt.attribute_on colormap(val)
        crt.print(y.to_i32, x.to_i32, tilemap(val))
        crt.refresh
      }
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
    if !@crt
      @tiles.flat_map{ |row| row }.map_with_index { |tile,i|
        print "\n" if i % @width == 0
        print tilemap(tile)
      }
      puts "\nSCORE: %i" % @segment
    else
      @crt.try { |crt|
        crt.attribute_on colormap(0)
        crt.attribute_on Crt::Attribute::Bold
        crt.print(@height-1,0, "SCORE: %i" % segment)
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

end

class ArcadeCabinet
  property cpu : VM2::VM
  property display : Display
  property always_print : Bool
  property draw_buffer : Array(Int64)
  property do_hack : Bool

  def initialize(cpu, curses=false)
    @cpu = cpu
    @display = Display.new(45,26,curses)
    @always_print = false
    @do_hack = false
    @draw_buffer = [] of Int64

    @cpu.debug = false
    @cpu.output_fn = ->(x: Int64) { proccess_output(x) }

    if curses = false
      @cpu.input_fn = ->() { get_input }
    else
      @cpu.input_fn = ->() { get_curses_input }
    end
  end

  def set_free_play
    @cpu.write_mem(0,2_i64)
  end

  def autopilot
    (@cpu.read_mem(388) <=> @cpu.read_mem(392)).to_i64
  end

  def proccess_output(val : Int64) : Nil
    @draw_buffer << val
    if @draw_buffer.size >= 3
      x,y,id = @draw_buffer.shift(3)

      @display.set(x,y,id)
      @display.print_display if @always_print
    end
  end

  def get_input(display=true) : Int64
    return autopilot if @do_hack

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
    when "x"
      autopilot
    else
      0_i64
    end
  end

  def get_curses_input
    return autopilot if @do_hack

    @display.crt.try { |crt|
      c = crt.getch
      log "\n>%i<\n" % c
      case c
      when 260, 104 then return -1_i64 # left arrow or h
      when 261, 108 then return  1_i64 # right arrow or l
      when 120 then return autopilot # x

      when 33 then @do_hack=true; autopilot # !

      when 63 # ?
        buf = [] of Int32
        crt.move(@display.height+1,0)
        crt.attribute_on @display.colormap(5)
        Crt.echo
        while (i = crt.getch) != 13
          buf << i
        end
        Crt.noecho
        crt.puts "got str: >%s<" % buf.map{ |i| i.unsafe_chr }.join
        0

      # exit on q, ^c or esc
      when 113, 27, 3 then @cpu.status = :halted
      end
    }
    return 0_i64
  end

  def log(msg)
    puts msg if Utils.enable_debug_output?
  end

  def run
    @cpu.run
  end

end

if ARGV[0]? == "play"
  Crt.init
  Crt.start_color
  Crt.raw

  cab = ArcadeCabinet.new(VM2.from_file(Utils.cli_param_or_default(1, "day13/input.txt")), true)
  cab.set_free_play
  cab.always_print = true
  cab.run

  # pause before exiting
  cab.display.crt.try { |c|
    c.attribute_on(cab.display.colormap(5))
    c.print(cab.display.height//3,3, "Game Over, press any key to continue")
    c.refresh
    c.getch
  }

  Crt.done

  puts "Game Over\nFinal Score: %i" % cab.display.segment
else
  prog = Utils.get_input_file(Utils.cli_param_or_default(0, "day13/input.txt"))
  # p1
  cab = ArcadeCabinet.new(VM2.from_string(prog))
  cab.always_print = false
  cab.run
  cab.display.print_display
  puts "P1: %i" % cab.display.count_painted(2)

  # reset for p2
  cab = ArcadeCabinet.new(VM2.from_string(prog))
  cab.always_print = false
  cab.set_free_play
  cab.do_hack = true
  cab.run
  puts "P2: %i" % cab.display.segment
end
