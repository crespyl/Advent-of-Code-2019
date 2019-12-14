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

# breakdown a value into the amount of ore necessary to produce it
def breakdown(rules, value)
  values = [value]

  produced = Hash.new(0)
  consumed = Hash.new(0)

  while ! values.empty? && ! values.all? { |v| v.resource == "ORE" }
    values = collapse_values(values)
    needed = values.shift
    reqs, extra = reqs_for_value(rules, needed)

    reqs.each do |req|
      available = produced[req.resource] - consumed[req.resource]
      if produced[req.resource] > 0 && produced[req.resource] >= consumed[req.resource]

        if available >= req.amount
          consumed[req.resource] += req.amount
          req.amount = 0
        elsif available > 0 && available < req.amount
          consumed[req.resource] += available
          req.amount -= available
        end
      end

      consumed[req.resource] += req.amount
    end

    produced[needed.resource] += needed.amount + extra

    values += reqs
  end

  return consumed["ORE"]
end

def find_max_fuel_for_ore(rules, ore)
  low, high = 0, ore
  pivot = low + ((high-low) / 2)

  while (pivot != high && pivot != low)
    case breakdown(rules, Value.new("FUEL", pivot)) <=> target
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
