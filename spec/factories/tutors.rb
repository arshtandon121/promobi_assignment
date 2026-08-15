FactoryBot.define do
  factory :tutor do
    sequence(:name) { |n| "Tutor #{n}" }
    sequence(:email) { |n| "tutor#{n}@example.com" }
    course
  end
end
