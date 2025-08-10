class Avo::Resources::Tag < Avo::BaseResource
  self.title = :name
  self.includes = []
  self.index_query = -> { query.unscoped }
  self.record_selector = -> { record.slug.presence || record.id }

  self.search = {
    query: -> { Tag.unscoped.ransack(name_cont: params[:q]).result(distinct: false) }
  }

  # Override to find records without default scope and use FriendlyId with history support
  def self.find_record(id, **kwargs)
    # First try to find by current slug or ID
    ::Tag.unscoped.friendly.find(id)
  rescue ActiveRecord::RecordNotFound
    # If not found, try to find by historical slug
    slug_record = FriendlyId::Slug.where(sluggable_type: "Tag", slug: id).first
    if slug_record
      ::Tag.unscoped.find(slug_record.sluggable_id)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  # Handle finding multiple records for bulk actions
  def self.find_records(ids, **kwargs)
    return [] if ids.blank?

    # Handle both comma-separated string and array
    id_list = ids.is_a?(String) ? ids.split(",").map(&:strip) : ids

    # Find each record individually to support slugs
    id_list.map { |id| find_record(id, **kwargs) rescue nil }.compact
  end

  def fields
    field :id, as: :text, readonly: true
    field :name, as: :text, required: true
    field :created_at, as: :date_time, readonly: true
    field :updated_at, as: :date_time, readonly: true

    # Associations
    field :posts, as: :has_and_belongs_to_many
  end

  def actions
    action Avo::Actions::BulkDelete
  end
end
