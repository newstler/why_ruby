module ApplicationHelper
  def markdown_to_html(markdown_text)
    return "" if markdown_text.blank?
    
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: 'nofollow', target: '_blank' }
    )
    
    markdown = Redcarpet::Markdown.new(renderer, 
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      disable_indented_code_blocks: true,
      strikethrough: true,
      lax_spacing: true,
      space_after_headers: true,
      superscript: true,
      underline: true,
      highlight: true,
      quote: true,
      footnotes: true
    )
    
    # Render markdown and apply syntax highlighting
    html = markdown.render(markdown_text)
    
    # Apply syntax highlighting to code blocks
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    doc.css('pre code').each do |code_block|
      language = code_block['class']&.gsub('language-', '') || 'text'
      begin
        lexer = Rouge::Lexer.find(language) || Rouge::Lexers::PlainText.new
        formatter = Rouge::Formatters::HTML.new(css_class: 'highlight')
        highlighted_code = formatter.format(lexer.lex(code_block.text))
        
        # Replace the pre > code structure with highlighted version
        new_pre = Nokogiri::HTML::DocumentFragment.parse(
          %Q(<div class="highlight highlight-#{language}">#{highlighted_code}</div>)
        )
        code_block.parent.parent.replace(new_pre) if code_block.parent
      rescue => e
        # If highlighting fails, keep the original code block
        Rails.logger.error "Syntax highlighting failed for language '#{language}': #{e.message}"
      end
    end
    
    doc.to_html
  end
end
