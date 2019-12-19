require "termbox"
# misc utility functions that are common in my solutions

module Utils
  struct Vec2
    property x : Int32
    property y : Int32

    def initialize(@x,@y) end

    def [](i : Int32)
      case i
      when 0 then @x
      when 1 then @y
      else raise "Bad index into Vec2"
      end
    end

    def []=(i : Int32, val : Int32)
      case i
      when 0 then @x = val
      when 1 then @y = val
      else raise "Bad index into Vec2"
      end
    end

    def <=>(other : Vec2)
      case x <=> other.x
      when 0 then x <=> other.y
      when -1 then -1
      when 1 then 1
      end
    end

    def +(other : Vec2)
      Vec2.new(self.x+other.x,self.y+other.y)
    end

    def -(other : Vec2)
      Vec2.new(self.x-other.x,self.y-other.y)
    end

    def *(other : Vec2)
      Vec2.new(self.x*other.x,self.y*other.y)
    end

    def dist(other : Vec2)
      Math.sqrt((@x - other.x)**2 + (@y - other.y)**2)
    end

    def clone
      Vec2.new(@x,@y)
    end

    def to_s
      "Vec2(#{@x},#{@y})"
    end
  end

  # check the AOC_DEBUG env var
  def self.enable_debug_output?
    ENV.has_key?("AOC_DEBUG") ? ENV["AOC_DEBUG"] == "true" : false
  end

  # get a parameter from the command line or else default
  def self.cli_param_or_default(n=0, default="")
    ARGV.size > n ? ARGV[n] : default
  end

  # read a file to string, strip any trailing whitespace
  def self.get_input_file(filename)
    File.read(filename).strip
  end

  # write an array of pixel RGB triples to a PPM file
  def self.write_ppm(width, height, pixels : Array(Tuple(Int32, Int32, Int32)), filename)
    File.open(filename, "w") do |file|
      file.print("P3\n%i %i\n255\n" % [width, height])
      pixels.each do |r,g,b|
        file.print("%i %i %i\n" % [r,g,b].map{ |v| v }) # wrap output to 255
      end
    end
  end

  # use Termbox peek to check for Ctrl-C/ESC/q
  def self.termbox_check_abort(window : Termbox::Window, ms=15) : Bool
    ev = window.peek(15)
    if ev.ch.chr == 'q' || ev.key == Termbox::KEY_CTRL_C || ev.key == Termbox::KEY_ESC
      true
    else
      false
    end
  end
end
