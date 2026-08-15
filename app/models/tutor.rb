class Tutor < ApplicationRecord
  belongs_to :course

  # Keeps the unique index on email meaningful regardless of how it was typed.
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true,
                    uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
end
