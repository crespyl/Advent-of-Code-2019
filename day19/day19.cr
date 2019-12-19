#!/usr/bin/env crystal

require "../lib/vm2.cr"
require "../lib/utils.cr"


prog = Utils.get_input_file(Utils.cli_param_or_default(0,"day19/input.txt"))
vm = VM2.from_string(prog)

hits = 0
(0...50).each do |x|
  (0...50).each do |y|
    hit = check_point(x,y,vm.clone)
    hits += hit

    if hit > 0
      print '#'
    else
      print '.'
    end
  end
  print '\n'
end

puts "Part 1: %i" % hits

# follow sw corner for simplicity
x,y = 0,50
while true
  while check_point(x,y,vm.clone) == 0
    x += 1
  end

  if check_point(x+99,y-99,vm.clone) > 0 &&
     check_point(x+99,y,vm.clone) > 0 &&
     check_point(x,y-99,vm.clone) > 0 &&
     check_point(x,y,vm.clone) > 0
    # puts "hit at #{x},#{y}"
    break
  end

  y += 1
end

# adjust to nw corner
puts "Part 2: %i" % [x*10000 + y-99]

def check_point(x,y,drone)
  drone.send_input(x)
  drone.send_input(y)
  drone.run
  return drone.read_output || 0
end
