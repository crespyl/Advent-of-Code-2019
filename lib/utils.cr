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
end
