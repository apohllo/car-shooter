#!/usr/bin/env ruby

require 'colors'
require_relative 'game_runner'

class Entity
  attr_accessor :x, :y, :texture, :color
  COLOR_MAP = {
    :white => Curses::COLOR_WHITE,
    :red => Curses::COLOR_RED,
    :blue => Curses::COLOR_BLUE,
    :green => Curses::COLOR_GREEN,
    :cyan => Curses::COLOR_CYAN,
    :magenta => Curses::COLOR_MAGENTA,
    :yellow => Curses::COLOR_YELLOW
  }

  def initialize(x,y,texture_path,color)
    @x, @y = x, y
    @texture = File.read(texture_path).split("\n")
    @color = COLOR_MAP[color]
  end
end

class StaticEntity < Entity
  def initialize(x,y,texture_path,color=:white)
    super
    @width = self.texture.max{|l| l.size}.size
  end

  def update(context)
    @x -= 1
    if @x + @width < 2
      @x = context.width
    end
  end
end

class Car < Entity
  def initialize(x,y)
    super(x,y,"data/car.txt",:magenta)
    @counter = 0
    @y_vector = 0
    @height = 6
  end

  def update(context)
    if @y_vector > 0
      offset = @y_vector * 2
      @y = context.height - @height -
        (((@counter/5) % (offset * 2) - offset)**2/3.0).round
      if (@counter/5) % (offset * 2) - offset == 0 && @counter > 0
        @counter = 0
        @y_vector = 0
      else
        @counter += 1
      end
    else
      @y = context.height - @height
    end
    @texture[2][1] = @texture[2][1] == "x" ? "+" : "x"
    @texture[2][5] = @texture[2][5] == "x" ? "+" : "x"
    @texture[0][3] = @y_vector.to_s
  end

  def go_up
    @y_vector += 1 unless @y_vector >= 3
  end

  def go_down
    @y_vector -= 1 unless @y_vector <= 0
  end
end

class Road
  attr_reader :x,:y

  def initialize(width,height)
    @width, @height = width, height
    @x = 0
    @y = @height - 3
  end

  def update(context)
  end

  def color
    Curses::COLOR_RED
  end

  def texture
    ["-" * @width, "%" * @width, "%" * @width]
  end
end

class CarGame
  attr_reader :width, :height

  def initialize(width, height)
    @ticks = 0
    @width = width
    @height = height
    @car = Car.new(10, 10)
    @entities = [
      Road.new(@width,@height),
      StaticEntity.new(50,26,"data/tree.txt",:yellow),
      StaticEntity.new(90,26,"data/wall.txt",:yellow),
      StaticEntity.new(20,29,"data/hole.txt",:red),
      StaticEntity.new(10,29,"data/small_hole.txt",:red),
      StaticEntity.new(5,5,"data/cloud1.txt",:blue),
      StaticEntity.new(50,10,"data/cloud2.txt",:blue),
      StaticEntity.new(70,15,"data/cloud3.txt",:blue),
      StaticEntity.new(100,7,"data/cloud4.txt",:blue),
      @car
    ]
  end

  def objects
    @entities
  end

  def input_map
    {
      ?j => :move_left,
      ?l => :move_right,
      ?i => :move_up,
      ?k => :move_down,
      ?q => :exit,
    }
  end

  def move_left
    @car.x -= 1
  end

  def move_right
    @car.x += 1
  end

  def move_down
    @car.go_down
  end

  def move_up
    @car.go_up
  end

  def exit
    Kernel.exit
  end

  def tick
    @entities.each{|e| e.update(self) }
  end

  def exit_message
    puts "You're dead ;(."
  end

  def textbox_content
    "Your distance: %dm"
  end

  def sleep_time
    0.05
  end
end

GameRunner.new(CarGame).run

exit

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


def draw(screen,entity)
  if Array === entity
    texture = entity
    bottom_offset = 0
    left_offset = 0
  else
    texture = entity.texture
    bottom_offset = entity.y
    left_offset = entity.x
  end
  texture.each.with_index do |row,row_index|
    row.each_char.with_index do |pixel,pixel_index|
      next if pixel_index + left_offset >= screen.first.size
      next if pixel_index + left_offset < 0
      screen[row_index+bottom_offset][pixel_index+left_offset] = pixel
    end
  end
end
