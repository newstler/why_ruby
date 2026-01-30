# frozen_string_literal: true

class SwitchToUuid7 < ActiveRecord::Migration[8.2]
  def up
    # Change default for users table
    change_column_default :users, :id, -> { "uuid7()" }

    # Change default for categories table
    change_column_default :categories, :id, -> { "uuid7()" }

    # Change default for tags table
    change_column_default :tags, :id, -> { "uuid7()" }

    # Change default for posts table
    change_column_default :posts, :id, -> { "uuid7()" }

    # Change default for comments table
    change_column_default :comments, :id, -> { "uuid7()" }

    # Change default for reports table
    change_column_default :reports, :id, -> { "uuid7()" }

    # Change default for testimonials table
    change_column_default :testimonials, :id, -> { "uuid7()" }

    # Change default for admins table
    change_column_default :admins, :id, -> { "uuid7()" }

    # Change default for active_storage_blobs table
    change_column_default :active_storage_blobs, :id, -> { "uuid7()" }

    # Change default for active_storage_attachments table
    change_column_default :active_storage_attachments, :id, -> { "uuid7()" }

    # Change default for active_storage_variant_records table
    change_column_default :active_storage_variant_records, :id, -> { "uuid7()" }
  end

  def down
    # Change back to ULID for users table
    change_column_default :users, :id, -> { "ULID()" }

    # Change back to ULID for categories table
    change_column_default :categories, :id, -> { "ULID()" }

    # Change back to ULID for tags table
    change_column_default :tags, :id, -> { "ULID()" }

    # Change back to ULID for posts table
    change_column_default :posts, :id, -> { "ULID()" }

    # Change back to ULID for comments table
    change_column_default :comments, :id, -> { "ULID()" }

    # Change back to ULID for reports table
    change_column_default :reports, :id, -> { "ULID()" }

    # Change back to ULID for testimonials table
    change_column_default :testimonials, :id, -> { "ULID()" }

    # Change back to ULID for admins table
    change_column_default :admins, :id, -> { "ULID()" }

    # Change back to ULID for active_storage_blobs table
    change_column_default :active_storage_blobs, :id, -> { "ULID()" }

    # Change back to ULID for active_storage_attachments table
    change_column_default :active_storage_attachments, :id, -> { "ULID()" }

    # Change back to ULID for active_storage_variant_records table
    change_column_default :active_storage_variant_records, :id, -> { "ULID()" }
  end
end
