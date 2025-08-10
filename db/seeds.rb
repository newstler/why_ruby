# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create categories
categories = [
  { 
    name: "Getting Started", 
    position: 1,
    description: "Begin your Ruby journey here. Find tutorials, setup guides, and beginner-friendly resources to help you write your first Ruby code."
  },
  { 
    name: "Ruby Language", 
    position: 2,
    description: "Explore the beauty and power of Ruby. Learn about syntax, idioms, and language features that make Ruby a joy to write."
  },
  { 
    name: "Rails Framework", 
    position: 3,
    description: "Master Ruby on Rails, the framework that revolutionized web development. Discover tips, patterns, and best practices for building modern web applications."
  },
  { 
    name: "Best Practices", 
    position: 4,
    description: "Write clean, maintainable, and elegant Ruby code. Learn from experienced developers about testing, refactoring, and design patterns."
  },
  { 
    name: "Community", 
    position: 5,
    description: "Connect with passionate Ruby developers from around the world. Explore their projects, contributions, and insights."
  },
  { 
    name: "Tools & Libraries", 
    position: 6,
    description: "Discover powerful gems, development tools, and libraries that enhance your Ruby development experience and productivity."
  },
  { 
    name: "Success Stories", 
    position: 7,
    description: "Read inspiring stories from companies and developers who chose Ruby. Learn how Ruby powered their growth and success."
  },
  { 
    name: "Performance", 
    position: 8,
    description: "Optimize your Ruby applications for speed and efficiency. Learn profiling techniques, performance tips, and scaling strategies."
  }
]

categories.each do |cat|
  category = Category.find_or_create_by(name: cat[:name]) do |c|
    c.position = cat[:position]
    c.description = cat[:description]
  end
  
  # Update description if it doesn't exist
  if category.description.blank? && cat[:description].present?
    category.update(description: cat[:description])
  end
end

puts "Created #{Category.count} categories"

# Create tags
tags = [
  "beginner", "advanced", "tutorial", "tips", "rails", "ruby", 
  "testing", "deployment", "gems", "api", "frontend", "backend",
  "database", "security", "performance", "refactoring", "design-patterns",
  "news", "best-practices"
]

tags.each do |tag_name|
  Tag.find_or_create_by(name: tag_name)
end

puts "Created #{Tag.count} tags"

# Create a test admin user (you'll need to sign in with GitHub in production)
admin = User.find_or_create_by(email: "admin@example.com") do |u|
  u.username = "admin"
  u.github_id = 12345
  u.role = :admin
  u.avatar_url = "https://avatars.githubusercontent.com/u/12345?v=4"
end

puts "Created admin user: #{admin.username}"

# Create some sample posts
if Post.count < 5
  post1 = Post.create!(
    user: admin,
    category: Category.find_by(name: "Getting Started"),
    title: "Why Ruby? A Beginner's Perspective",
    content: "# Why Ruby?\n\nRuby is a dynamic, open source programming language with a focus on simplicity and productivity. It has an elegant syntax that is natural to read and easy to write.\n\n## Key Features\n\n- **Developer Happiness**: Ruby is designed to make programmers happy\n- **Readable Syntax**: Code that reads like English\n- **Object-Oriented**: Everything is an object\n- **Dynamic Typing**: Flexible and expressive\n\n```ruby\n# Hello World in Ruby\nputs 'Hello, World!'\n\n# Creating a class\nclass Greeting\n  def initialize(name)\n    @name = name\n  end\n  \n  def say_hello\n    puts \"Hello, #{@name}!\"\n  end\nend\n\ngreeting = Greeting.new('Ruby')\ngreeting.say_hello\n```",
    published: true,
    pin_position: 1
  )
  post1.tags << Tag.find_by(name: "beginner")
  post1.tags << Tag.find_by(name: "ruby")
  
  post2 = Post.create!(
    user: admin,
    category: Category.find_by(name: "Rails Framework"),
    title: "Rails 8.1: The Latest and Greatest",
    url: "https://rubyonrails.org/2024/11/7/rails-8-1-has-been-released",
    published: true,
    pin_position: 2
  )
  post2.tags << Tag.find_by(name: "rails")
  post2.tags << Tag.find_by(name: "news")
  
  post3 = Post.create!(
    user: admin,
    category: Category.find_by(name: "Best Practices"),
    title: "SOLID Principles in Ruby",
    content: "# SOLID Principles in Ruby\n\nSOLID is a mnemonic acronym for five design principles intended to make software designs more understandable, flexible, and maintainable.\n\n## Single Responsibility Principle\n\nA class should have one, and only one, reason to change.\n\n```ruby\n# Bad\nclass User\n  def initialize(name, email)\n    @name = name\n    @email = email\n  end\n  \n  def send_email(message)\n    # Email sending logic\n  end\n  \n  def save_to_database\n    # Database logic\n  end\nend\n\n# Good\nclass User\n  attr_reader :name, :email\n  \n  def initialize(name, email)\n    @name = name\n    @email = email\n  end\nend\n\nclass UserMailer\n  def send_email(user, message)\n    # Email sending logic\n  end\nend\n\nclass UserRepository\n  def save(user)\n    # Database logic\n  end\nend\n```",
    published: true
  )
  post3.tags << Tag.find_by(name: "best-practices")
  post3.tags << Tag.find_by(name: "design-patterns")
  
  puts "Created sample posts"
end
