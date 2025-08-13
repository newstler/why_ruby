module ImageHelper
  # Generate a responsive image tag - simplified for Turbo compatibility
  def responsive_post_image(post, size: :medium, css_class: "", alt: nil, loading: "auto")
    return nil unless post.featured_image.attached?

    # Get the appropriate blob
    blob = if post.has_processed_images? && post.image_variant(size)
             post.image_variant(size)
    else
             post.featured_image.blob
    end

    return nil unless blob

    # Use URL helper for consistent URL generation
    image_url = url_for(blob)

    # Simple image tag without complex blur loading (which breaks with Turbo)
    image_tag(image_url,
             alt: alt || post.title,
             class: css_class,
             loading: loading)  # Use auto to let browser decide
  end

  # Simpler version for tile/grid views
  def post_image_tag(post, size: :thumb, css_class: "", alt: nil)
    return nil unless post.featured_image.attached?

    # Get the appropriate blob
    blob = if post.has_processed_images? && post.image_variant(size)
             post.image_variant(size)
    else
             post.featured_image.blob
    end

    return nil unless blob

    # Use URL helper
    image_url = url_for(blob)

    # Simple image tag without lazy loading for tiles (they're small WebP files anyway)
    image_tag(image_url,
             alt: alt || post.title,
             class: css_class,
             loading: "auto")  # Let browser decide
  end

  # Get the optimal image size for context
  def image_size_for_context(context)
    case context
    when :tile, :grid
      :thumb
    when :post, :show
      :medium
    when :og, :social
      :large
    else
      :medium
    end
  end
end
