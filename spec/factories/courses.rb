FactoryBot.define do
  factory :course do
    sequence(:name) { |n| "Ruby on Rails Fundamentals #{n}" }
    description { "Build and ship web applications with Ruby on Rails" }

    trait :with_tutors do
      transient do
        tutors_count { 2 }
      end

      after(:create) do |course, evaluator|
        create_list(:tutor, evaluator.tutors_count, course: course)
      end
    end
  end
end
