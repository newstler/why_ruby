class Avo::Resources::Testimonial < Avo::BaseResource
  self.title = :heading
  self.includes = [ :user ]
  self.model_class = ::Testimonial
  self.description = "Manage user testimonials"
  self.default_view_type = :table

  def fields
    field :id, as: :text, readonly: true, hide_on: [ :index ]

    field :user_with_avatar,
      as: :text,
      name: "User",
      only_on: [ :index ],
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

    field :user, as: :belongs_to, only_on: [ :forms, :show ]

    field :heading, as: :text, link_to_record: true
    field :subheading, as: :text, hide_on: [ :index ]
    field :quote, as: :textarea, rows: 4
    field :body_text, as: :textarea, rows: 6, hide_on: [ :index ]

    field :published,
      as: :text,
      name: "Published",
      only_on: [ :index ],
      format_using: -> do
        if record.published
          content_tag(:span, class: "inline-flex items-center text-green-600") do
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

    field :published, as: :boolean, hide_on: [ :index ]
    field :position, as: :number
    field :ai_feedback, as: :textarea, rows: 3, hide_on: [ :index ]
    field :ai_attempts, as: :number, readonly: true, hide_on: [ :index ]

    field :created_at, as: :date_time, readonly: true, hide_on: [ :index ]
    field :updated_at, as: :date_time, readonly: true
  end
end
