#!/usr/bin/env crystal

require "../lib/utils.cr"

input = Utils.get_input_file(Utils.cli_param_or_default(0,"day22/input.txt"))

# Part 1
d = make_deck(10007)

input.lines.each_with_index do |line, idx|
  command, arg = parse_command_args(line)

  case command
  when "deal into new stack" then d = deal_into_stack(d)
  when "cut" then d = cut_n_cards(d, arg)
  when "deal with increment" then d = deal_with_increment(d, arg)
  else raise "invalid command: #{command}"
  end
end

puts "Part 1: %i" % d.index(2019)

# Part 2
# d = make_deck(119315717514047)

# 101741582076661_i64.times do |n|
#   input.lines.each_with_index do |line, idx|
#     command, arg = parse_command_args(line)

#     case command
#     when "deal into new stack" then d = deal_into_stack(d)
#     when "cut" then d = cut_n_cards(d, arg)
#     when "deal with increment" then d = deal_with_increment(d, arg)
#     else raise "invalid command: #{command}"
#     end
#   end
# end

# puts "Part 2: %i" % d[2020]

def parse_command_args(line) : Tuple(String, Int64)
  pattern = /(deal into new stack|cut|deal with increment)(\s+(-?\d+))?/
  m = line.match(pattern) || raise "Couldn't match line! (#{line})"
  {m[1], m[3]? ? m[3].to_i64 : 0_i64}
end

alias Deck = Array(Int64)

def make_deck(n : Int64) : Deck
  (0_i64...n).to_a
end

def deal_into_stack(deck : Deck) : Deck
  new_deck = Deck.new

  while (card = deck.pop?)
    new_deck << card
  end

  return new_deck
end

def cut_n_cards(deck : Deck, n : Int64) : Deck
  return deck[n...] + deck[...n]
end

def deal_with_increment(deck : Deck, n : Int64) : Deck
  new_deck = Deck.new(deck.size, -1)
  idx = 0
  deal_idx = 0

  while (deal_idx < deck.size)
    new_deck[idx] = deck[deal_idx]
    deal_idx += 1
    idx = (idx + n) % deck.size
  end

  return new_deck
end
