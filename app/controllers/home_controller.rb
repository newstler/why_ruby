class HomeController < ApplicationController
  def index
    @pinned_posts = Post.published.pinned
                          .where.not(post_type: "success_story")
                          .includes(:user, :category, :tags)
                          .reorder(:pin_position)
    @posts = Post.published
                      .where.not(post_type: "success_story")
                      .includes(:user, :category, :tags)
                      .page(params[:page])
                      .per(20)
    @success_stories = Post.success_stories
                           .published
                           .includes(:user)
                           .order(created_at: :desc)
    subquery = Testimonial.published
      .select("testimonials.*", "ROW_NUMBER() OVER (PARTITION BY LOWER(heading) ORDER BY RANDOM()) AS rn")
    @testimonials = Testimonial
      .from(subquery, :testimonials)
      .where("rn = 1")
      .order(Arel.sql("RANDOM()"))
      .limit(10)
      .includes(:user)
  end
end
