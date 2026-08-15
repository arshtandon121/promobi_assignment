require "rails_helper"

RSpec.describe Tutor, type: :model do
  describe "associations" do
    it "belongs to a course" do
      tutor = create(:tutor)

      expect(tutor.course).to be_a(Course)
    end

    it "is invalid without a course" do
      tutor = build(:tutor, course: nil)

      expect(tutor).not_to be_valid
      expect(tutor.errors[:course]).to include("must exist")
    end

    it "teaches only the course it belongs to" do
      first_course = create(:course)
      second_course = create(:course)
      tutor = create(:tutor, course: first_course)

      tutor.update!(course: second_course)

      expect(tutor.reload.course).to eq(second_course)
      expect(first_course.tutors).to be_empty
    end
  end

  describe "validations" do
    it "is valid with a name, an email and a course" do
      expect(build(:tutor)).to be_valid
    end

    it "is invalid without a name" do
      tutor = build(:tutor, name: nil)

      expect(tutor).not_to be_valid
      expect(tutor.errors[:name]).to include("can't be blank")
    end

    it "is invalid without an email" do
      tutor = build(:tutor, email: nil)

      expect(tutor).not_to be_valid
      expect(tutor.errors[:email]).to include("can't be blank")
    end

    it "is invalid with a malformed email" do
      tutor = build(:tutor, email: "arshdeep-at-example.com")

      expect(tutor).not_to be_valid
      expect(tutor.errors[:email]).to include("is invalid")
    end

    it "is invalid when the email is already taken, ignoring case" do
      create(:tutor, email: "arshdeep@example.com")
      tutor = build(:tutor, email: "ARSHDEEP@example.com")

      expect(tutor).not_to be_valid
      expect(tutor.errors[:email]).to include("has already been taken")
    end
  end
end
