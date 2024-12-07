# frozen_string_literal: true

module SQLite3
  class Database
    alias_method :original_initialize_extensions, :initialize_extensions

    def initialize_extensions(extensions)
      # Convert extension names to actual paths
      extensions&.map! do |ext|
        case ext
        when 'ulid'
          require 'sqlite_ulid'
          SqliteUlid.ulid_loadable_path
        else
          ext
        end
      end

      original_initialize_extensions(extensions)
    end
  end
end
