#!/usr/bin/env crystal
require "termbox"
require "readline"
require "../lib/utils.cr"
require "../lib/vm2.cr"
require "../lib/display.cr"

class SegmentDisplay < Display::Display
  property segment : Int64

  def initialize(@width, @height, curses = false)
    @width = width
    @height = height
    @tiles = [] of Array(Int64)
    height.times { @tiles << [0_i64] * width }

    @window = Termbox::Window.new if curses

    @segment = 0

    @colormap = {} of Int32 => Tuple(Int32, Int32)
    @tilemap = {
       0 => " ",
       1 => "#",
       2 => "=",
       3 => "@",
       4 => "o",
      -1 => "?",
    }

    if curses
      @colormap = {
         0 => {Termbox::COLOR_DEFAULT, Termbox::COLOR_DEFAULT},
         1 => {Termbox::COLOR_WHITE, Termbox::COLOR_WHITE},
         2 => {Termbox::COLOR_CYAN, Termbox::COLOR_CYAN},
         3 => {Termbox::COLOR_GREEN, Termbox::COLOR_DEFAULT},
         4 => {Termbox::COLOR_BLUE, Termbox::COLOR_DEFAULT},
         5 => {Termbox::COLOR_WHITE, Termbox::COLOR_BLUE},
        -1 => {Termbox::COLOR_WHITE, Termbox::COLOR_RED}
      }

      @window.try { |w|
        w.set_input_mode(Termbox::INPUT_ESC)
        w.clear
      }
    end
  end

  def set(x, y, val)
    if x < 0
      # segment display
      @segment = val
    else
      @tiles[y][x] = val
      @window.try { |window|
        colors = colormap(val)
        window.write_string(Termbox::Position.new(x.to_i32, y.to_i32), tilemap(val), colors[0], colors[1])
        window.render
      }
    end
  end

  def print_display
    if !@window
      @tiles.flat_map { |row| row }.map_with_index { |tile, i|
        print "\n" if i % @width == 0
        print tilemap(tile)
      }
      puts ""
    else
      @window.try { |window|
        colors = colormap(0)
        window.write_string(Termbox::Position.new(0, @height-1), "SCORE: %i" % segment, colors[0], colors[1])
        window.render
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

class ArcadeCabinet
  property cpu : VM2::VM
  property display : SegmentDisplay
  property always_print : Bool
  property draw_buffer : Array(Int64)
  property do_hack : Bool
  property save_frames : Bool

  def initialize(cpu, curses = false)
    @cpu = cpu
    @display = SegmentDisplay.new(45, 26, curses)
    @always_print = false
    @do_hack = false
    @save_frames = false
    @draw_buffer = [] of Int64

    @cpu.debug = false
    @cpu.output_fn = ->(x : Int64) { proccess_output(x) }

    if curses = false
      @cpu.input_fn = ->{ get_input }
    else
      @cpu.input_fn = ->{ get_curses_input }
    end
  end

  def set_free_play
    @cpu.write_mem(0, 2_i64)
  end

  def autopilot
    (@cpu.read_mem(388) <=> @cpu.read_mem(392)).to_i64
  end

  def proccess_output(val : Int64) : Nil
    @draw_buffer << val
    if @draw_buffer.size >= 3
      x, y, id = @draw_buffer.shift(3)

      @display.set(x, y, id)
      @display.print_display if @always_print

      if @save_frames
        @frame = @frame ? @frame.try{ |f| f+1 } : 0
        pixels = @display.to_pixels
        Utils.write_ppm(@display.width,@display.height, pixels, "frames/d13-%08i.ppm" % @frame)
      end
    end
  end

  def get_input(display = true) : Int64
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

    @display.window.try { |window|
      while (ev = window.poll).type != Termbox::EVENT_KEY
      end

      log "\n>%i<\n" % ev.key

      if ev.key == Termbox::KEY_ARROW_LEFT || ev.ch.chr == 'h'
        return -1_i64
      elsif ev.key == Termbox::KEY_ARROW_RIGHT || ev.ch.chr == 'l'
        return  1_i64
      elsif ev.key == Termbox::KEY_ESC || ev.key == Termbox::KEY_CTRL_C || ev.ch.chr == 'q'
        @cpu.status = :halted
        return  0_i64
      elsif ev.ch.chr == 'x'
        return  autopilot
      elsif ev.ch.chr == '!'
        @do_hack = true
        autopilot
      else
        return  0_i64
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
  cab = ArcadeCabinet.new(VM2.from_file(Utils.cli_param_or_default(1, "day13/input.txt")), true)
  cab.set_free_play
  cab.always_print = true
  cab.run

  # pause before exiting
  cab.display.window.try { |w|
    colors = cab.display.colormap(5)
    w.set_primary_colors(colors[0], colors[1])
    w.write_string(Termbox::Position.new(3, cab.display.height//3), "Game Over, press any key to continue")
    w.render
    w.poll
    w.shutdown
  }

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
  cab.save_frames = ENV["AOC_FRAMES"]? == "on"
  cab.run
  puts "P2: %i" % cab.display.segment
end
