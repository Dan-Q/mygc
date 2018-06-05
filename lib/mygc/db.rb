require "active_record"

module MyGc
  class DB
    DEFAULT_FILENAME = 'mygc.db'
    DATABASE_CONFIG = { adapter: 'sqlite3' }

    def self.open(filename = nil)
      filename ||= DEFAULT_FILENAME
      @connection ||= ActiveRecord::Base.establish_connection(self.config(filename))
      ActiveRecord::Migration.verbose = false
      ActiveRecord::Schema.define do
        unless table_exists?(:accounts)
          create_table :accounts do |t|
            t.string :service
            t.string :username
            t.string :password
            t.timestamps
          end
        end
        unless table_exists?(:caches)
          create_table :caches do |t|
            t.string :service
            t.string :url
            t.string :friendly_url
            t.string :name
            t.string :code
            t.string :cache_type
            t.string :friendly_url
            t.string :latlng
            t.string :dec_lat
            t.string :dec_lng
            t.integer :difficulty
            t.integer :terrain
            t.string :size
            t.integer :favorite_points
            t.string :short_description
            t.string :long_description
            t.string :hint
            t.string :owner_name
            t.string :owner_link
            t.datetime :hidden_date
            t.timestamps
          end
        end
        unless table_exists?(:logs)
          create_table :logs do |t|
            t.string :service
            t.string :cache_id
            t.string :cache_code
            t.datetime :date
            t.string :url
            t.string :log_type
            t.string :log_html
            t.string :log_image
            t.boolean :favorite
            t.string :region
            t.timestamps
          end
        end
      end
      self
    end

    def self.config(filename = nil)
      filename ||= DEFAULT_FILENAME
      DATABASE_CONFIG.merge({ database: filename })
    end
  end
end