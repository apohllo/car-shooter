#!/usr/bin/env ruby

require 'colors'
require_relative 'game_runner'

class Entity
  attr_accessor :x, :y, :texture, :color, :colors
  COLOR_MAP = {
    :white => Curses::COLOR_WHITE,
    :red => Curses::COLOR_RED,
    :blue => Curses::COLOR_BLUE,
    :green => Curses::COLOR_GREEN,
    :cyan => Curses::COLOR_CYAN,
    :magenta => Curses::COLOR_MAGENTA,
    :yellow => Curses::COLOR_YELLOW
  }
  SHORT_COLOR_MAP = Hash[COLOR_MAP.map{|k,v| [k.to_s[0],v]}]

  PATH = "data/"
  TEXTURE_EXT = ".txt"
  COLORS_EXT = ".col"

  def initialize(x,y,texture,color)
    @x, @y = x, y
    @texture = File.read(PATH + texture + TEXTURE_EXT).split("\n")
    if File.exist?(PATH + texture + COLORS_EXT)
      @colors = File.read(PATH + texture + COLORS_EXT).split("\n").
        map{|r| r.each_char.map{|c| SHORT_COLOR_MAP[c] || Curses::COLOR_WHITE } }
      @color = COLOR_MAP[color]
    else
      @color = COLOR_MAP[color]
    end
  end
end

class StaticEntity < Entity
  def initialize(x,y,texture_path,color=:white)
    super
    @width = self.texture.max{|l| l.size}.size
    @height = self.texture.size
  end

  def update(context)
    @x -= 1
    if @x + @width < 2
      @x = context.width
    end
  end
end

class Bomb < StaticEntity
  def update(context)
    super
    @y += 0.7
    if @y + @height > context.height - 3
      @y = 1
    end
  end
end

class Shoot < StaticEntity
  def update(context)
    @x += 2
    if @x >= context.width - 1
      context.remove_entity(self)
    end
  end
end

class Car < Entity
  def initialize(x,y)
    super(x,y,"car",:magenta)
    @counter = 0
    @y_vector = 0
    @height = 6
  end

  def update(context)
    if @y_vector > 0
      argument = @counter / 5.0
      @y = (context.height - @height + 1.5*(argument ** 2 - 4 * argument)).round
      if argument == 4
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
  end

  def go_up
    @y_vector = 3
  end

  def go_down
  end

  def shoot(context)
    context.add_entity(Shoot.new(@x+5,@y,"shoot",:red))
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
      StaticEntity.new(50,@height-6,"tree",:green),
      StaticEntity.new(90,@height-6,"wall",:yellow),
      StaticEntity.new(20,@height-3,"hole",:red),
      StaticEntity.new(10,@height-3,"small_hole",:red),
      StaticEntity.new(5,5,"cloud1",:blue),
      StaticEntity.new(50,3,"cloud2",:cyan),
      StaticEntity.new(70,6,"cloud3",:blue),
      StaticEntity.new(100,8,"cloud4",:cyan),
      Bomb.new(110,1,"bomb",:yellow),
      @car
    ]
    @distance = 0
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
      ' ' => :shoot,
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

  def shoot
    @car.shoot(self)
  end

  def add_entity(entity)
    @entities[-2...-2] = entity
  end

  def remove_entity(entity)
    @entities.delete(entity)
  end

  def exit
    Kernel.exit
  end

  def tick
    @entities.each{|e| e.update(self) }
    @distance += 0.1
  end

  def exit_message
    puts "You're dead ;(."
  end

  def textbox_content
    "Your distance: %dm" % @distance
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
