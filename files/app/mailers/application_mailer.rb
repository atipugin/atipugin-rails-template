class ApplicationMailer < ActionMailer::Base
  default from: Settings.email.from
end
