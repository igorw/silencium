class Event
  attr_reader :name
  attr_reader :data
  
  def initialize(name, data = nil)
    @name = name.to_sym
    @data = !data.nil? ? data : {}
    
    # symbolize
    @data = recursive_symbolize_keys @data
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
  
  # def self.import_mq(raw_event)
  #   parsed_event = Marshal.load(raw_event);
  #   Event.new(parsed_event[0], parsed_event[1])
  # end
  # 
  # def self.export_mq(event)
  #   Marshal.dump([event.name, event.data])
  # end
  
  def recursive_symbolize_keys hash
    if !hash.is_a?(Hash)
      return hash
    end
    
    new_hash = {}
    hash.each_pair do |key, value|
      new_hash[key.to_sym] = recursive_symbolize_keys(value)
    end
    new_hash
  end
end
