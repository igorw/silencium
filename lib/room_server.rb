module Silencium
  class RoomServer
    include ServerBase
    
    def initialize
      @rooms = {}
    
      EM::PeriodicTimer.new(10) do
        trigger_global_event rooms_event
      end
    
      EM::PeriodicTimer.new(3) do
        clean
      end
    end
  
    def client_connect(ws, sid)
      trigger_event ws, rooms_event
    
      log "Client connected: #{sid}"
    end
  
    def client_disconnect(ws, sid)
      log "Client disconnected: #{sid}"
    end
  
    def trigger_global_event(event)
      @ws_channel.push event
    
      log "Trigger global event: " + event.to_s
    end
  
    def receive_mq_event(event)
      log "Reveived mq event: #{event.to_s}"
    
      case event.name
        when :room_broadcast then
          if @rooms[event.data[:name]].nil?
            @rooms[event.data[:name]] = Room.new(event.data[:name], event.data[:port], event.data[:users])
          else
            @rooms[event.data[:name]].alive
            @rooms[event.data[:name]].update(event.data[:users])
          end
      end
    end
  
    # remove dead rooms
    # rooms must broadcast all 10 seconds
    def clean
      @rooms.values.each do |room|
        if room.updated < Time.new - 10
          @rooms.delete room.name
        end
      end
    end
  
    def rooms_event
      Event.new(:rooms, rooms: @rooms.values.map { |room| {name: room.name, port: room.port, users: room.users} })
    end
  end
end
