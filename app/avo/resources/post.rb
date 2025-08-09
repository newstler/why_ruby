class Avo::Resources::Post < Avo::BaseResource
  self.title = :title
  self.includes = [:user, :category, :tags, :comments]
  self.model_class = ::Post
  self.index_query = -> { query.unscoped }
  self.description = "Manage all posts in the system"
  self.default_view_type = :table
  
  self.search = {
    query: -> { Post.unscoped.ransack(title_cont: params[:q], content_cont: params[:q], m: "or").result(distinct: false) }
  }
  
  # Override to find records without default scope
  def self.find_record(id, **kwargs)
    ::Post.unscoped.find(id)
  end

  def fields
    # Compact ID display - only show last 8 chars on index
    field :id, as: :text, readonly: true, hide_on: [:index]
    
    # Main content fields
    field :title, as: :text, required: true, link_to_record: true
    
    # User with avatar - custom display for index
    field :user, as: :belongs_to,
      only_on: [:forms, :show]
    
    field :user_with_avatar, 
      as: :text,
      name: "User",
      only_on: [:index],
      format_using: -> do
        if record.user
          avatar_url = record.user.avatar_url || "https://avatars.githubusercontent.com/u/0"
          link_to view_context.avo.resources_user_path(record.user), 
                  class: "flex items-center gap-2 hover:underline" do
            image_tag(avatar_url, class: "w-5 h-5 rounded-full", alt: record.user.username) +
            content_tag(:span, record.user.username)
          end
        else
          content_tag(:span, "-", class: "text-gray-400")
        end
      end
    
    field :category, as: :belongs_to
    
    # Status badges for index view
    field :published, 
      as: :text,
      name: "Published",
      only_on: [:index],
      format_using: -> do
        if record.published
          content_tag(:span, class: "inline-flex items-center text-green-600") do
            # Simple checkmark for consistency
            content_tag(:svg, xmlns: "http://www.w3.org/2000/svg",
                       class: "w-4 h-4",
                       viewBox: "0 0 20 20",
                       fill: "currentColor") do
              content_tag(:path, nil,
                         "fill-rule": "evenodd",
                         d: "M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z",
                         "clip-rule": "evenodd")
            end
          end
        else
          content_tag(:span, "-", class: "text-gray-400")
        end
      end
    
    field :published, as: :boolean, hide_on: [:index]
    field :pin_position, as: :number, hide_on: [:index]
    
    # Needs Review with custom icons
    field :needs_admin_review, 
      as: :text,
      name: "Needs Review",
      only_on: [:index],
      format_using: -> do
        if record.needs_admin_review
          content_tag(:span, class: "inline-flex items-center text-red-600") do
            # Exclamation mark in circle for "yes"
            content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", 
                       class: "w-4 h-4", 
                       viewBox: "0 0 20 20", 
                       fill: "currentColor") do
              content_tag(:path, nil, 
                         "fill-rule": "evenodd",
                         d: "M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z",
                         "clip-rule": "evenodd")
            end
          end
        else
          content_tag(:span, class: "inline-flex items-center text-green-600") do
            # Simple checkmark for consistency with Published field
            content_tag(:svg, xmlns: "http://www.w3.org/2000/svg",
                       class: "w-4 h-4",
                       viewBox: "0 0 20 20",
                       fill: "currentColor") do
              content_tag(:path, nil,
                         "fill-rule": "evenodd",
                         d: "M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z",
                         "clip-rule": "evenodd")
            end
          end
        end
      end
    
    field :needs_admin_review, as: :boolean, hide_on: [:index]
    
    # URL field for forms - plain text input
    field :url, as: :text, 
      only_on: [:forms],
      placeholder: "https://example.com/article"
    
    # URL field for show view - formatted as link
    field :url, as: :text,
      only_on: [:show],
      format_using: -> { link_to(value, value, target: "_blank", class: "text-blue-600 hover:underline") if value.present? }
    
    # Add a compact URL field just for index
    field :url, as: :text, 
      name: "Link",
      only_on: [:index],
      format_using: -> do
        if value.present?
          domain = URI.parse(value).host rescue "External"
          link_to(domain || "Link", value, target: "_blank", class: "text-blue-600 hover:underline")
        else
          content_tag(:span, "-", class: "text-gray-400")
        end
      end
    
    # Long content fields - hide from index
    field :content, as: :textarea, hide_on: [:index], rows: 20
    field :summary, as: :textarea, hide_on: [:index], rows: 5
    field :title_image_url, as: :text, hide_on: [:index]
    
    # Counts and metadata
    field :reports_count, as: :number, readonly: true, hide_on: [:index]
    
    # Clickable comments count that leads to filtered comments
    field :comments,
      as: :text,
      name: "Comments",
      only_on: [:index],
      format_using: -> do
        count = record.comments.count
        if count > 0
          link_to count.to_s, 
                  view_context.avo.resources_comments_path(via_record_id: record.id, via_resource_class: "Avo::Resources::Post"),
                  class: "text-blue-600 hover:underline font-medium",
                  title: "View comments for this post"
        else
          content_tag(:span, "0", class: "text-gray-400")
        end
      end
    
    # Timestamps - show only updated_at on index
    field :created_at, as: :date_time, readonly: true, hide_on: [:index]
    field :updated_at, as: :date_time, readonly: true
    
    # Associations - hide from index to save space
    field :tags, as: :has_and_belongs_to_many, hide_on: [:index]
    field :comments, as: :has_many, hide_on: [:index]
    field :reports, as: :has_many, hide_on: [:index]
  end
  
  def actions
    action Avo::Actions::TogglePublished
    action Avo::Actions::RegenerateSummary
    action Avo::Actions::BulkDelete
    # action Avo::Actions::PinContent
    # action Avo::Actions::ClearReports
  end
  
  # def filters
  #   filter Avo::Filters::Published
  #   filter Avo::Filters::NeedsReview
  #   filter Avo::Filters::ContentType
  # end
end 