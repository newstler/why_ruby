class TestimonialsController < ApplicationController
  before_action :authenticate_user!

  def create
    @testimonial = current_user.build_testimonial(testimonial_params)

    if @testimonial.save
      @processing = true
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to user_path(current_user), notice: "Your testimonial has been submitted for processing." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "testimonial_section",
            partial: "testimonials/section",
            locals: { testimonial: @testimonial, user: current_user }
          )
        end
        format.html { redirect_to user_path(current_user), alert: @testimonial.errors.full_messages.to_sentence }
      end
    end
  end

  def update
    @testimonial = current_user.testimonial

    if @testimonial.update(testimonial_params)
      @processing = @testimonial.saved_change_to_quote?
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to user_path(current_user), notice: "Your testimonial has been updated and resubmitted for processing." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "testimonial_section",
            partial: "testimonials/section",
            locals: { testimonial: @testimonial, user: current_user }
          )
        end
        format.html { redirect_to user_path(current_user), alert: @testimonial.errors.full_messages.to_sentence }
      end
    end
  end

  private

  def testimonial_params
    params.expect(testimonial: [ :quote ])
  end
end
