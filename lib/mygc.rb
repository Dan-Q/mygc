require 'mygc/version'
require 'mygc/services'
require 'mygc/db'
require 'mygc/models/account'
require 'mygc/models/cache'
require 'mygc/models/log'
require 'thor'
require 'ruby-progressbar'

module MyGc
  PROGRESSBAR_FORMAT = '%t: |%b%i| %p%% %e'

  class CLIAccount < Thor
    desc "add", "Add a geocaching account"
    def add
      MyGc::DB::open(options[:db])
      puts "Known services: #{Account::KNOWN_SERVICES.keys.join(' ')}"
      service = ask "Which service:"
      username = ask "Username:"
      password = ask "Password:"
      new_account = Account.new(service: service, username: username, password: password)
      if new_account.save
        puts "New account created."
      else
        puts "Failed to add account:\n#{new_account.errors.full_messages.map{|e|" * #{e}"}.join("\n")}"
      end
    end

    desc "remove", "Remove a geocaching account"
    def remove
      MyGc::DB::open(options[:db])
      id = ask "Remove which account (ID):"
      unless account = Account.find_by_id(id)
        puts "Account not found with ID #{id}."
        return
      end
      account.destroy
      puts "Account removed."
    end

    desc "list", "List geocaching accounts"
    def list
      MyGc::DB::open(options[:db])
      puts Account.list
    end

    desc "modify", "Modify a geocaching account"
    def modify
      MyGc::DB::open(options[:db])
      id = ask "Modify which account (ID):"
      unless account = Account.find_by_id(id)
        puts "Account not found with ID #{id}."
        return
      end
      username = ask "Username (enter to leave unchanged):"
      username = account.username if username == ''
      password = ask "Password (enter to leave unchanged):"
      password = account.password if password == ''
      if account.update_attributes(username: username, password: password)
        puts "Updated account."
      else
        puts "Failed to update account:\n#{account.errors.full_messages.map{|e|" * #{e}"}.join("\n")}"
      end
    end
  end

  class CLICache < Thor
    desc "list", "List known caches"
    def list
      MyGc::DB::open(options[:db])
      puts Cache.list
    end
  end

  class CLILog < Thor
    desc "list", "List logs"
    def list
      MyGc::DB::open(options[:db])
      puts Log.list
    end
  end

  class CLI < Thor
    method_option :db, aliases: "-d", desc: "File to store results in; default #{MyGc::DB::DEFAULT_FILENAME}"

    desc "account", "Add, remove, or list geocaching accounts"
    subcommand "account", CLIAccount

    desc "cache", "List known caches"
    subcommand "cache", CLICache

    desc "log", "List logs"
    subcommand "log", CLILog

    desc "test", "Test connectivity of all accounts"
    def test
      MyGc::DB::open(options[:db])
      Account.all.map(&:to_service).each do |service|
        progress = ProgressBar.create(title: "#{service.class::NAME} / #{service.account.username}", total: 2, format: PROGRESSBAR_FORMAT)
        service.log_in; progress.increment; service.wait
        success = service.logged_in?
        progress.increment
        puts success ? 'OKAY' : 'FAILED'
      end
    end

    desc "update", "Update logs of all accounts"
    def update
      MyGc::DB::open(options[:db])
      Account.all.map(&:to_service).each do |service|
        progress = ProgressBar.create(title: "#{service.class::NAME} / #{service.account.username}", total: nil, format: PROGRESSBAR_FORMAT)
        # Log in
        service.log_in; progress.increment; service.wait
        success = service.logged_in?
        progress.increment
        raise "Login failed" unless success
        # Get logs list
        service.wait
        logs_list = service.logs_list{progress.increment}
        progress.progress = 0
        progress.total = (logs_list.length * 2)
        # Get each log and its cache
        logs_list.each do |log_row|
          begin
            cache = Cache.find_or_initialize_by(service: service.account.service, url: log_row[:cache_link])
            if cache.needs_updating?
              # DEBUG: puts "#{cache.new_record? ? 'Creating' : 'Updating'} cache described at #{log_row[:cache_link]}"
              service.wait
              cache_data = service.get_cache(log_row[:cache_link])
              raise cache.errors.full_messages.join("\n") unless cache.update_attributes(cache_data)
            end
            progress.increment
            log = Log.find_or_initialize_by(cache_id: cache.id, service: service.account.service, url: log_row[:log_link])
            if log.needs_updating?
              # DEBUG: puts "#{log.new_record? ? 'Creating' : 'Updating'} log described at #{log_row[:log_link]}"
              log.log_type = log_row[:log_type]
              log.favorite = log_row[:favorite]
              log.date = log_row[:date]
              log.region = log_row[:region]
              service.wait
              log_data = service.get_log(log_row[:log_link])
              raise log.errors.full_messages.join("\n") unless log.update_attributes(log_data)
            end
            progress.increment
          rescue Net::ReadTimeout => e
            # We can accept a few ReadTimeouts from time to time
            puts "Net::ReadTimeout"
          rescue Selenium::WebDriver::Error::UnknownError => e
            # These sometimes happen, too, when trying to load a page. Ignore and press on, for now.
            puts "Selenium::WebDriver::Error::UnknownError"
          end
        end
      end
    end
  end
end

# MyGc::DB::open
MyGc::CLI.start
