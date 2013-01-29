#!/usr/bin/env ruby

require 'colors'

class Entity
  attr_reader :x_offset, :y_offset, :texture

  def initialize(x_offset,y_offset,texture_path)
    @x_offset = x_offset
    @y_offset = y_offset
    @texture = File.read(texture_path).split("\n")
  end
end

class StaticEntity < Entity
  def initialize(x_offset,y_offset,texture_path)
    super
    @width = self.texture.max{|l| l.size}.size
  end

  def update(context)
    @x_offset -= 1
    if @x_offset + @width < 0
      @x_offset = context.first.size
    end
  end
end

class Car < Entity
  def initialize(x_offset,y_offset)
    super(x_offset,y_offset,"data/car.txt")
    @counter = 0
  end

  def update(context)
    @y_offset = context.size - 14 + (((@counter/2.0) %10-5)**2/3.0).round
    @texture[2][1] = @texture[2][1] == "x" ? "+" : "x"
    @texture[2][5] = @texture[2][5] == "x" ? "+" : "x"
    @counter += 1
  end
end

LINES = 3
COLOR_MAP = {
  /\(|\)|@/ => :green,
  /#/ => :yellow,
  /-|\\|\// => :bold,
  /=/ => :blue,
  /\*/ => :blue,
  /%/ => :yellow_bg
}

def paint(chars)
  (chars || []).map do |char|
    _,color = COLOR_MAP.find{|k,v| char =~ k }
    color ? char.hl(color) : char
  end.join("")
end

def display(view)
  view.each.with_index do |row,row_index|
    puts paint(row)
  end
  print "[#{view.size}A"
end

def draw(screen,entity)
  if Array === entity
    texture = entity
    bottom_offset = 0
    left_offset = 0
  else
    texture = entity.texture
    bottom_offset = entity.y_offset
    left_offset = entity.x_offset
  end
  texture.each.with_index do |row,row_index|
    row.each_char.with_index do |pixel,pixel_index|
      next if pixel_index + left_offset >= screen.first.size
      next if pixel_index + left_offset < 0
      screen[row_index+bottom_offset][pixel_index+left_offset] = pixel
    end
  end
end

road = File.read("data/road.txt").split("\n")
entities = [
  StaticEntity.new(50,28,"data/tree.txt"),
  StaticEntity.new(90,28,"data/wall.txt"),
  StaticEntity.new(20,31,"data/hole.txt"),
  StaticEntity.new(10,31,"data/small_hole.txt"),
  StaticEntity.new(5,5,"data/cloud1.txt"),
  StaticEntity.new(50,10,"data/cloud2.txt"),
  StaticEntity.new(70,15,"data/cloud3.txt"),
  StaticEntity.new(100,7,"data/cloud4.txt"),
]

car = Car.new(4,3)

length = road.max{|l| l.size}.size
height = road.size
screen = Array.new(height){Array.new(length," ")}

draw(screen,road)

system("clear")
offset = 0
loop do
  begin
    view = []
    screen.each do |row|
      view << (row[offset..screen.first.size] || []) + (row[0...[offset-1,0].max] || [])
    end
    entities.each{|e| draw(view,e)}
    draw(view,car)
    display(view)

    entities.each{|e| e.update(view)}
    car.update(view)

    sleep(0.05)
    offset += 1
    offset %= view.first.size
  rescue Interrupt
    #system('clear')
    puts
    break
  end
end
