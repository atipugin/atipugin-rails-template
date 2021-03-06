def source_paths
  Array(super) + [File.join(File.expand_path(File.dirname(__FILE__)), 'files')]
end

def ask_with_default_yes(question)
  answer = ask question
  %w(n N no No).include?(answer) ? false : true
end

def ask_with_default_no(question)
  answer = ask question
  %w(y Y yes Yes).include?(answer)
end

# Ask about optional stuff
install_devise = ask_with_default_yes('Install Devise? [Y/n]')
install_sidekiq = ask_with_default_no('Install Sidekiq? [Y/n]')

# Add proper .gitignore
remove_file '.gitignore'
copy_file 'gitignore.example', '.gitignore'

# Define Ruby version in Gemfile
prepend_to_file 'Gemfile', "ruby '2.1.3'\n"

# Comment out unused default gems
unused_gems = %w(turbolinks jbuilder sdoc byebug web-console)
comment_lines 'Gemfile', /(gem.*(#{unused_gems.join('|')}))/

# Declare gems to install
gem 'annotate'
gem 'autoprefixer-rails'
gem 'bootstrap-sass'
gem 'devise' if install_devise
gem 'jquery-rails-cdn'
gem 'meta-tags'
gem 'premailer-rails'
gem 'pry-rails'
gem 'rails_config'
gem 'russian'
gem 'slim-rails'
gem 'unicorn'

if install_sidekiq
  gem 'sidekiq'
  gem 'sinatra', '>= 1.3.0', require: false
end

gem_group :development, :test do
  gem 'factory_girl_rails'
  gem 'ffaker'
  gem 'rspec-rails'
end

gem_group :development do
  gem 'brakeman', require: false
  gem 'foreman'
  gem 'guard-rspec', require: false
  gem 'i18n-tasks'
  gem 'rubocop', require: false
end

gem_group :test do
  gem 'capybara'
  gem 'database_cleaner'
end

# Install gems
run_bundle

# Copy config examples
directory 'config/examples'
directory 'config/examples', 'config'

# Remove unused configs
inside 'config' do
  unless install_sidekiq
    remove_file 'sidekiq.yml'
    remove_file 'examples/sidekiq.yml'
  end
end

# Install rspec
generate 'rspec:install'

# Install database_cleaner
inside 'spec' do
  gsub_file 'rails_helper.rb',
            /(config.use_transactional_fixtures).*/,
            '\1 = false'

  insert_into_file 'rails_helper.rb', after: "config.infer_spec_type_from_file_location!\n" do
    <<-EOS

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
    EOS
  end
end

# Install factory_girl_rails
inside 'spec' do
  insert_into_file 'rails_helper.rb', after: "RSpec.configure do |config|\n" do
    <<-EOS
  include FactoryGirl::Syntax::Methods

    EOS
  end

  comment_lines 'rails_helper.rb', /config.fixture_path/
end

# Install guard-rspec
run 'bundle exec guard init rspec'

# Install rubocop
run 'bundle exec rubocop app --rails --auto-gen-config'
create_file '.rubocop.yml' do
  <<-EOS
inherit_from: .rubocop_todo.yml
AllCops:
  Exclude:
    - spec/rails_helper.rb
    - spec/spec_helper.rb
  EOS
end

insert_into_file 'Rakefile', after: "Rails.application.load_tasks\n" do
  <<-EOS

if %w(development test).include?(Rails.env)
  require 'rubocop/rake_task'

  RuboCop::RakeTask.new(:rubocop) do |task|
    task.fail_on_error = false
    task.options = %w(--rails --force-exclusion)
    task.patterns = %w(app/**/*.rb lib/**/*.rb spec/**/*.rb)
  end

  task(:default).clear
  task default: [:spec, :rubocop]
end
  EOS
end

# Install i18n-tasks
run 'cp $(bundle show i18n-tasks)/templates/config/i18n-tasks.yml config/'
create_file 'lib/tasks/i18n.rake' do
  <<-EOS
namespace :i18n do
  task normalize: :environment do
    `bundle exec i18n-tasks normalize`
  end

  task health: :environment do
    `bundle exec i18n-tasks health`
  end
end

task i18n: %w(i18n:normalize i18n:health)
  EOS
end

# Install foreman
create_file 'Procfile'

# Install unicorn
append_to_file 'Procfile',
               "unicorn: bundle exec unicorn -c ./config/unicorn.rb -p $PORT\n"

# Install russian
inside 'config' do
  uncomment_lines 'application.rb', /config.i18n.(load_path|default_locale)/
  gsub_file 'application.rb',
            /(config.i18n.load_path).*/,
            %q{\1 += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]}
  gsub_file 'application.rb', /(config.i18n.default_locale).*/, '\1 = :ru'

  uncomment_lines 'application.rb', /config.time_zone/
  gsub_file 'application.rb', /(config.time_zone).*/, %q{\1 = 'Moscow'}

  gsub_file 'i18n-tasks.yml', /(base_locale).*/, '\1: ru'
  uncomment_lines 'i18n-tasks.yml', /.*config\/locales\/\*\.\%\{locale\}\.yml/
  gsub_file 'i18n-tasks.yml',
            /(.*config\/locales)\/\*\.\%\{locale\}\.yml/,
            '\1/**/*/%{locale}.yml'

  uncomment_lines 'environments/development.rb',
                  /config.action_view.raise_on_missing_translations = true/

  inside 'locales' do
    run 'rm -f en.yml'
    create_file 'ru.yml' do
      <<-EOS
ru:
  app_name: #{app_name.titleize}
      EOS
    end
  end
end

run 'bundle exec rake i18n'

# Install annotate
generate 'annotate:install'

# Install rails_config
create_file 'config/settings.yml'

# Configure ActionMailer
inside 'config' do
  append_to_file 'settings.yml' do
    <<-EOS
email:
  default_url_options:
    host: localhost:5000
  from: #{app_name.titleize} <no-reply@localhost>
  smtp_settings:
    address: localhost
    port: 1025
    EOS
  end

  insert_into_file 'application.rb', after: "config.active_record.raise_in_transactional_callbacks = true\n" do
    <<-EOS

    config.action_mailer.default_url_options = Settings.email.default_url_options.to_h
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = Settings.email.smtp_settings.to_h
    EOS
  end

  gsub_file 'environments/development.rb',
            /(config.action_mailer.raise_delivery_errors).*/, '\1 = true'
end

directory 'app/mailers'

# Disable annoying generators
insert_into_file 'config/application.rb', after: "config.action_mailer.smtp_settings = Settings.email.smtp_settings.to_h\n" do
  <<-EOS

    config.generators do |g|
      g.assets false
      g.controller_specs false
      g.helper false
      g.view_specs false
    end
  EOS
end

# Add welcome page
generate :controller, 'welcome', 'index', '--skip-routes'
uncomment_lines 'config/routes.rb', /root 'welcome#index'/

# Install jquery-rails-cdn
inside 'config/initializers' do
  uncomment_lines 'assets.rb', /Rails.application.config.assets.precompile/
  gsub_file 'assets.rb',
            /(Rails.application.config.assets.precompile).*/,
            '\1 += %w(jquery.js)'
end

# Manage layout stuff
inside 'app' do
  inside 'assets' do
    inside 'javascripts' do
      remove_file 'application.js'
      copy_file 'application.js.coffee'
    end

    inside 'stylesheets' do
      remove_file 'application.css'
      copy_file '_bootstrap-variables.css.scss'
      copy_file 'application.css.scss'

      # Create custom Bootstrap import file
      path = run('bundle show bootstrap-sass', capture: true).chomp
      lines = []
      File.read(File.join(path, 'assets', 'stylesheets', '_bootstrap.scss'))
        .each_line do |line|
          line.prepend('// ') if line.chomp.present? && line !~ /^\/\/.*/
          lines << line
        end

      create_file '_bootstrap-custom.css.scss', lines.join
    end
  end

  inside 'helpers' do
    copy_file 'body_class_helper.rb'
    copy_file 'class_set_helper.rb'
  end

  inside 'views' do
    inside 'layouts' do
      remove_file 'application.html.erb'
      copy_file 'application.html.slim'
    end

    directory 'shared'
  end
end

# Install devise
if install_devise
  generate 'devise:install'
  inside 'config' do
    inside 'locales' do
      remove_file 'devise.en.yml'
      directory 'devise'
    end

    inside 'initializers' do
      comment_lines 'devise.rb', /config.mailer_sender/
      uncomment_lines 'devise.rb', /(config.mailer = ).*\n/
      gsub_file 'devise.rb',
                /(config.mailer = ).*\n/,
                "config.parent_mailer = 'ApplicationMailer'\n"

      gsub_file 'devise.rb', /(config.password_length).*/, '\1 = 6..128'
    end

    uncomment_lines 'i18n-tasks.yml', /ignore_unused:/
    uncomment_lines 'i18n-tasks.yml', /- '{devise,kaminari,will_paginate}.*'/
    insert_into_file 'i18n-tasks.yml', after: "ignore_unused:\n" do
      <<-EOS
- errors.*
      EOS
    end
  end
end

# Install sidekiq
if install_sidekiq
  inside 'config' do
    append_to_file 'settings.yml' do
      <<-EOS

redis:
  namespace: #{app_name}
      EOS
    end

    copy_file 'initializers/sidekiq.rb'

    insert_into_file 'routes.rb', before: "Rails.application.routes.draw do\n" do
      <<-EOS
require 'sidekiq/web'

      EOS
    end

    insert_into_file 'routes.rb', after: "Rails.application.routes.draw do\n" do
      <<-EOS
  mount Sidekiq::Web => '/sidekiq'

      EOS
    end
  end

  append_to_file 'Procfile',
                 "sidekiq: bundle exec sidekiq -C ./config/sidekiq.yml\n"
end

# Install premailer-rails
initializer 'premailer_rails.rb', <<-EOS
Premailer::Rails.config.merge!(generate_text_part: false)
EOS
