// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Disable Turbo progress bar to prevent inline styles in head
import { Turbo } from "@hotwired/turbo-rails"
Turbo.config.drive.progressBarDelay = Infinity // Effectively disables the progress bar
