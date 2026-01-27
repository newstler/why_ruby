# # This file should ensure the existence of records required to run the application in every environment (production,
# # development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# # The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# # Create categories
# categories = [
#   {
#     name: "Getting Started",
#     position: 1,
#     description: "Begin your Ruby journey here. Find tutorials, setup guides, and beginner-friendly resources to help you write your first Ruby code."
#   },
#   {
#     name: "Ruby Language",
#     position: 2,
#     description: "Explore the beauty and power of Ruby. Learn about syntax, idioms, and language features that make Ruby a joy to write."
#   },
#   {
#     name: "Rails Framework",
#     position: 3,
#     description: "Master Ruby on Rails, the framework that revolutionized web development. Discover tips, patterns, and best practices for building modern web applications."
#   },
#   {
#     name: "Best Practices",
#     position: 4,
#     description: "Write clean, maintainable, and elegant Ruby code. Learn from experienced developers about testing, refactoring, and design patterns."
#   },
#   {
#     name: "Community",
#     position: 5,
#     description: "Connect with passionate Ruby developers from around the world. Explore their projects, contributions, and insights."
#   },
#   {
#     name: "Tools & Libraries",
#     position: 6,
#     description: "Discover powerful gems, development tools, and libraries that enhance your Ruby development experience and productivity."
#   },
#   {
#     name: "Success Stories",
#     position: 7,
#     description: "Read inspiring stories from companies and developers who chose Ruby. Learn how Ruby powered their growth and success."
#   },
#   {
#     name: "Performance",
#     position: 8,
#     description: "Optimize your Ruby applications for speed and efficiency. Learn profiling techniques, performance tips, and scaling strategies."
#   }
# ]

# categories.each do |cat|
#   category = Category.find_or_create_by(name: cat[:name]) do |c|
#     c.position = cat[:position]
#     c.description = cat[:description]
#   end

#   # Update description if it doesn't exist
#   if category.description.blank? && cat[:description].present?
#     category.update(description: cat[:description])
#   end
# end

# puts "Created #{Category.count} categories"

# # Create tags
# tags = [
#   "beginner", "advanced", "tutorial", "tips", "rails", "ruby",
#   "testing", "deployment", "gems", "api", "frontend", "backend",
#   "database", "security", "performance", "refactoring", "design-patterns",
#   "news", "best-practices"
# ]

# tags.each do |tag_name|
#   Tag.find_or_create_by(name: tag_name)
# end

# puts "Created #{Tag.count} tags"

# # Create a test admin user (you'll need to sign in with GitHub in production)
# admin = User.find_or_create_by!(email: "admin@example.com") do |u|
#   u.username = "admin"
#   u.github_id = 12345
#   u.role = :admin
#   u.avatar_url = "https://avatars.githubusercontent.com/u/12345?v=4"
# end

# puts "Created admin user: #{admin.username} (ID: #{admin.id})"

# # Ensure admin is properly saved
# if admin.persisted?
#   puts "Admin user exists with ID: #{admin.id}"
# else
#   puts "Failed to create admin user: #{admin.errors.full_messages.join(', ')}"
#   exit 1
# end

# # Create some sample posts
# if Post.count < 5
#   post1 = Post.create!(
#     user: admin,
#     category: Category.find_by(name: "Getting Started"),
#     title: "Why Ruby? A Beginner's Perspective",
#     content: "# Why Ruby?\n\nRuby is a dynamic, open source programming language with a focus on simplicity and productivity. It has an elegant syntax that is natural to read and easy to write.\n\n## Key Features\n\n- **Developer Happiness**: Ruby is designed to make programmers happy\n- **Readable Syntax**: Code that reads like English\n- **Object-Oriented**: Everything is an object\n- **Dynamic Typing**: Flexible and expressive\n\n```ruby\n# Hello World in Ruby\nputs 'Hello, World!'\n\n# Creating a class\nclass Greeting\n  def initialize(name)\n    @name = name\n  end\n  \n  def say_hello\n    puts \"Hello, #{@name}!\"\n  end\nend\n\ngreeting = Greeting.new('Ruby')\ngreeting.say_hello\n```",
#     published: true,
#     pin_position: 1
#   )
#   post1.tags << Tag.find_by(name: "beginner")
#   post1.tags << Tag.find_by(name: "ruby")

#   post2 = Post.create!(
#     user: admin,
#     category: Category.find_by(name: "Rails Framework"),
#     title: "Rails 8.1: The Latest and Greatest",
#     url: "https://rubyonrails.org/2024/11/7/rails-8-1-has-been-released",
#     published: true,
#     pin_position: 2
#   )
#   post2.tags << Tag.find_by(name: "rails")
#   post2.tags << Tag.find_by(name: "news")

