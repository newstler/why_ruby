class Avo::Resources::Project < Avo::BaseResource
  self.title = :name
  self.includes = [ :user, :star_snapshots ]
  self.model_class = ::Project
  self.description = "Manage GitHub projects (repositories) for users"
  self.default_view_type = :table

  self.search = {
    query: -> { Project.ransack(name_cont: params[:q], github_url_cont: params[:q], m: "or").result(distinct: false) }
  }

  def fields
    field :id, as: :text, readonly: true, hide_on: [ :index ]

    field :name, as: :text, link_to_record: true

    field :user, as: :belongs_to,
      only_on: [ :forms, :show ]

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

    field :stars, as: :number, only_on: [ :forms, :show ]
    field :stars_with_trend,
      as: :text,
      name: "Stars",
      only_on: [ :index ],
      sortable: -> { query.order(stars: direction) },
      format_using: -> do
        gained = record.stars_gained
        trend = gained > 0 ? content_tag(:span, " +#{gained}", class: "text-green-600") : ""
        safe_join([ record.stars.to_s, trend ])
      end
    field :github_url, as: :text, only_on: [ :forms ]
    field :github_url, as: :text, name: "GitHub", only_on: [ :index ],
      format_using: -> do
        if value.present?
          repo_name = value.split("/").last(2).join("/")
          link_to(repo_name, value, target: "_blank", class: "text-blue-600 hover:underline")
        else
          content_tag(:span, "-", class: "text-gray-400")
        end
      end
    field :github_url, as: :text, only_on: [ :show ],
      format_using: -> { link_to(value, value, target: "_blank", class: "text-blue-600 hover:underline") if value.present? }

    field :description, as: :textarea, hide_on: [ :index ], rows: 3
    field :forks_count, as: :number, hide_on: [ :index ]
    field :size, as: :number, hide_on: [ :index ]
    field :topics, as: :text, hide_on: [ :index ],
      format_using: -> { value.is_a?(Array) ? value.join(", ") : value.to_s }

    field :hidden, as: :boolean
    field :archived, as: :boolean

    field :pushed_at, as: :date_time, readonly: true, hide_on: [ :index ]
    field :created_at, as: :date_time, readonly: true, hide_on: [ :index ]
    field :updated_at, as: :date_time, readonly: true

    field :star_snapshots, as: :has_many, hide_on: [ :index ]
  end
end
