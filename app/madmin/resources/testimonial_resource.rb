class TestimonialResource < Madmin::Resource
  def self.actions
    [ :index, :show, :edit, :update ]
  end

  attribute :id, form: false, index: false
  attribute :quote
  attribute :heading, form: false
  attribute :subheading, form: false
  attribute :body_text, form: false
  attribute :published
  attribute :position
  attribute :ai_attempts, form: false
  attribute :ai_feedback, form: false
  attribute :reject_reason, form: false
  attribute :user
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.searchable_attributes
    [ :quote, :heading ]
  end

  def self.display_name(record)
    record.heading.presence || record.quote&.truncate(60) || "Testimonial ##{record.id.first(8)}"
  end
end
