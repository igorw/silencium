module Silencium
  module ServerBase
    def init_ws(options)
      @ws_channel = EM::Channel.new
      
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
          
          ws.onerror { |e|
            raise e
          }
          
          client_connect ws, sid
        }
      end
    end
    
    def init_mq(queue, options)
      @mq_queue = queue
      Warren::Queue.connection = options
      
      Warren::Queue.subscribe(@mq_queue) do |event|
        receive_mq_event event
      end
    end
    
    def trigger_event(ws, event)
      ws.send Event.export(event)
    end
  
    def trigger_mq_event(event)
      Warren::Queue.publish(@mq_queue, event)
    end
    
    def log(message)
      puts "[#{Time.new.strftime("%H:%M:%S")}] #{message}"
    end
  end
end
