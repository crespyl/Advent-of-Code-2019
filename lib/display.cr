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

  def set(x, y, val : Int32)
    set(x,y,val.to_i64)
  end

  def set(x, y, val : Int64)
    @tiles[y][x] = val
    @crt.try { |crt|
      crt.attribute_on colormap(val)
      crt.print(y.to_i32, x.to_i32, tilemap(val))
      crt.refresh
    }
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
    @tiles.flat_map { |row| row }.map_with_index { |tile, i|
      print "\n" if i % @width == 0
      print tilemap(tile)
    }
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
  def colormap(v)
    Crt::Attribute::Normal
  end

  # Return the printable character for a given value
  abstract def tilemap(v)
end
