class Card
  attr_accessor :word
  attr_accessor :taboo_words
  
  def initialize(word, taboo_words)
    @word = word
    @taboo_words = taboo_words
  end
end
