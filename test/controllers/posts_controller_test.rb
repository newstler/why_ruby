require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:user_with_testimonial)
    @other_user = users(:user_without_testimonial)
    @admin = users(:admin_user)
    @category = categories(:general)
    @published_post = posts(:published_article)
    @unpublished_post = posts(:unpublished_article)
    @other_users_post = posts(:other_users_post)
  end

  # -------------------------------------------------------------------------
  # Authorization: edit
  # -------------------------------------------------------------------------

  test "owner can access edit for their post" do
    sign_in @owner
    get edit_post_path(@published_post)
    assert_response :success
  end

  test "other user cannot edit someone else's post" do
    sign_in @other_user
    get edit_post_path(@published_post)
    assert_redirected_to root_path
  end

  test "admin can edit any post" do
    sign_in @admin
    get edit_post_path(@other_users_post)
    assert_response :success
  end

  test "unauthenticated user is redirected when editing" do
    get edit_post_path(@published_post)
    assert_response :redirect
  end

  # -------------------------------------------------------------------------
  # Authorization: destroy
  # -------------------------------------------------------------------------

  test "owner can destroy their own post" do
    sign_in @owner
    assert_difference "Post.count", -1 do
      delete post_destroy_path(@published_post)
    end
  end

  test "other user cannot destroy someone else's post" do
    sign_in @other_user
    assert_no_difference "Post.count" do
      delete post_destroy_path(@published_post)
    end
    assert_redirected_to root_path
  end

  test "admin can destroy any post" do
    sign_in @admin
    assert_difference "Post.count", -1 do
      delete post_destroy_path(@other_users_post)
    end
  end

  # -------------------------------------------------------------------------
  # Authorization: create
  # -------------------------------------------------------------------------

  test "unauthenticated user cannot create a post" do
    assert_no_difference "Post.count" do
      post posts_path, params: {
        post: {
          title: "New Post", content: "Content here.",
          post_type: "article", category_id: @category.id
        }
      }
    end
    assert_response :redirect
  end

  # -------------------------------------------------------------------------
  # Show: published/unpublished visibility
  # -------------------------------------------------------------------------

  test "published post is visible to any visitor" do
    get post_path(@published_post.category, @published_post)
    assert_response :success
  end

  test "unpublished post is visible to its owner" do
    sign_in @owner
    get post_path(@unpublished_post.category, @unpublished_post)
    assert_response :success
  end

  test "unpublished post redirects other logged-in users" do
    sign_in @other_user
    get post_path(@unpublished_post.category, @unpublished_post)
    assert_redirected_to root_path
  end

  test "unpublished post redirects unauthenticated visitors" do
    get post_path(@unpublished_post.category, @unpublished_post)
    assert_redirected_to root_path
  end

  test "admin can view unpublished posts" do
    sign_in @admin
    get post_path(@unpublished_post.category, @unpublished_post)
    assert_response :success
  end
end
