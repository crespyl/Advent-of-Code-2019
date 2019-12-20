require "termbox"
# misc utility functions that are common in my solutions

module Utils

  # Priority Queue
  class PQueue(T)
    def initialize()
      @queue = Array(Tuple(T,Int32)).new
    end

    def size
      @queue.size
    end

    def empty?
      @queue.empty?
    end

    def insert(val : T, p : Int32)
      @queue.push({val, p})
      idx = 0
      while idx < @queue.size
        if (pair = @queue[idx]) && pair[1] > p
          break
        end
        idx += 1
      end
      @queue.insert(idx, {val, p})
    end

    def insert_or_update(val : T, p : Int32)
      if idx = @queue.index { |pair| pair[0] == val }
        @queue.update(idx) { {val, p} }
      else
        insert(val, p)
      end
    end

    def pop_min
      @queue.pop()[0]
    end

    def pop_max
      @queue.shift()[0]
    end
  end

  struct Vec3
    property x : Int32
    property y : Int32
    property z : Int32

    def initialize(@x,@y,@z) end
    def initialize(xy : Vec2)
      @x = xy.x
      @y = xy.y
      @z = 0
    end

    def xy
      Vec2.new(@x,@y)
    end

    def [](i : Int32)
      case i
      when 0 then @x
      when 1 then @y
      when 2 then @z
      else raise "Bad index into Vec3"
      end
    end

    def []=(i : Int32, val : Int32)
      case i
      when 0 then @x = val
      when 1 then @y = val
      when 2 then @z = val
      else raise "Bad index into Vec3"
      end
    end

    def <=>(other : Vec3)
      {@x,@y,@z} <=> {other.x,other.y,other.z}
    end

    def +(other : Vec3)
      Vec3.new(self.x+other.x,self.y+other.y,self.z+other.z)
    end

    def -(other : Vec3)
      Vec3.new(self.x-other.x,self.y-other.y,self.z-other.z)
    end

    def *(other : Vec3)
      Vec3.new(self.x*other.x,self.y*other.y,self.z*other.z)
    end

    # manhattan distance
    def dist(other : Vec3)
      (self.x-other.x).abs + (self.y-other.y).abs + (self.z-other.z).abs
    end

    def dist(other : Vec2)
      (self.x-other.x).abs + (self.y-other.y).abs
    end

    def clone
      Vec3.new(@x,@y,@z)
    end

    def to_s
      "Vec3(#{@x},#{@y},#{@z})"
    end
  end


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
