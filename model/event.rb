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
