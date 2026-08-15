require "rails_helper"

RSpec.describe Course, type: :model do
  describe "associations" do
    it "has many tutors" do
      course = create(:course, :with_tutors, tutors_count: 3)

      expect(course.tutors.count).to eq(3)
    end

    it "removes its tutors when it is destroyed" do
      course = create(:course, :with_tutors, tutors_count: 2)

      expect { course.destroy }.to change(Tutor, :count).by(-2)
    end
  end

  describe "validations" do
    it "is valid with a name" do
      expect(build(:course)).to be_valid
    end

    it "is invalid without a name" do
      course = build(:course, name: nil)

      expect(course).not_to be_valid
      expect(course.errors[:name]).to include("can't be blank")
    end
  end

  describe "nested tutors" do
    it "creates tutors passed as tutors_attributes" do
      course = Course.new(
        name: "Advanced Ruby",
        tutors_attributes: [
          { name: "Arshdeep", email: "arshdeep@example.com" },
          { name: "Neha", email: "neha@example.com" }
        ]
      )

      expect { course.save! }.to change(Tutor, :count).by(2)
      expect(course.tutors.map(&:name)).to contain_exactly("Arshdeep", "Neha")
    end

    it "saves the course and its tutors in a single transaction" do
      course = Course.new(
        name: "Advanced Ruby",
        tutors_attributes: [
          { name: "Arshdeep", email: "arshdeep@example.com" },
          { name: "Neha", email: "not-an-email" }
        ]
      )

      expect(course.save).to be(false)
      expect(Course.count).to eq(0)
      expect(Tutor.count).to eq(0)
    end
  end
end
