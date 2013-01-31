#!/usr/bin/env ruby

require 'bundler/setup'
require 'gaminator'
require 'set'


LOG = File.open("log.txt","w")

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

  def pixels
    Set.new(self.texture.map.with_index{|r,ri|
      r.each_char.map.with_index{|c,ci| [(@x+ci).round,(@y+ri).round]}}.flatten(1))
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
      context.remove_entity(self)
    end
  end

  def colliding_pixels(entity)
    LOG.puts(self.pixels.inspect)
    self.pixels & entity.pixels
  end

  def collide?(entity)
    !colliding_pixels(entity).empty?
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
    context.add_entity(Shoot.new(@x+7,@y,"shoot",:red))
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

  def collide?(entity)
    false
  end
end

class Boom
  attr_accessor :x,:y
  def initialize(x,y)
    @x, @y = x, y
    @char = "x"
  end

  def char
    @char
  end

  def color
    Curses::COLOR_YELLOW
  end

  def update(context)
    @char = @char == "x" ? " " : "x"
  end

  def collide?(car)
    false
  end
end

class Cloud < StaticEntity
  def update(context)
    @x -= 1
    if @x + @width < 2
      @x = context.width
    end
  end
end

class CarGame
  attr_reader :width, :height

  def initialize(width, height)
    @ticks = 0
    @width = width
    @height = height
    @car = Car.new(10, 10)
    x_offset = 0
    @entities = [
      Road.new(@width,@height),
      File.read("data/track.txt").split("\n").map do |line|
        type,x_delta = line.split(",")
        x_offset += x_delta.to_i
        case type
        when "bomb"
          Bomb.new(x_offset,2,type,:yellow)
        when "hole", "small_hole"
          StaticEntity.new(x_offset,@height-4,type,:red)
        when "wall", "tree","finish"
          StaticEntity.new(x_offset,@height-6,type,:red)
        when "house"
          StaticEntity.new(x_offset,@height-7,type,:red)
        when /cloud/
          color =
            if type =~ /(2|4)$/
              :blue
            else
              :cyan
            end
          Cloud.new(x_offset,(rand*10).round,type,color)
        end
      end,
      @car
    ].flatten
    @distance = 0
    @entity_distance = 30
    @state = :running
    @collision = []
    @bombs = @entities.select{|e| Bomb === e }
    @sleep_time = 0.04
    @counter = 0
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
    @running = false
    Kernel.exit
  end

  def tick
    case @state
    when :running
      @entities.each{|e| e.update(self) }
      @bombs.each do |bomb|
        @entities.select{|e| Shoot === e }.each do |shoot|
          if bomb.collide?(shoot)
            remove_entity(bomb)
            remove_entity(shoot)
          end
        end
      end
      @entities.each do |entity|
        next if entity == @car
        if entity.collide?(@car)
          entity.colliding_pixels(@car).each do |x,y|
            @entities << Boom.new(x,y)
            @collision << @entities.last
          end
          @state = :end
          @sleep_time = 0.2
          break
        end
      end
      @counter += 1
      @distance += 0.1
    when :end
      @collision.each{|c| c.update(self) }
    end
  end

  def exit_message
    puts "You're dead ;(. %dm" % @distance
  end

  def textbox_content
    "Your distance: %dm" % @distance
  end

  def sleep_time
    @sleep_time
  end
end

Gaminator::Runner.new(CarGame).run
