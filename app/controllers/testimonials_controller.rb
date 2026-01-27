class TestimonialsController < ApplicationController
  before_action :authenticate_user!

  def create
    @testimonial = current_user.build_testimonial(testimonial_params)

    if @testimonial.save
      redirect_to user_path(current_user), notice: "Your testimonial has been submitted for processing."
    else
      redirect_to user_path(current_user), alert: @testimonial.errors.full_messages.to_sentence
    end
  end

  def update
    @testimonial = current_user.testimonial

    if @testimonial.update(testimonial_params)
      redirect_to user_path(current_user), notice: "Your testimonial has been updated and resubmitted for processing."
    else
      redirect_to user_path(current_user), alert: @testimonial.errors.full_messages.to_sentence
    end
  end

  private

  def testimonial_params
    params.expect(testimonial: [ :quote ])
  end
end
