# frozen_string_literal: true

require "base64"

namespace :book do
  # Featured testimonials appear first, in this order. Everything else follows in default order.
  FEATURED_USERNAMES = %w[matz dhh pragdave AmandaPerino].freeze

  # Usernames whose testimonials should be excluded from the book output.
  # Kept here (rather than unpublished in the DB) so authors can still edit/resubmit on the site.
  EXCLUDED_USERNAMES = %w[rubyon].freeze

  # Print specs (European printshop, per whyruby.info book contract).
  TRIM_WIDTH_MM = 170
  TRIM_HEIGHT_MM = 240
  BLEED_MM = 3
  PAGE_WIDTH_MM = TRIM_WIDTH_MM + BLEED_MM * 2   # 176
  PAGE_HEIGHT_MM = TRIM_HEIGHT_MM + BLEED_MM * 2 # 246

  # We look for a European coated CMYK profile inside vendor/icc/. Fogra51
  # (PSO Coated v3) is preferred — it's ECI's current recommended default and
  # models OBA-brightened stocks accurately. Fogra39 (ISO Coated v2) is kept
  # as a fallback since a lot of shops still calibrate against it. The ECI
  # files aren't redistributable, so users drop them in themselves.
  PREFERRED_ICC_NAMES = %w[
    PSOcoated_v3.icc
    PSOcoated_v3_FOGRA51.icc
    ISOcoated_v2_eci.icc
    ISOcoated_v2_300_eci.icc
    Coated_Fogra39L_VIGC_300.icc
    FOGRA39.icc
  ].freeze

  desc "Generate 'Why Ruby?' as HTML + print-ready PDF (176×246mm, CMYK, text-to-curves, PDF/X-1a)"
  task generate: :environment do
    testimonials = ordered_testimonials_for_book

    if testimonials.empty?
      puts "No published testimonials found. Nothing to generate."
      exit 0
    end

    html = build_book_html(testimonials)
    html_path = Rails.root.join("tmp", "why_ruby_book.html")
    File.write(html_path, html)

    puts "Generated book with #{testimonials.size} testimonials (#{book_page_count(testimonials)} pages, even-padded)"
    puts "HTML: #{html_path}"

    raw_pdf_path = Rails.root.join("tmp", "why_ruby_book_raw.pdf")
    final_pdf_path = Rails.root.join("tmp", "why_ruby_book.pdf")

    unless render_chrome_pdf(html_path, raw_pdf_path)
      puts "Chrome PDF step failed — skipping post-processing."
      next
    end

    if postprocess_pdf_for_print(raw_pdf_path, final_pdf_path)
      File.delete(raw_pdf_path) if File.exist?(raw_pdf_path)
      puts "PDF:  #{final_pdf_path}"
      puts "      → CMYK · text outlined to curves · PDF/X-1a · 176×246mm (170×240 trim + 3mm bleed)"
    else
      File.rename(raw_pdf_path, final_pdf_path) if File.exist?(raw_pdf_path)
      puts "PDF:  #{final_pdf_path}  (raw Chrome output — post-processing skipped/failed)"
    end
  end

  private

  def ordered_testimonials_for_book
    all = Testimonial.published.ordered.includes(:user).to_a
    all.reject! { |t| EXCLUDED_USERNAMES.include?(t.user.username) }
    featured_by_username = all.each_with_object({}) do |t, acc|
      acc[t.user.username] = t if FEATURED_USERNAMES.include?(t.user.username)
    end
    featured = FEATURED_USERNAMES.map { |u| featured_by_username[u] }.compact
    rest = (all - featured).shuffle
    featured + rest
  end

  def render_chrome_pdf(html_path, pdf_path)
    chrome = detect_chrome_binary
    unless chrome
      puts "Chrome/Chromium not found — cannot generate PDF."
      puts "Install Chrome, or open the HTML in your browser and use File → Print → Save as PDF."
      return false
    end

    ok = system(
      chrome,
      "--headless=new",
      "--disable-gpu",
      "--no-sandbox",
      "--no-pdf-header-footer",
      "--print-to-pdf-no-header",
      "--print-to-pdf=#{pdf_path}",
      "file://#{html_path}"
    )

    ok && File.exist?(pdf_path)
  end

  # Post-process Chrome's PDF into a print-ready PDF/X-1a:
  #   • All glyphs outlined to curves (-dNoOutputFonts) — kills Affinity's
  #     "broken font" import problem since there are no fonts in the file
  #     to break in the first place.
  #   • RGB → CMYK conversion with a Fogra39-family output intent when the
  #     ECI ICC profile is available under vendor/icc/, otherwise Ghostscript's
  #     default CMYK profile (US-SWOP-ish; visually close for proofing).
  #   • /prepress preset keeps images at 300 DPI and honors overprint.
  def postprocess_pdf_for_print(input_path, output_path)
    gs = detect_ghostscript
    unless gs
      puts "Ghostscript not found — skipping print-ready post-processing."
      puts "Install with: brew install ghostscript  (macOS)  or  apt install ghostscript  (Debian/Ubuntu)"
      return false
    end

    icc_path, icc_source = resolve_output_icc_profile
    unless icc_path
      puts "No CMYK ICC profile available — skipping post-processing."
      return false
    end
    pdfx_def_path = write_pdfx_def(icc_path)

    intent = output_intent_metadata(icc_path)
    puts "Post-processing PDF via Ghostscript"
    if icc_source == :fogra
      puts "  Output intent: #{File.basename(icc_path)} (#{intent[:identifier]})"
    else
      puts "  Output intent: Ghostscript default CMYK (drop PSOcoated_v3.icc into"
      puts "                 vendor/icc/ from https://www.eci.org for a fully"
      puts "                 spec-compliant Fogra51 PDF/X-1a; download is free)."
    end

    # Ghostscript 9.28+ SAFER mode needs an explicit allowlist for anything
    # outside the working dir — the ICC profile especially, since it typically
    # lives under /opt/homebrew or /usr/share.
    ok = system(
      gs,
      "-dNOPAUSE", "-dBATCH", "-dSAFER", "-dQUIET",
      "--permit-file-read=#{icc_path}",
      "--permit-file-read=#{pdfx_def_path}",
      "--permit-file-read=#{input_path}",
      "--permit-file-write=#{output_path}",
      "-sDEVICE=pdfwrite",
      "-dCompatibilityLevel=1.6",
      "-dPDFX=1",
      "-dNoOutputFonts",
      "-sProcessColorModel=DeviceCMYK",
      "-sColorConversionStrategy=CMYK",
      "-dPDFSETTINGS=/prepress",
      "-dEmbedAllFonts=true",
      "-dSubsetFonts=true",
      "-dDetectDuplicateImages=true",
      "-sOutputICCProfile=#{icc_path}",
      "-sOutputFile=#{output_path}",
      pdfx_def_path.to_s,
      input_path.to_s
    )

    File.delete(pdfx_def_path) if File.exist?(pdfx_def_path)

    unless ok && File.exist?(output_path)
      puts "  Ghostscript post-processing failed — see errors above."
      return false
    end

    true
  end

  def detect_chrome_binary
    [
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
      "/opt/homebrew/bin/chromium",
      "/usr/bin/google-chrome",
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser"
    ].find { |path| File.executable?(path) }
  end

  def detect_ghostscript
    return ENV["GS_BIN"] if ENV["GS_BIN"] && File.executable?(ENV["GS_BIN"])

    %w[
      /opt/homebrew/bin/gs
      /usr/local/bin/gs
      /usr/bin/gs
    ].find { |path| File.executable?(path) }
  end

  def resolve_output_icc_profile
    vendor_icc = Rails.root.join("vendor", "icc")
    preferred = PREFERRED_ICC_NAMES.map { |name| vendor_icc.join(name) }.find { |p| File.exist?(p) }
    return [ preferred.to_s, :fogra ] if preferred

    default_cmyk = Dir.glob([
      "/opt/homebrew/share/ghostscript/*/iccprofiles/default_cmyk.icc",
      "/usr/local/share/ghostscript/*/iccprofiles/default_cmyk.icc",
      "/usr/share/ghostscript/*/iccprofiles/default_cmyk.icc"
    ]).first

    default_cmyk ? [ default_cmyk, :default ] : [ nil, :missing ]
  end

  # Adapted from Ghostscript's stock PDFX_def.ps, hard-coded for PDF/X-1a. The
  # OutputConditionIdentifier / Info are derived from the actual embedded ICC
  # so metadata stays consistent (Fogra51 profile → FOGRA51 tag, etc.). If we
  # fall back to gs's default CMYK, we tag it Fogra51 as the safest modern
  # default — the printshop will resolve against their own calibration anyway.
  def write_pdfx_def(icc_path)
    escaped_icc = icc_path.to_s.gsub("(", '\\(').gsub(")", '\\)')
    intent = output_intent_metadata(icc_path)

    body = <<~PS
      %!
      % Generated PDF/X-1a header for the 'Why Ruby?' book.

      systemdict /ColorConversionStrategy known {
        systemdict /ColorConversionStrategy get cvn dup /Gray ne exch /CMYK ne and
      } {
        true
      } ifelse
      { /ColorConversionStrategy cvx /rangecheck signalerror
      } if

      [ /GTS_PDFXVersion (PDF/X-1a:2001)
        /Title (Why Ruby?)
        /Trapped /False
      /DOCINFO pdfmark

      /ICCProfile (#{escaped_icc}) def

      [/_objdef {icc_PDFX} /type /stream /OBJ pdfmark
      [{icc_PDFX} << /N 4 >> /PUT pdfmark
      [{icc_PDFX} ICCProfile (r) file /PUT pdfmark

      [/_objdef {OutputIntent_PDFX} /type /dict /OBJ pdfmark
      [{OutputIntent_PDFX} <<
        /Type /OutputIntent
        /S /GTS_PDFX
        /OutputCondition (Commercial offset printing, Europe)
        /Info (#{intent[:info]})
        /OutputConditionIdentifier (#{intent[:identifier]})
        /RegistryName (http://www.color.org)
        /DestOutputProfile {icc_PDFX}
      >> /PUT pdfmark
      [{Catalog} <</OutputIntents [ {OutputIntent_PDFX} ]>> /PUT pdfmark
    PS

    path = Rails.root.join("tmp", "why_ruby_pdfx_def.ps")
    File.write(path, body)
    path
  end

  def output_intent_metadata(icc_path)
    name = File.basename(icc_path.to_s).downcase
    if name.include?("psocoated_v3") || name.include?("fogra51")
      { identifier: "FOGRA51", info: "Coated FOGRA51 \\(PSO Coated v3, ISO 12647-2:2013\\)" }
    elsif name.include?("isocoated_v2") || name.include?("fogra39")
      { identifier: "FOGRA39", info: "Coated FOGRA39 \\(ISO Coated v2, ISO 12647-2:2004\\)" }
    else
      # Unknown/default profile — tag as Fogra51 (current ECI recommendation).
      { identifier: "FOGRA51", info: "Coated FOGRA51 \\(PSO Coated v3, ISO 12647-2:2013\\)" }
    end
  end

  # Front matter is 2 pages (title + colophon), back matter is 1 page.
  # Printshops need an even total, so we drop a blank leaf before the back
  # cover if the count comes out odd.
  def book_page_count(testimonials)
    base = 2 + testimonials.size + 1
    base.odd? ? base + 1 : base
  end

  def build_book_html(testimonials)
    base_pages = 2 + testimonials.size + 1
    padding_page = base_pages.odd? ? blank_page : ""

    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Why Ruby?</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700;900&display=swap" rel="stylesheet">
        <style>
          #{book_css}
        </style>
      </head>
      <body>
        #{title_page}
        #{colophon_page}
        #{testimonials.map { |t| testimonial_page(t) }.join("\n")}
        #{padding_page}
        #{back_page}
      </body>
      </html>
    HTML
  end

  def blank_page
    %(<div class="page blank-page"></div>)
  end

  def book_css
    <<~CSS
      @page {
        size: 176mm 246mm;
        margin: 0;
      }

      *, *::before, *::after {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
      }

      html, body {
        margin: 0;
        padding: 0;
        background: #fff;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }

      body {
        font-family: "Inter", system-ui, -apple-system, sans-serif;
        color: #000;
        line-height: 1.5;
      }

      .page {
        width: 176mm;
        height: 246mm;
        padding: 20mm 18mm;
        position: relative;
        overflow: hidden;
        page-break-after: always;
        display: flex;
        flex-direction: column;
      }

      .page:last-child {
        page-break-after: auto;
      }

      /* ── Title page ── */

      .title-page {
        justify-content: center;
        align-items: center;
        text-align: center;
      }

      .title-page__logo {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 8mm;
        font-weight: 900;
        font-size: 84pt;
        color: #dc2626;
        line-height: 1;
        letter-spacing: -0.02em;
      }

      .title-page__logo-icon {
        width: 44mm;
        height: 44mm;
        object-fit: contain;
      }

      /* ── Colophon page ── */

      .colophon-page {
        justify-content: flex-end;
        align-items: center;
        text-align: center;
      }

      .colophon-page__text {
        font-size: 8.5pt;
        color: #9ca3af;
        letter-spacing: 0.04em;
        padding-bottom: 4mm;
      }

      /* ── Back page ── */

      .back-page {
        justify-content: center;
        align-items: center;
        text-align: center;
      }

      .back-page__heart {
        font-size: 14pt;
        color: #6b7280;
        line-height: 1.8;
      }

      .back-page__url {
        font-size: 9pt;
        color: #9ca3af;
        letter-spacing: 0.08em;
        margin-top: 8mm;
      }

      /* ── Testimonial page (1:1 home-carousel layout, centered on page) ── */

      .testimonial-page {
        justify-content: center;
        align-items: stretch;
      }

      .testimonial-inner {
        display: flex;
        flex-direction: column;
      }

      .testimonial__heading {
        font-family: Georgia, "Times New Roman", serif;
        font-style: italic;
        font-size: 46pt;
        color: #dc2626;
        line-height: 1.05;
        letter-spacing: -0.02em;
        margin-bottom: 6mm;
      }

      .testimonial__subheading {
        font-size: 18pt;
        font-weight: 700;
        color: #000;
        line-height: 1.3;
        margin-bottom: 3mm;
      }

      .testimonial__body {
        font-size: 11pt;
        color: #6b7280;
        line-height: 1.7;
        margin-top: 5mm;
        margin-bottom: 12mm;
      }

      /* Red bordered quote box + red opening " overhanging top-left + downward tail. */
      .quote-block {
        position: relative;
        padding-top: 3mm;
      }

      .quote-block__mark {
        position: absolute;
        top: -6mm;
        left: -3mm;
        font-family: Georgia, "Times New Roman", serif;
        font-size: 60pt;
        color: #dc2626;
        line-height: 1;
        user-select: none;
        z-index: 2;
      }

      .quote-block__box {
        background: #fff;
        border: 1.5pt solid #fecaca;
        border-radius: 3mm;
        padding: 8mm;
        position: relative;
      }

      .quote-block__text {
        font-style: italic;
        font-size: 12pt;
        color: #4b5563;
        line-height: 1.6;
      }

      /* Quotes have no length cap, so the type steps down to fit the page
         rather than the text ever being cut. */
      .quote-block__text--long   { font-size: 11pt; line-height: 1.55; }
      .quote-block__text--longer { font-size: 10pt; line-height: 1.5; }
      .quote-block__text--xlong  { font-size: 9pt;  line-height: 1.45; }

      .quote-block__box--long   { padding: 7mm; }
      .quote-block__box--longer { padding: 6mm; }
      .quote-block__box--xlong  { padding: 5mm; }

      /* Speech-bubble tail: outer red triangle + inner white triangle, pointing down toward avatar. */
      .quote-block__box::before,
      .quote-block__box::after {
        content: "";
        position: absolute;
        width: 0;
        height: 0;
      }

      /* Outer red tail apex is shifted 1 mm further left than the inner white,
         so the red tail-point pokes out to the left of the white — feels more
         "leaning toward" the avatar rather than perfectly stacked. */
      .quote-block__box::before {
        bottom: -5mm;
        left: 10.2mm;
        border-left: 4mm solid transparent;
        border-right: 4mm solid transparent;
        border-top: 5mm solid #fecaca;
      }

      .quote-block__box::after {
        bottom: -4mm;
        left: 9.5mm;
        border-left: 5mm solid transparent;
        border-right: 5mm solid transparent;
        border-top: 6mm solid #fff;
      }

      /* User tile — avatar left, info right (matches _user_tile.html.erb on iPad). */
      .user-tile {
        display: flex;
        align-items: center;
        gap: 5mm;
        margin-top: 8mm;
      }

      .user-tile__avatar-wrap {
        width: 30mm;
        height: 32mm;
        position: relative;
        flex-shrink: 0;
      }

      .user-tile__info {
        flex: 1;
        min-width: 0;
      }

      .user-tile__name {
        font-size: 16pt;
        font-weight: 700;
        color: #000;
        line-height: 1.15;
      }

      .user-tile__bio {
        font-size: 9pt;
        color: #6b7280;
        line-height: 1.4;
        margin-top: 2mm;
      }

      .user-tile__meta {
        font-size: 8pt;
        color: #9ca3af;
        line-height: 1.4;
        display: flex;
        flex-wrap: wrap;
        gap: 3mm;
        margin-top: 1.5mm;
      }

      .user-tile__meta-item {
        display: inline-flex;
        align-items: center;
        gap: 1mm;
      }

      .user-tile__meta-icon {
        width: 2.8mm;
        height: 2.8mm;
        color: #d1d5db;
        fill: currentColor;
        flex-shrink: 0;
      }
    CSS
  end

  def title_page
    <<~HTML
      <div class="page title-page">
        <div class="title-page__logo">
          <span>Why</span>
          <img class="title-page__logo-icon" src="#{heart_data_uri}" alt="">
          <span>Ruby?</span>
        </div>
      </div>
    HTML
  end

  def colophon_page
    <<~HTML
      <div class="page colophon-page">
        <div class="colophon-page__text">whyruby.info &bull; #{Date.current.year}</div>
      </div>
    HTML
  end

  def back_page
    <<~HTML
      <div class="page back-page">
        <div class="back-page__heart">Made with &#10084;&#65039; by the Ruby community</div>
        <div class="back-page__url">rubycommunity.org</div>
      </div>
    HTML
  end

  def testimonial_page(testimonial)
    user = testimonial.user
    subheading_html = format_subheading(testimonial.subheading)

    <<~HTML
      <div class="page testimonial-page">
        <div class="testimonial-inner">
          #{"<div class=\"testimonial__heading\">#{escape(testimonial.heading)}</div>" if testimonial.heading.present?}
          #{"<div class=\"testimonial__subheading\">#{subheading_html}</div>" if testimonial.subheading.present?}
          #{"<div class=\"testimonial__body\">#{escape(testimonial.body_text)}</div>" if testimonial.body_text.present?}
          #{quote_block(testimonial)}
          #{user_tile(user)}
        </div>
      </div>
    HTML
  end

  # Step the quote type down as the text grows. Never truncates — the full quote
  # is always printed, the page just gives it more room.
  QUOTE_FIT_STEPS = [ [ 560, "xlong" ], [ 460, "longer" ], [ 360, "long" ] ].freeze

  def quote_block(testimonial)
    return "" if testimonial.quote.blank?

    step = QUOTE_FIT_STEPS.find { |threshold, _| testimonial.quote.length > threshold }&.last
    text_class = [ "quote-block__text", ("quote-block__text--#{step}" if step) ].compact.join(" ")
    box_class = [ "quote-block__box", ("quote-block__box--#{step}" if step) ].compact.join(" ")

    <<~HTML
      <div class="quote-block">
        <span class="quote-block__mark">&ldquo;</span>
        <div class="#{box_class}">
          <div class="#{text_class}">#{escape(testimonial.quote)}</div>
        </div>
      </div>
    HTML
  end

  def user_tile(user)
    @gem_clip_counter = (@gem_clip_counter || 0) + 1
    uid = @gem_clip_counter
    avatar_url = escape(user.avatar_url.to_s)
    gem_path = "M56.6.55h86.84c6.79,0,13.13,3.39,16.9,9.04l36.26,54.34c5.26,7.89,4.37,18.37-2.15,25.25l-79.68,84.14c-8.01,8.46-21.49,8.46-29.51,0L5.59,89.18c-6.52-6.88-7.41-17.36-2.15-25.25L39.7,9.59C43.47,3.94,49.81.55,56.6.55Z"

    meta_items = []

    if user.company.present?
      meta_items << <<~HTML.strip
        <span class="user-tile__meta-item">
          <svg class="user-tile__meta-icon" viewBox="0 0 20 20" fill="#9ca3af">
            <path fill-rule="evenodd" d="M4 16.5v-13h-.25a.75.75 0 010-1.5h12.5a.75.75 0 010 1.5H16v13h.25a.75.75 0 010 1.5H3.75a.75.75 0 010-1.5H4zm3-11a.5.5 0 01.5-.5h1a.5.5 0 01.5.5v1a.5.5 0 01-.5.5h-1a.5.5 0 01-.5-.5v-1zm4 0a.5.5 0 01.5-.5h1a.5.5 0 01.5.5v1a.5.5 0 01-.5.5h-1a.5.5 0 01-.5-.5v-1zm-4 4a.5.5 0 01.5-.5h1a.5.5 0 01.5.5v1a.5.5 0 01-.5.5h-1a.5.5 0 01-.5-.5v-1zm4 0a.5.5 0 01.5-.5h1a.5.5 0 01.5.5v1a.5.5 0 01-.5.5h-1a.5.5 0 01-.5-.5v-1zm-3 4h2a.5.5 0 01.5.5v3h-3v-3a.5.5 0 01.5-.5z" clip-rule="evenodd"/>
          </svg>
          #{escape(user.company)}
        </span>
      HTML
    end

    if user.location.present?
      meta_items << <<~HTML.strip
        <span class="user-tile__meta-item">
          <svg class="user-tile__meta-icon" viewBox="0 0 20 20" fill="#9ca3af">
            <path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd"/>
          </svg>
          #{escape(user.location)}
        </span>
      HTML
    end

    <<~HTML
      <div class="user-tile">
        <div class="user-tile__avatar-wrap">
          <svg viewBox="0 0 200 180" preserveAspectRatio="xMidYMid meet" style="width:100%;height:100%;overflow:visible;" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <clipPath id="gem-clip-#{uid}">
                <path d="#{gem_path}"/>
              </clipPath>
            </defs>
            #{"<image href=\"#{avatar_url}\" width=\"200\" height=\"180\" clip-path=\"url(#gem-clip-#{uid})\" preserveAspectRatio=\"xMidYMid slice\"/>" if avatar_url.present?}
            #{"<rect width=\"200\" height=\"180\" fill=\"#d1d5db\" clip-path=\"url(#gem-clip-#{uid})\"/>" if avatar_url.blank?}
            <path d="#{gem_path}" fill="none" stroke="white" stroke-width="10"/>
            <path d="#{gem_path}" fill="none" stroke="#e5e7eb" stroke-width="5"/>
          </svg>
        </div>
        <div class="user-tile__info">
          <div class="user-tile__name">#{escape(user.display_name)}</div>
          #{"<div class=\"user-tile__bio\">#{escape(user.bio)}</div>" if user.bio.present?}
          #{meta_items.any? ? "<div class=\"user-tile__meta\">#{meta_items.join}</div>" : ""}
        </div>
      </div>
    HTML
  end

  def format_subheading(subheading)
    return "" if subheading.blank?

    subheading
      .split(".")
      .map(&:strip)
      .reject(&:blank?)
      .map { |sentence| "#{escape(sentence)}." }
      .join("<br>")
  end

  def escape(text)
    ERB::Util.html_escape(text.to_s)
  end

  def heart_data_uri
    @heart_data_uri ||= begin
      path = Rails.root.join("app", "assets", "images", "heart.webp")
      "data:image/webp;base64,#{Base64.strict_encode64(File.binread(path))}"
    end
  end
end
