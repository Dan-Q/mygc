class Log < ActiveRecord::Base
  LOG_TYPES = %w{found dnf note admin will-attend attended}
  LIST_FORMAT = "%6s | %10s | %8s | %11s\n"

  belongs_to :account
  belongs_to :cache

  validates :log_type, inclusion: LOG_TYPES

  # Returns a list of all logs formatted for printing to the screen
  def self.list
    result = sprintf(LIST_FORMAT, 'ID', 'Date', 'Cache ID', 'Type')
    result += LIST_FORMAT.gsub(' | ', '-+-').gsub(/%(\d+)[s]/){|f| '-' * f.gsub(/[^\d]/,'').to_i }
    result += self.all.map{|l| sprintf(LIST_FORMAT, l.id, l.date, l.cache_id, l.log_type) }.join('')
  end

  # Returns true if this log record is stale or incomplete, false otherwise
  def needs_updating?
    return true if new_record?
    false
  end
end
