module MyGc
  class GeocachingCom < GeocachingService
    NAME = 'geocaching.com'
    LOG_TYPE_MAPPINGS = {
      "Didn't find it"           => 'dnf',
      'Archive'                  => 'note',
      'Attended'                 => 'attended',
      'Enable Listing'           => 'note',
      'Found it'                 => 'found',
      'Needs Archived'           => 'note',
      'Needs Maintenance'        => 'note',
      'Owner Maintenance'        => 'note',
      'Post Reviewer Note'       => 'admin',
      'Submit for Review'        => 'admin',
      'Will Attend'              => 'will-attend',
      'Write note'               => 'note'
    }
    CACHE_TYPE_MAPPINGS = {
      'Traditional Geocache'     => 'traditional',
      'Project APE Cache'        => 'traditional',
      'Mystery Cache'            => 'unknown',
      'Multi-cache'              => 'multi',
      'Virtual Cache'            => 'virtual',
      'EarthCache'               => 'virtual',
      'Wherigo Cache'            => 'whereigo',
      'Event Cache'              => 'event',
      'Cache In Trash Out Event' => 'event',
      'Letterbox Hybrid'         => 'letterbox',
      'Geocaching HQ'            => 'traditional'
    }

    # Convenience function to convert Geocaching.com-style GPS coordinates (heading, degrees, decimal minutes), e.g.
    # "N 52° 23.862 W 004° 01.972" into decimal degree array (with heading implied by sign) e.g. [52.3977, -4.032866666666667]
    def deg_min_to_dec_deg(in_coords)
      lath, latd, latm, lngh, lngd, lngm = in_coords.match(/([NS]) *(\d+)[° ]+([\d.]+)'? +([EW]) *(\d+)[° ]+([\d.]+)'?/).to_a[1..-1]
      lat = (latd.to_i + (latm.to_f / 60)) * (lath.upcase == 'S' ? -1 : 1)
      lng = (lngd.to_i + (lngm.to_f / 60)) * (lngh.upcase == 'W' ? -1 : 1)
      [lat.round(5), lng.round(5)]
    end

    # Logs in to geocaching.com
    def log_in
      @chrome.get 'https://www.geocaching.com/account/login'
      set_field_value('#Username', @account.username)
      set_field_value('#Password', @account.password)
      @chrome.find_element(css: '#Login').click
    end

    # Logs out of geocaching.com, if logged-in
    def log_out
      @chrome.find_elements(css: 'form[action="/account/logout"]').first.submit
    end

    # Returns true if logged in to geocaching.com, false otherwise
    def logged_in?
      @chrome.find_elements(css: 'form[action="/account/logout"]').any?
    end

    # Returns an array summarising all cache logs
    def logs_list
      @chrome.get('https://www.geocaching.com/my/logs.aspx?s=1')
      @chrome.execute_script("return document.querySelectorAll('.Table tr')").map{|tr|
        yield
        tds = @chrome.execute_script("return arguments[0].querySelectorAll('td')", tr)
        {
          log_type: LOG_TYPE_MAPPINGS[tds[0].attribute('innerHTML').match(/alt="(.*?)"/)[1]],
          favorite: (tds[1].attribute('innerHTML').strip != ''),
          date: tds[2].text.strip,
          cache_link: @chrome.execute_script("return arguments[0].querySelector('a').href", tds[3]),
          region: tds[4].text.strip,
          log_link: @chrome.execute_script("return arguments[0].querySelector('a').href", tds[5]),
        }
      }.reject{|log| log[:type] == ''}
    end

    # Loads a cache from a URL
    def get_cache(url)
      @chrome.get(url)
      cache_data = {}
      cache_data[:url] = url
      cache_data[:name] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_CacheName').innerText.trim()")
      cache_data[:code] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_CoordInfoLinkControl1_uxCoordInfoCode').innerText.trim()")
      cache_data[:cache_type] = CACHE_TYPE_MAPPINGS[@chrome.execute_script("return document.querySelector('#cacheDetails img').alt")]
      cache_data[:friendly_url] = @chrome.execute_script("return document.querySelector('#aspnetForm').action.trim()").gsub(/(\?.*)?$/, '')
      cache_data[:latlng] = @chrome.execute_script("return document.querySelector('#uxLatLon').innerText.trim()")
      cache_data[:dec_lat], cache_data[:dec_lng] = deg_min_to_dec_deg(cache_data[:latlng])
      cache_data[:difficulty] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_uxLegendScale img').alt.split(' ')[0]").to_i
      cache_data[:terrain] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_Localize12 img').alt.split(' ')[0]").to_i
      cache_data[:size] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_size small').innerText.replace(/[\\(\\)]/g ,'')")
      cache_data[:favorite_points] = @chrome.execute_script("return (fps = document.querySelector('.favorite-value')) && fps.innerText.trim()").to_i
      cache_data[:short_description] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_ShortDescription').innerHTML")
      cache_data[:long_description] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_LongDescription').innerHTML")
      begin
        @chrome.execute_script("document.querySelector('#ctl00_ContentBody_lnkDH').click()") # decode hints
      rescue Selenium::WebDriver::Error::UnknownError
        # Selenium sometimes goes weird here, but it's no biggie
      end
      cache_data[:hint] = @chrome.execute_script("return document.querySelector('#div_hint').innerText.trim()")
      cache_data[:owner_name] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_mcd1 a').innerText")
      cache_data[:owner_link] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_mcd1 a').href")
      cache_data[:hidden_date] = @chrome.execute_script("return document.querySelector('#ctl00_ContentBody_mcd2').innerText.substring(9)")
      cache_data
    end

    # Loads a log from a URL
    def get_log(url)
      @chrome.get(url)
      log_data = {}
      log_data[:cache_code] = @chrome.execute_script("return document.querySelector('.CoordInfoCode').innerText.trim()")
      log_data[:log_type] = LOG_TYPE_MAPPINGS[@chrome.execute_script("return document.querySelector('#ctl00_ContentBody_LogBookPanel1_LogImage').alt")]
      log_data[:log_html] = @chrome.execute_script("return document.querySelector('#LogTextbox').innerHTML.trim()").gsub(/^( |\t|\n|\r|&nbsp;)+/, '').gsub(/( |\t|\n|\r|&nbsp;)+$/, '').strip
      log_data[:log_image] = @chrome.execute_script("return (img = document.querySelector('.LogImagePanel img')) && img.src")
      log_data
    end
  end
end
