#!/usr/bin/env crystal

struct Vec3
  property x : Int32
  property y : Int32
  property z : Int32

  def initialize
    @x, @y, @z = 0,0,0
  end

  def initialize(x,y,z)
    @x = x
    @y = y
    @z = z
  end

  def to_s
    "(%i,%i,%i)" % [@x,@y,@z]
  end

  def reduce(init, &block)
    state = init
    state = yield state, @x
    state = yield state, @y
    state = yield state, @z
    return state
  end

  def []=(i : Int, val : Int32)
    case i
    when 0 then @x = val
    when 1 then @y = val
    when 2 then @z = val
    else raise "Bad index into Vec3"
    end
  end

  def [](i : Int)
    case i
    when 0 then @x
    when 1 then @y
    when 2 then @z
    else raise "Bad index into Vec3"
    end
  end

  def +(v : Vec3)
    Vec3.new(@x + v.x, @y + v.y, @z + v.z)
  end
  def -(v : Vec3)
    Vec3.new(@x - v.x, @y - v.y, @z - v.z)
  end
  def *(v : Vec3)
    Vec3.new(@x * v.x, @y * v.y, @z * v.z)
  end
end


class Moon
  property pos : Vec3
  property vel : Vec3
  property name : String

  def_hash @name, @pos, @vel

  def initialize(name, pos, vel)
    @name = name
    @pos = pos
    @vel = vel
  end

  def initialize(name : String, pos : Vec3)
    @name = name
    @pos = pos
    @vel = Vec3.new
  end

  def move
    @pos = @pos + @vel
  end

  def energy
    pot = @pos.reduce(0) { |sum, v| sum+(v.abs) }
    kin = @vel.reduce(0) { |sum, v| sum+(v.abs) }
    pot * kin
  end

  def to_s
    "%s: pos %s vel %s" % [@name, @pos.to_s, @vel.to_s]
  end

  def clone
    Moon.new(@name, @pos, @vel)
  end

end

def apply_gravity(a : Moon, b : Moon)
  (0..2).each do |axis|
    if a.pos[axis] < b.pos[axis]
      a.vel[axis] = a.vel[axis] + 1
      b.vel[axis] = b.vel[axis] - 1
    elsif a.pos[axis] > b.pos[axis]
      a.vel[axis] = a.vel[axis] - 1
      b.vel[axis] = b.vel[axis] + 1
    end
  end
end

def step(moons)
  moons.permutations(2).map{ |pair| pair.to_set }.to_set.each do |pair|
    a, b = pair.to_a
    apply_gravity(a, b)
  end
  moons.each { |m| m.move }
end

def find_cycle(moons : Array(Moon), axis : Int32) : Int64
  start = moons.map { |m| {m.pos[axis], m.vel[axis]} }
  n = 1_i64
  step(moons)
  while moons.map{ |m| {m.pos[axis], m.vel[axis]} } != start
    n += 1
    step(moons)
  end
  return n
end

# Part 1

moons = [] of Moon
moons << Moon.new("a", Vec3.new(6,10,10))
moons << Moon.new("b", Vec3.new(-9,3,17))
moons << Moon.new("c", Vec3.new(9,-4,14))
moons << Moon.new("d", Vec3.new(4,14,4))

1000.times do |i|
  step(moons)
  #puts "after #{i+1} steps:"
  #moons.each { |m| puts m.to_s }
end

puts "Part 1:"
moons.each { |m| puts m.to_s }
puts "system_e: %i" % moons.reduce(0) { |sum,m| sum + m.energy }

# Part 2

moons = [] of Moon

#test
# moons << Moon.new("a", Vec3.new(-8,-10,0))
# moons << Moon.new("b", Vec3.new(5,5,10))
# moons << Moon.new("c", Vec3.new(2,-7,3))
# moons << Moon.new("d", Vec3.new(9,-8,-3))

#input
moons << Moon.new("a", Vec3.new(6,10,10))
moons << Moon.new("b", Vec3.new(-9,3,17))
moons << Moon.new("c", Vec3.new(9,-4,14))
moons << Moon.new("d", Vec3.new(4,14,4))

moons.each { |m| puts m.to_s }

cycle_x = find_cycle(moons.clone, 0)
cycle_y = find_cycle(moons.clone, 1)
cycle_z = find_cycle(moons.clone, 2)

puts "%i, %i, %i" % [cycle_x, cycle_y, cycle_z]
puts cycle_x.lcm(cycle_y.lcm(cycle_z))
