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
  
  def initialize(ws)
    @ws = ws
  end
  
  def trigger_event(event)
    @ws.send Event.export(event)
  end
end

class Event
  attr_accessor :name
  attr_accessor :data
  
  def initialize(name = nil, data = nil)
      @name = name
      @data = !data.nil? ? data : {}
  end
  
  def self.import(raw_event)
    parsed_event = JSON.parse(raw_event);
    
    event = Event.new
    event.name = parsed_event[0].to_sym
    event.data = parsed_event[1]
    
    event
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
    
    puts [Time.new, "Client connected: #{sid}"]
  end
  
  def client_disconnect(ws, sid)
    puts [Time.new, "Client disconnected: #{sid}"]
  end
  
  def trigger_event(ws, event)
    ws.send Event.export(event)
  end
  
  def trigger_global_event(event)
    @ws_channel.push event
    
    puts [Time.new, "Trigger global event: " + event.to_s]
  end
  
  def receive_event(ws, event)
    puts [Time.new, "Received event: #{event.name}"]
    
    case event.name
      when :join then
        @users << User.new(ws)
        trigger_event ws, Event.new(:join)
        trigger_event ws, Event.new(:debug, message: "something")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
        trigger_event ws, Event.new(:debug, message: "something else")
    end
  end
end

EM.run {
  @server = SilenciumServer.new
  @server.init_ws :host => "0.0.0.0", :port => 3001
}
