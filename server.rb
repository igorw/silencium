require 'eventmachine'
require './em-websocket/lib/em-websocket'
require 'json'

class Card
  attr_accessor :word
  attr_accessor :taboo_words
end

class User
  attr_accessor :ws
  attr_accessor :name
  attr_accessor :cards
  
  def initialize(ws, name)
    @ws = ws
    @name = name
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
    @games = []
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
    trigger_event_users
  end
  
  def trigger_event(ws, event)
    ws.send Event.export(event)
  end
  
  def trigger_global_event(event)
    @ws_channel.push event
    
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
          trigger_event_users
          trigger_event ws, Event.new(:debug, message: "joined game")
        end
      when :guess then
        trigger_global_event Event.new(:guess, {username: find_user(ws).name, word: event.data[:word]})
    end
  end
  
  def trigger_event_users
    trigger_global_event Event.new(:users, users: @users.map { |user| user.name })
  end
  
  private
  
  def log(message)
    puts [Time.new, message]
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
end

EM.run {
  @server = SilenciumServer.new
  @server.init_ws :host => "0.0.0.0", :port => 3001
}
