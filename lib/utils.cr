require "termbox"
# misc utility functions that are common in my solutions

module Utils
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
