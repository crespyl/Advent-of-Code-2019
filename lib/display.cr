require "crt"

alias Color = Crt::ColorPair

abstract class Display
  property width : Int32
  property height : Int32
  property tiles : Array(Array(Int64))

  property crt : Crt::Window | Nil

  def initialize(width, height, curses = false)
    @width = width
    @height = height
    @tiles = [] of Array(Int64)
    height.times { @tiles << [0_i64] * width }

    @crt = Crt::Window.new(height, width) if curses
  end

  def get(x, y)
    @tiles[y][x]
  end

  def set(x, y, val)
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

  def count_painted(color = nil)
    @tiles.flat_map { |row| row }.reduce(0) { |sum, tile|
      if color
        tile == color ? sum + 1 : sum
      else
        tile != 0 ? sum + 1 : sum
      end
    }
  end

  def print_display
    if !@crt
      @tiles.flat_map { |row| row }.map_with_index { |tile, i|
        print "\n" if i % @width == 0
        print tilemap(tile)
      }
      puts "\nSCORE: %i" % @segment
    else
      @crt.try { |crt|
        crt.attribute_on colormap(0)
        crt.attribute_on Crt::Attribute::Bold
        crt.print(@height - 1, 0, "SCORE: %i" % segment)
        crt.attribute_off Crt::Attribute::Bold
        crt.refresh
      }
    end
  end

  def to_pixels
    @tiles.flat_map { |row| row }.map { |v| rgbmap(v) }
  end

  def to_tiles
    @tiles.flat_map { |row| row }.map { |v| tilemap(v) }
  end

  # Return an RGB triple for a given value (for printing to PPM, etc)
  def rgbmap(v): Tuple(Int32, Int32, Int32)
    v = v.to_i32
    {v%255, v%255, v%255}
  end

  # Return the color for a given value (in whatever format needed by the
  # terminal library in use)
  abstract def colormap(v)

  # Return the printable character for a given value
  abstract def tilemap(v)
end
