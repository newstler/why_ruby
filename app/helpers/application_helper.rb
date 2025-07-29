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
    doc.css('code').each do |code_block|
      if code_block.parent.name == 'pre'
        language = code_block['class']&.gsub('language-', '') || 'text'
        begin
          highlighted = Rouge.highlight(code_block.text, language, 'html')
          code_block.parent.replace(highlighted)
        rescue => e
          # If highlighting fails, keep the original code block
          Rails.logger.error "Syntax highlighting failed: #{e.message}"
        end
      end
    end
    
    doc.to_html
  end
end