#   post3 = Post.create!(
#     user: admin,
#     category: Category.find_by(name: "Best Practices"),
#     title: "SOLID Principles in Ruby",
#     content: "# SOLID Principles in Ruby\n\nSOLID is a mnemonic acronym for five design principles intended to make software designs more understandable, flexible, and maintainable.\n\n## Single Responsibility Principle\n\nA class should have one, and only one, reason to change.\n\n```ruby\n# Bad\nclass User\n  def initialize(name, email)\n    @name = name\n    @email = email\n  end\n  \n  def send_email(message)\n    # Email sending logic\n  end\n  \n  def save_to_database\n    # Database logic\n  end\nend\n\n# Good\nclass User\n  attr_reader :name, :email\n  \n  def initialize(name, email)\n    @name = name\n    @email = email\n  end\nend\n\nclass UserMailer\n  def send_email(user, message)\n    # Email sending logic\n  end\nend\n\nclass UserRepository\n  def save(user)\n    # Database logic\n  end\nend\n```",
#     published: true
#   )
#   post3.tags << Tag.find_by(name: "best-practices")
#   post3.tags << Tag.find_by(name: "design-patterns")

#   puts "Created sample posts"
# end

# Seed testimonials (pre-published, no AI processing needed)
if Testimonial.count == 0
  # Need at least 4 users for testimonials
  seed_users = []
  [
    { username: "matz", email: "matz@ruby-lang.org", github_id: "100001", name: "Yukihiro Matsumoto", bio: "Creator of Ruby", avatar_url: "https://avatars.githubusercontent.com/u/30281?v=4" },
    { username: "dhh", email: "dhh@hey.com", github_id: "100002", name: "David Heinemeier Hansson", bio: "Creator of Ruby on Rails", company: "37signals", avatar_url: "https://avatars.githubusercontent.com/u/2741?v=4" },
    { username: "tenderlove", email: "tenderlove@ruby-lang.org", github_id: "100003", name: "Aaron Patterson", bio: "Ruby & Rails core team", company: "Shopify", avatar_url: "https://avatars.githubusercontent.com/u/3124?v=4" },
    { username: "eileencodes", email: "eileencodes@github.com", github_id: "100004", name: "Eileen Uchitelle", bio: "Rails core team", company: "GitHub", avatar_url: "https://avatars.githubusercontent.com/u/2381?v=4" }
  ].each do |attrs|
    user = User.find_or_create_by!(github_id: attrs[:github_id]) do |u|
      u.username = attrs[:username]
      u.email = attrs[:email]
      u.name = attrs[:name]
      u.bio = attrs[:bio]
      u.company = attrs[:company]
      u.avatar_url = attrs[:avatar_url]
    end
    seed_users << user
  end

  testimonials_data = [
    {
      user: seed_users[0],
      quote: "Ruby is simple in appearance, but is very complex inside, just like our human body.",
      heading: "Ecosystem",
      subheading: "A language that grows with you",
      body_text: "Ruby's rich ecosystem of gems and tools means you can build almost anything. From web applications to automation scripts, the community has created solutions for every need.",
      published: true,
      position: 1
    },
    {
      user: seed_users[1],
      quote: "Ruby on Rails has made building web applications a joy. The convention over configuration philosophy lets me focus on what matters — creating value.",
      heading: "Simplicity",
      subheading: "Beautiful code that reads like prose",
      body_text: "Ruby's elegant syntax makes code a pleasure to read and write. It prioritizes developer happiness, letting you express ideas naturally without fighting the language.",
      published: true,
      position: 2
    },
    {
      user: seed_users[2],
      quote: "I love Ruby because it lets me be creative. Writing Ruby feels like having a conversation with the computer rather than issuing commands.",
      heading: "Productivity",
      subheading: "Ship faster, iterate quicker",
      body_text: "Ruby and Rails together form an incredibly productive stack. What takes weeks in other languages can be built in days, without sacrificing code quality or maintainability.",
      published: true,
      position: 3
    },
    {
      user: seed_users[3],
      quote: "The Ruby community is one of the most welcoming in all of tech. MINASWAN isn't just a saying — it's how we build software together.",
      heading: "Community",
      subheading: "Matz is nice and so we are nice",
      body_text: "Ruby's community stands out for its warmth and inclusivity. From RubyConf to local meetups, Ruby developers support each other and welcome newcomers with open arms.",
      published: true,
      position: 4
    }
  ]

  testimonials_data.each do |data|
    user = data.delete(:user)
    now = Time.current
    # Use insert_all to skip callbacks (avoid AI processing for seeds)
    Testimonial.insert_all([ data.merge(user_id: user.id, ai_attempts: 0, created_at: now, updated_at: now) ])
  end

  puts "Created #{Testimonial.count} testimonials"
end
