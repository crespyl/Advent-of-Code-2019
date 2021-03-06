#!/usr/bin/env crystal
require "../lib/utils.cr"

struct Val
  def initialize(@resource : String, @amount : Int64)
  end

  def resource() @resource end
  def amount() @amount end
  def amount=(v : Int64) @amount=v end
end

class Rule
  property output : Val
  property requirements : Array(Val)

  def initialize(@requirements, @output) end

  def to_s
    "%s => %s" % [@requirements.map(&:to_s).join(", "), @output]
  end
end

def parse_value(str)
  m = str.match(/(\d+)\s+(\w+)/)
  if m && m.size >= 3
    Val.new(m[2],m[1].to_i64)
  else
    raise "could not parse value from '#{str}'"
  end
end

def parse_rule(str)
  reqs, output = str.split(" => ")
  reqs = reqs.split(", ").map{ |s| parse_value(s) }

  output = parse_value(output)

  Rule.new(reqs, output)
end

def parse_file(filename)
  File.read(filename)
    .lines
    .map(&.chomp)
    .map { |line| parse_rule(line) }
    .each_with_object({} of String => Rule) { |rule, hash| hash[rule.output.resource] = rule }
end

# take a list that might contain several values with the same resource and fold
# them into one value for each resource
def collapse_values(values)
  values.each_with_object(Hash(String, Int64).new(0)) { |v,h|
    h[v.resource] += v.amount
  }.map { |k,v| Val.new(k,v) }
end

# get the requirements necessary to produce the requested value
def reqs_for_value(rules, value) : Tuple(Array(Val), Int64)
  rule = rules[value.resource]?
  return {[] of Val,0_i64}  unless rule && value.amount > 0

  reqs = rule.requirements.map { |v| Val.new(v.resource, v.amount) }
  excess = 0_i64

  if rule.output.amount >= value.amount
    # one application of this rule is enough
    excess = rule.output.amount - value.amount
  else
    # we need a multiple of the values
    extras = (value.amount // rule.output.amount) + (value.amount % rule.output.amount == 0 ? 0 : 1)
    reqs = reqs.map { |req| Val.new(req.resource, req.amount * extras) }
    excess = (rule.output.amount * extras) - value.amount
  end
  {reqs, excess}
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

  produced = Hash(String, Int64).new(0)
  consumed = Hash(String, Int64).new(0)

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
  low, high = 0_i64, ore
  pivot = low + ((high-low) // 2_i64)

  while (pivot != high && pivot != low)
    case breakdown(rules, Val.new("FUEL", pivot)) <=> ore
    when  0 then break
    when  1 then high = pivot
    when -1 then low = pivot
    end

    pivot = low + ((high-low) // 2)
  end

  pivot
end

INPUT = Utils.cli_param_or_default(0,"day14/input.txt")
rules = parse_file(INPUT)

# part 1
puts "Part 1: %i" % breakdown(rules, Val.new("FUEL", 1))

# part 2
TRILLION=1_000_000_000_000
puts "Part 2: %i" % find_max_fuel_for_ore(rules, TRILLION)
