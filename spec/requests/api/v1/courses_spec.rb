require "rails_helper"

RSpec.describe "Api::V1::Courses", type: :request do
  describe "POST /api/v1/courses" do
    let(:payload) do
      {
        course: {
          name: "Ruby on Rails Fundamentals",
          description: "Build and ship web applications with Rails",
          tutors_attributes: [
            { name: "Arshdeep", email: "arshdeep@example.com" },
            { name: "Neha", email: "neha@example.com" }
          ]
        }
      }
    end

    it "creates the course and its tutors in a single request" do
      expect {
        post "/api/v1/courses", params: payload, as: :json
      }.to change(Course, :count).by(1).and change(Tutor, :count).by(2)

      expect(response).to have_http_status(:created)
    end

    it "returns the created course with its tutors" do
      post "/api/v1/courses", params: payload, as: :json

      body = response.parsed_body

      expect(body["id"]).to be_present
      expect(body["name"]).to eq("Ruby on Rails Fundamentals")
      expect(body["description"]).to eq("Build and ship web applications with Rails")
      expect(body["tutors"].map { |tutor| tutor["email"] })
        .to contain_exactly("arshdeep@example.com", "neha@example.com")
    end

    it "exposes only the documented fields" do
      post "/api/v1/courses", params: payload, as: :json

      body = response.parsed_body

      expect(body.keys).to contain_exactly("id", "name", "description", "tutors")
      expect(body["tutors"].first.keys).to contain_exactly("id", "name", "email")
    end

    it "creates a course that has no tutors yet" do
      expect {
        post "/api/v1/courses", params: { course: { name: "Standalone Course" } }, as: :json
      }.to change(Course, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["tutors"]).to eq([])
    end
  end

  describe "GET /api/v1/courses" do
    it "returns every course along with its tutors" do
      rails_course = create(:course, name: "Rails")
      create(:tutor, name: "Arshdeep", email: "arshdeep@example.com", course: rails_course)
      create(:course, name: "Postgres")

      get "/api/v1/courses"

      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body.map { |course| course["name"] }).to contain_exactly("Rails", "Postgres")

      serialized_rails = body.find { |course| course["name"] == "Rails" }
      expect(serialized_rails["tutors"].map { |tutor| tutor["name"] }).to eq([ "Arshdeep" ])

      serialized_postgres = body.find { |course| course["name"] == "Postgres" }
      expect(serialized_postgres["tutors"]).to eq([])
    end

    it "returns an empty list when there are no courses" do
      get "/api/v1/courses"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end
end
