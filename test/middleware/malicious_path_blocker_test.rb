# frozen_string_literal: true

require "test_helper"

class MaliciousPathBlockerTest < ActionDispatch::IntegrationTest
  # WordPress paths
  test "blocks wp-admin requests" do
    get "/wp-admin"
    assert_response :forbidden
  end

  test "blocks wp-login.php requests" do
    get "/wp-login.php"
    assert_response :forbidden
  end

  test "blocks xmlrpc.php requests" do
    get "/xmlrpc.php"
    assert_response :forbidden
  end

  test "blocks wp-config requests" do
    get "/wp-config.php.bak"
    assert_response :forbidden
  end

  # PHP files
  test "blocks .php file requests" do
    get "/admin.php"
    assert_response :forbidden
  end

  # Sensitive files
  test "blocks .env file requests" do
    get "/.env"
    assert_response :forbidden
  end

  test "blocks .git directory requests" do
    get "/.git/config"
    assert_response :forbidden
  end

  # Path traversal
  test "blocks path traversal attempts" do
    get "/../../etc/passwd"
    assert_response :forbidden
  end

  # Dotfiles (scanner probes)
  test "blocks dotfile requests like .rbenv-vars" do
    get "/.rbenv-vars"
    assert_response :forbidden
  end

  test "blocks dotfile requests like .yarnrc" do
    get "/.yarnrc"
    assert_response :forbidden
  end

  # File extension probes (not in public/)
  test "blocks unknown file extensions like delete.sql" do
    get "/delete.sql"
    assert_response :not_found
  end

  test "blocks unknown file extensions like secrets.txt" do
    get "/secrets.txt"
    assert_response :not_found
  end

  test "blocks unknown file extensions like remove.sh" do
    get "/remove.sh"
    assert_response :not_found
  end

  test "blocks unknown file extensions like sitemap.xml" do
    get "/sitemap.xml"
    assert_response :not_found
  end

  # Apple touch icon — legitimate iOS request, served as static file
  test "allows apple-touch-icon-precomposed requests" do
    get "/apple-touch-icon-precomposed.png"
    assert_response :success
  end

  # Known public files should pass through
  test "allows robots.txt" do
    get "/robots.txt"
    assert_response :success
  end

  test "allows favicon.ico" do
    get "/favicon.ico"
    assert_response :success
  end

  # Case insensitivity
  test "blocks uppercase WordPress paths" do
    get "/WP-ADMIN"
    assert_response :forbidden
  end

  # Legitimate paths should not be blocked
  test "allows root path" do
    get "/"
    assert_response :success
  end

  test "allows health check" do
    get "/up"
    assert_response :success
  end
end
