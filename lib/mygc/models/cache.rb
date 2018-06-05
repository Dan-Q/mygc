class Cache < ActiveRecord::Base
  CACHE_TYPES = %w{traditional multi puzzle moving virtual webcam event mp3 guestbook unknown deaddrop bit letterbox challenge whereigo}
  LIST_FORMAT = "%6s | %14s | %10s | %50s | %12s\n"

  belongs_to :account
  has_many :logs

  validates :cache_type, inclusion: CACHE_TYPES

  # Returns a list of all caches formatted for printing to the screen
  def self.list
    result = sprintf(LIST_FORMAT, 'ID', 'Service', 'Code', 'Name', 'Type')
    result += LIST_FORMAT.gsub(' | ', '-+-').gsub(/%(\d+)[s]/){|f| '-' * f.gsub(/[^\d]/,'').to_i }
    result += self.all.map{|c| sprintf(LIST_FORMAT, c.id, c.code, c.name, c.cache_type) }.join('')
  end

  # Returns true if this cache's record is stale or incomplete, false otherwise
  def needs_updating?
    return true if new_record?
    false
  end
end
