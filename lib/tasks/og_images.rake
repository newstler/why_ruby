namespace :og do
  desc "Screenshot the community OG image page to public/og-image-community.png"
  task community: :environment do
    require "selenium-webdriver"
    require "base64"

    port = ENV.fetch("PORT", 3003)
    url = "http://localhost:#{port}/og-image-community"

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
    options.add_argument("--hide-scrollbars")

    driver = Selenium::WebDriver.for(:chrome, options:)

    begin
      # Viewport must be wider than the 1200px body so content doesn't get squeezed.
      # The CDP clip below ensures the output is exactly 1200x630.
      driver.manage.window.resize_to(1600, 900)

      driver.navigate.to(url)
      sleep 2

      # CDP screenshot clipped to exact OG image dimensions
      result = driver.execute_cdp("Page.captureScreenshot",
        format: "png",
        clip: { x: 0, y: 0, width: 1200, height: 630, scale: 1 })

      output_path = Rails.root.join("public", "og-image-community.png").to_s
      File.binwrite(output_path, Base64.decode64(result["data"]))

      puts "Saved OG image to #{output_path}"
    ensure
      driver.quit
    end
  end
end
