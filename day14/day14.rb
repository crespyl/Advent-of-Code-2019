#!/usr/bin/env ruby

require_relative "../lib/utils.rb"

INPUT = Utils.cli_param_or_default(0,"sample.txt")

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

rules = parse_file(INPUT)
puts "GOT RULES:"
puts rules.map { |k,v| "%s: %s" % [k.to_s, v.to_s] }

# take a list that might contain several values with the same resource and fold
# them into one value for each resource
def collapse_values(values)
  values.each_with_object(Hash.new { |h,k| h[k] = 0 }) { |v,h|
    h[v.resource] += v.amount
  }.map { |k,v| Value.new(k,v) }
end

# value indicates a specific number of a specific resource
def reqs_for_value(rules, value)
  #puts "FINDING %s" % value.to_s
  rule = rules[value.resource]
  return [[],0]  unless rule && value.amount > 0
 
  reqs = rule.requirements.map { |v| Value.new(v.resource, v.amount) }
  excess = 0
  # puts rule.to_s
  # puts value.to_s

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

# take 2
def breakdown(rules, values)

  produced = Hash.new(0)
  consumed = Hash.new(0)

  puts "==== breakdown start ===="
  puts produced
  puts consumed
  puts values
  puts rules

  while ! values.empty? && ! values.all? { |v| v.resource == "ORE" }
    values = collapse_values(values)
   
    puts "==== step ===="
    puts values.map { |v| v.to_s }
    puts "--------------"

    needed = values.shift

    reqs, extra = reqs_for_value(rules, needed)

    reqs.each do |req|
      available = produced[req.resource] - consumed[req.resource]
      puts "> #{available}/#{req.amount} #{req.resource} AVAILABLE"
      # check if we have some available already
      if produced[req.resource] > 0 && produced[req.resource] >= consumed[req.resource]

        if available >= req.amount
          puts "> CONSUMED SOME AVAILABLE #{req.to_s}"
          consumed[req.resource] += req.amount
          req.amount = 0
        elsif available > 0 && available < req.amount
          puts "> CONSUMED #{available} AVAILABLE #{req.resource}"
          consumed[req.resource] += available
          req.amount -= available
        end
      end

      consumed[req.resource] += req.amount
      puts "> CONSUMED [#{consumed[req.resource]}] +#{req.to_s}"
    end

    produced[needed.resource] += needed.amount + extra
    puts "> PRODUCED [#{produced[needed.resource]}] +#{needed.amount+extra} (#{needed.amount} + #{extra}) #{needed.resource}"

    values += reqs
  end

  puts collapse_values(values).map { |v| v.to_s }
  puts " >%s< " % consumed["ORE"]
  return [consumed, produced]
end
