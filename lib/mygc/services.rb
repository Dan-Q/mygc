require 'selenium-webdriver'
# CHROME_ARGS = %w{disable-gpu incognito disable-infobars no-sandbox headless}
CHROME_ARGS = %w{disable-gpu incognito disable-infobars no-sandbox}
# CHROME_BINARY = "/usr/bin/google-chrome"
CHROME_BINARY = "/usr/bin/chromium"

Selenium::WebDriver::Chrome.path = CHROME_BINARY

module MyGc
  class GeocachingService
    attr_accessor :account, :chrome

    WAIT_TIME = (1.5...2.5) # seconds to wait between transactions so as to be polite and not abuse services or trigger rate-limiting, expressed as a range

    def initialize(account)
      launch_chrome
      @account = account
    end

    # Waits e.g. between transactions so as not to hammer/abuse service; uses an approximate normal distribution when deciding how long to wait
    def wait
      mean = (WAIT_TIME.first + WAIT_TIME.last) / 2
      devi = (WAIT_TIME.last - WAIT_TIME.first) / 4
      theta = 2 * Math::PI * rand
      rho = Math.sqrt(-2 * Math.log(1 - rand))
      scale = devi * rho
      duration = mean + scale * Math.cos(theta)
      sleep(duration)
    end

    protected

    # Launches an instance of Headless Chrome and connects to it
    # Raises an error if unable
    def launch_chrome
      @chrome = Selenium::WebDriver.for(:chrome, options: Selenium::WebDriver::Chrome::Options.new(args: CHROME_ARGS))
    end

    # Sets the value of a field in Chrome; working around the (older) ChomeWebdriver issue of not being able to call .send_keys
    # without a working virtual X server (https://github.com/Automattic/wp-e2e-tests/issues/515#issuecomment-301165065)
    # Field can be expressed as a (CSS) string rather than an element
    def set_field_value(field, value)
      field = @chrome.find_element(css: field) if field.is_a?(String)
      begin
        @chrome.execute_script("arguments[0].value='#{value.gsub("'", "\\\\'")}'", field)
      rescue Selenium::WebDriver::Error::UnknownError
        # Selenium sometimes throws this but it's harmless
      end
    end
  end
end

require 'mygc/services/geocaching_com'
