require 'eventmachine'
require './em-websocket/lib/em-websocket'
require 'json'

class Card
  attr_accessor :word
  attr_accessor :taboo_words
end

class User
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
    trigger_event ws, Event.new(:connect)
    
    log "Client connected: #{sid}"
  end
  
  def client_disconnect(ws, sid)
    log "Client disconnected: #{sid}"
  end
  
  def trigger_event(ws, event)
    ws.send Event.export(event)
  end
  
  def trigger_global_event(event)
    @ws_channel.push event
    
    log "Trigger global event: " + event.to_s
  end
  
  def receive_event(ws, event)
    log "Received event: #{event.name}"
    
    case event.name
      when :join then
        if event.data[:username].empty?
          trigger_event ws, Event.new(:join, {accepted: false, message: "No username given"})
        else
          @users << User.new(ws, event.data[:username])
          trigger_event ws, Event.new(:join, {accepted: true})
          trigger_event ws, Event.new(:debug, message: "joined game")
        end
    end
  end
  
  private
  
  def log(message)
    puts [Time.new, message]
  end
end

EM.run {
  @server = SilenciumServer.new
  @server.init_ws :host => "0.0.0.0", :port => 3001
}
