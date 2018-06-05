class Account < ActiveRecord::Base
  KNOWN_SERVICES = {
    'geocaching.com' => MyGc::GeocachingCom
  }
  LIST_FORMAT = "%5s | %18s | %30s\n"

  has_many :logs

  validates :service, :username, :password, presence: { allow_blank: false }
  validates :service, inclusion: KNOWN_SERVICES.keys

  # Returns a list of all accounts formatted for printing to the screen
  def self.list
    result = sprintf(LIST_FORMAT, 'ID', 'Service', 'Username')
    result += LIST_FORMAT.gsub(' | ', '-+-').gsub(/%(\d+)[s]/){|f| '-' * f.gsub(/[^\d]/,'').to_i }
    result += self.all.map{|a| sprintf(LIST_FORMAT, a.id, a.service, a.username) }.join('')
  end

  # Returns a Service configured with this Account
  def to_service
    KNOWN_SERVICES[service].new(self)
  end
end
