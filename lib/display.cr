require "crt"
require "termbox"

module Display

  abstract class Display
    property width : Int32
    property height : Int32
    property tiles : Array(Array(Int64))

    property window : Termbox::Window | Nil

    def initialize(width, height, curses = false)
      @width = width
      @height = height
      @tiles = [] of Array(Int64)
      height.times { @tiles << [0_i64] * width }

      @window = Termbox::Window.new if curses
    end

    def get(x, y)
      @tiles[y][x]
    end

    def set(x, y, val : Int32)
      set(x,y,val.to_i64)
    end

    def set(x, y, val : Int64)
      @tiles[y][x] = val
      @window.try { |window|
        colors = colormap(val)
        window.write_string(Termbox::Position.new(y.to_i32, x.to_i32), tilemap(val), colors[0], colors[1])
        window.render
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
      if @window.nil?
        @tiles.flat_map { |row| row }.map_with_index { |tile, i|
          print "\n" if i % @width == 0
          print tilemap(tile)
        }
        print "\n"
      else
        @window.try { |window| window.render }
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
    def colormap(v)
      {Termbox::COLOR_DEFAULT, Termbox::COLOR_DEFAULT}
    end

    # Return the printable character for a given value
    abstract def tilemap(v)
    end

    class MapDisplay < Display
      property map : Hash(Tuple(Int32,Int32), Int64)
      property offset_x : Int32
      property offset_y : Int32

      def initialize(width, height, curses = false, default=0)
        @width, @height = width, height
        @offset_x, @offset_y = 0, 0
        @map = Hash(Tuple(Int32,Int32), Int64).new(default.to_i64)

        @tiles = [] of Array(Int64)
        height.times { @tiles << [0_i64] * width }

        @window = Termbox::Window.new if curses

        @window.try { |w|
          w.set_input_mode(Termbox::INPUT_ESC)
          w.clear
        }
      end
   
      def count_painted(color=nil)
        count = 0
        @map.each do |k,v|
          count += 1 if color && color == v || v != 0
        end
        count
      end

      def set_offset(x,y)
        @offset_x,@offset_y = x,y
        update_tiles
      end

      def set_offset(pos : Tuple(Int32, Int32))
        set_offset(pos[0],pos[1])
      end

      # update the array of tiles for rendering, based on the offset_x/y properties
      def update_tiles
        x,y = @offset_x, @offset_y
        height.times do |row|
          width.times do |col|
            val = @map[{x+col,y+row}]
            @tiles[row][col] = val
            @window.try { |w|
              colors = colormap(val)
              w.write_string(Termbox::Position.new(col.to_i32, row.to_i32), tilemap(val), colors[0], colors[1])
              w.render
            }
          end
        end
      end

      def print_display
        if @window.nil?
          @tiles.flat_map { |row| row }.map_with_index { |tile, i|
            print "\n" if i % @width == 0
            print tilemap(tile)
          }
          print "\n"
        else
          @window.try { |window| window.render }
        end
      end

      def tilemap(v)
        case v
        when 0 then " "
        when 1 then "."
        when 2 then "#"
        when 3 then "@"
        when 4 then ">"
        else "?"
        end
      end

      def [](loc : Tuple(Int32, Int32))
        @map[loc]
      end

      def []?(loc : Tuple(Int32, Int32))
        @map[loc]?
      end

      def []=(loc : Tuple(Int32, Int32), val)
        set(loc[0],loc[1],val.to_i64)
      end

      def set(x,y,val)
        @map[{x,y}] = val.to_i64
        @window.try { |window|
          colors = colormap(val)
          window.write_string(Termbox::Position.new(x.to_i32 - @offset_x,
                                                    y.to_i32 - @offset_y),
                              tilemap(val), colors[0], colors[1])
          window.render
        }
      end

      def get(x,y)
        @map[{x,y}]
      end

      def set(loc : Tuple(Int32,Int32), val)
        set(loc[0],loc[1], val)
      end

      def get(loc : Tuple(Int32, Int32), val)
        @map[loc]
      end

    end
  end
