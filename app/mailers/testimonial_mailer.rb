class TestimonialMailer < ApplicationMailer
  def invitation(user)
    @user = user
    @profile_url = user_url(@user)

    mail(to: @user.email, subject: "Share why you love Ruby!")
  end
end
