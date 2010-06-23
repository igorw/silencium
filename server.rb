require 'bundler'

Bundler.setup

require 'eventmachine'
require 'em-websocket'
require 'json'

class Card
  attr_accessor :word
  attr_accessor :taboo_words
  
  def initialize(word, taboo_words)
    @word = word
    @taboo_words = taboo_words
  end
end

class User
  attr_accessor :ws
  attr_accessor :name
  attr_accessor :points
  
  def initialize(ws, name)
    @ws = ws
    @name = name
    @points = 0
  end
  
  def trigger_event(event)
    @ws.send Event.export(event)
  end
end

class Event
  attr_reader :name
  attr_reader :data
  
  def initialize(name, data = nil)
    @name = name.to_sym
    @data = !data.nil? ? data : {}
    
    # symbolize
    @data = @data.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo }
  end
  
  def to_s
    "#{@name.to_s} #{@data.to_s}"
  end
  
  def self.import(raw_event)
    parsed_event = JSON.parse(raw_event);
    Event.new(parsed_event[0], parsed_event[1])
  end
  
  def self.export(event)
    [event.name.to_s, event.data].to_json
  end
end

class SilenciumServer
  def initialize
    @ws_channel = EM::Channel.new
    @cards = [
      Card.new('car', ['wheels', 'mercedes']),
      Card.new('github', ['git', 'hub']),
      Card.new('hell', ['god', 'satan', 'demon']),
    ]
    @old_cards = []
    @users = []
  end
  
  def init_ws(options)
    EM::WebSocket.start(options) do |ws|
      ws.onopen {
        # outgoing message
        sid = @ws_channel.subscribe do |event|
          trigger_event ws, event
        end
        
        # client disconnect
        ws.onclose {
          @ws_channel.unsubscribe sid
          client_disconnect ws, sid
        }
        
        # incoming message
        ws.onmessage { |raw_event|
          event = Event.import(raw_event)
          receive_event ws, event
        }
        
        client_connect ws, sid
      }
    end
  end
  
  def client_connect(ws, sid)
    log "Client connected: #{sid}"
    
    trigger_event ws, Event.new(:connect)
  end
  
  def client_disconnect(ws, sid)
    log "Client disconnected: #{sid}"
    
    remove_user ws
    user_count_changed :leave
  end
  
  def trigger_event(ws, event)
    ws.send Event.export(event)
  end
  
  def trigger_global_event(event)
    @users.each do |user|
      user.trigger_event event
    end
    
    log "Trigger global event: " + event.to_s
  end
  
  def receive_event(ws, event)
    log "Received event: #{event.to_s}"
    
    if event.name != :join && find_user(ws).nil?
      log "Event from non-joined user (ws: #{ws})"
    end
    
    case event.name
      when :join then
        error = false
        if event.data[:username].empty?
          error = "No username given"
        elsif find_user_name(event.data[:username])
          error = "Username already taken"
        end
        
        if error
          trigger_event ws, Event.new(:join, {accepted: false, message: error})
        else
          @users << User.new(ws, event.data[:username])
          trigger_event ws, Event.new(:join, accepted: true)
          trigger_event ws, Event.new(:debug, message: "joined game")
          user_count_changed :join
        end
      when :guess then
        trigger_global_event Event.new(:guess, {username: find_user(ws).name, word: event.data[:word]})
      when :give then
        trigger_global_event Event.new(:give, {username: find_user(ws).name, hint: event.data[:hint]})
    end
  end
  
  # called whenever a user joins or leaves
  # status is :join or :leave
  def user_count_changed(status = :join)
    # trigger user event
    trigger_global_event Event.new(:users, users: @users.map {|user| {name: user.name, giver: is_giver?(user)} })
    
    # set up giver
    if @users.size > 0
      @users.first.trigger_event Event.new(:become_giver)
    end
    
    # check if more than one user is playing
    if @users.size == 1
      # only one guy left
      trigger_global_event Event.new(:pause)
    elsif @users.size == 2 && status == :join
      # second user joined, game can continue
      trigger_global_event Event.new(:unpause)
    end
  end
  
  def log(message)
    puts "[#{Time.new.strftime("%H:%M:%S")}] #{message}"
  end
  
  def find_user(ws)
    @users.each do |user|
      if ws === user.ws
        return user
      end
    end
  end
  
  def find_user_name(name)
    @users.each do |user|
      if name === user.name
        return user
      end
    end
    
    nil
  end
  
  def remove_user(ws)
    user = find_user(ws)
    @users.delete user
  end
  
  def is_giver?(user)
    user === @users.first
  end
  
  def next_round
    # first user becomes last
    @users << @users.shift
    
    @users.first.trigger_event Event.new(:become_giver)
    @users.last.trigger_event Event.new(:become_player)
  end
end

EM.run {
  @server = SilenciumServer.new
  @server.init_ws host: "0.0.0.0", port: 3001
}
