#!/usr/bin/env ruby
require_relative "../lib/utils.rb"

Value = Struct.new(:resource, :amount)

class Rule
  attr_accessor :output
  attr_accessor :requirements

  def initialize(reqs, output)
    @requirements = reqs
    @output = output
  end

  def to_s
    "%s => %s" % [@requirements.map(&:to_s).join(', '), @output]
  end
end

def parse_value(str)
  m = str.match(/(\d+)\s+(\w+)/)
  Value.new(m[2],m[1].to_i).freeze if m
end

def parse_rule(str)
  reqs, out = str.split(" => ")
  reqs = reqs.split(", ").map{ |s| parse_value(s) }

  out = parse_value(out)

  Rule.new(reqs, out).freeze
end

def parse_file(filename)
  File.read(filename)
    .lines
    .map(&:chomp)
    .map { |line| parse_rule(line) }
    .each_with_object({}) { |rule, hash| hash[rule.output.resource] = rule }
    .freeze
end

# take a list that might contain several values with the same resource and fold
# them into one value for each resource
def collapse_values(values)
  values.each_with_object(Hash.new { |h,k| h[k] = 0 }) { |v,h|
    h[v.resource] += v.amount
  }.map { |k,v| Value.new(k,v) }
end

# get the requirements necessary to produce the requested value
def reqs_for_value(rules, value)
  rule = rules[value.resource]
  return [[],0]  unless rule && value.amount > 0
 
  reqs = rule.requirements.map { |v| Value.new(v.resource, v.amount) }
  excess = 0

  if rule.output.amount >= value.amount
    # one application of this rule is enough
    excess = rule.output.amount - value.amount
  else
    # we need a multiple of the values
    extras = (value.amount / rule.output.amount) + (value.amount % rule.output.amount == 0 ? 0 : 1)
    reqs = reqs.map { |req| Value.new(req.resource, req.amount * extras) }
    excess = (rule.output.amount * extras) - value.amount
  end
  [reqs, excess]
end

# Breakdown a value into the amount of ore necessary to produce it
#
# The basic idea is to walk the provided ORE => FUEL formula backwards. For any
# given value with rule (m X => n Y) we do the following:
#
#  given (n Y) in our working set,
#  note that we have PRODUCED (n Y),
#  remove (n Y) from the working set,
#  state that we must have CONSUMED (m X),
#  add (m X) to the working set
#
# the difference between the amount PRODUCED and CONSUMED for any given resource
# is considered available, and can be used to reduce the requirements for the
# next rule that needs them.
def breakdown(rules, value)
  values = [value]

  produced = Hash.new(0)
  consumed = Hash.new(0)

  # Keep iterating over our list of available values, until all that's left is ORE
  while ! values.empty? && ! values.all? { |v| v.resource == "ORE" }
    values = collapse_values(values) # make sure we fold the list down and don't
                                     # have two or more clumps of the same
                                     # resource at once

    # select one value to examine and get is requirements, along with any excess
    # that will be produced
    needed = values.shift
    reqs, extra = reqs_for_value(rules, needed)

    reqs.each do |req|
      # for each requirement
      available = produced[req.resource] - consumed[req.resource]
      if produced[req.resource] > 0 && produced[req.resource] >= consumed[req.resource]
        # if we have some spares available, modify the required amount and note
        # the consumption
        if available >= req.amount
          consumed[req.resource] += req.amount
          req.amount = 0
        elsif available > 0 && available < req.amount
          consumed[req.resource] += available
          req.amount -= available
        end
      end

      # having updated the required amount to account for any already available,
      # we note the consumption
      consumed[req.resource] += req.amount
    end

    # now that we processed all the requirements, we can state that we produced
    # some amount
    produced[needed.resource] += needed.amount + extra

    # and we add the requirements to our working set so that we can keep
    # following the chain
    values += reqs
  end

  # lastly we just pull out the amount of ore we consumed during the process
  consumed["ORE"]
end

def find_max_fuel_for_ore(rules, ore)
  low, high = 0, ore
  pivot = low + ((high-low) / 2)

  while (pivot != high && pivot != low)
    case breakdown(rules, Value.new("FUEL", pivot)) <=> ore
    when  0 then break
    when  1 then high = pivot
    when -1 then low = pivot
    end

    pivot = low + ((high-low) / 2)
  end

  pivot
end

INPUT = Utils.cli_param_or_default(0,"day14/input.txt")
rules = parse_file(INPUT)

# part 1
puts "Part 1: %i" % breakdown(rules, Value.new("FUEL", 1))

# part 2
TRILLION=1_000_000_000_000
puts "Part 2: %i" % find_max_fuel_for_ore(rules, TRILLION)
