# frozen_string_literal: true

module Middleware
  # Blocks known malicious request paths before they reach the Rails router.
  # Two strategies:
  # 1. Blocklist: known exploit patterns (WordPress, PHP, etc.)
  # 2. File extension guard: any path with a file extension that doesn't
  #    correspond to an actual file in public/ gets blocked. This prevents
  #    scanners from probing paths like /delete.sql, /secrets.txt, etc.
  class MaliciousPathBlocker
    BLOCKED_PATTERNS = [
      # WordPress
      /wp-admin/i, /wp-includes/i, /wp-content/i, /wp-login/i,
      /xmlrpc\.php/i, /wp-config/i,
      # PHP files
      /\.php$/i, /\.php\//i,
      # Common exploit paths
      /\.env$/i, /\.git/i, /\.svn/i,
      /phpinfo/i, /phpmyadmin/i,
      /admin\.php/i, /setup\.php/i,
      # Path traversal
      /\.\.\//,
      # Dotfiles (e.g. .rbenv-vars, .yarnrc, .dockerignore)
      /\/\.[^\/]+$/
    ].freeze

    # Matches paths like /foo.xml, /bar.txt, /Dockerfile (no extension but known probe)
    FILE_EXTENSION_PATTERN = /\.[a-zA-Z0-9]+$/

    def initialize(app)
      @app = app
      @public_path = Rails.public_path
    end

    def call(env)
      path = env["PATH_INFO"].to_s

      if blocked_path?(path)
        log_blocked_request(env, path)
        [ 403, { "Content-Type" => "text/plain" }, [ "Forbidden" ] ]
      elsif unknown_file_request?(path)
        log_blocked_request(env, path)
        [ 404, { "Content-Type" => "text/plain" }, [ "Not Found" ] ]
      else
        @app.call(env)
      end
    end

    private

    def blocked_path?(path)
      BLOCKED_PATTERNS.any? { |pattern| path.match?(pattern) }
    end

    def unknown_file_request?(path)
      return false unless path.match?(FILE_EXTENSION_PATTERN)

      # Allow if a real file exists in public/
      !File.exist?(File.join(@public_path, path))
    end

    def log_blocked_request(env, path)
      ip = env["HTTP_X_FORWARDED_FOR"]&.split(",")&.first&.strip || env["REMOTE_ADDR"]
      Rails.logger.warn "[MaliciousPathBlocker] Blocked: #{path} from #{ip}"
    end
  end
end
