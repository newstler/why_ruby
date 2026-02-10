namespace :github do
  desc "Update GitHub data for all users using the UpdateGithubDataJob"
  task update_all_job: :environment do
    puts "Starting GitHub data update job for all users..."
    UpdateGithubDataJob.perform_now
    puts "Job completed. Check logs for details."
  end
end
