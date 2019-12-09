require "./opcodes.cr"
require "./vm.cr"

# This module defines the "Intcode" interpreter and several utility functions
# for dealing with opcodes and parameter handling
module Intcode
  @@DEBUG = false

  # Parse the input string into an array of integers
  def self.read_intcode(str)
    str.split(',')
      .map { |s| Int64.new(s) }
      .reject { |x| !x.is_a? Int64 }
  end

  # Load an Intcode program from a filename, returned as an array of Integers
  def self.load_file(filename)
    read_intcode(File.read(filename))
  end

  # Enable or disable verbose debug logging during execution
  def self.set_debug(enable_debug)
    @@DEBUG = enable_debug
  end

  def self.log(msg)
    puts msg if @@DEBUG
  end

  # Represents an encoded parameter and its addressing mode, used by both the VM
  # and Opcodes
  struct Parameter
    property val : Int64   # The original value in memory
    property mode : Symbol # The addressing mode

    def initialize(@mode, @val) end

    # Return a debug string indicating the mode and value, used for debug and
    # disasm
    def debug
      case mode
      when :position then "@#{val}"
      when :literal then "#{val}"
      else
        "?#{mode}:#{val}"
      end
    end
  end

end
