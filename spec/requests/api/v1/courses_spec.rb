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

  describe "POST /api/v1/courses with invalid data" do
    it "rejects a course without a name" do
      expect {
        post "/api/v1/courses", params: { course: { description: "No name given" } }, as: :json
      }.not_to change(Course, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Name can't be blank")
    end

    it "rejects the whole request when one tutor is invalid" do
      payload = {
        course: {
          name: "Ruby on Rails Fundamentals",
          tutors_attributes: [
            { name: "Arshdeep", email: "arshdeep@example.com" },
            { name: "Neha", email: "not-an-email" }
          ]
        }
      }

      post "/api/v1/courses", params: payload, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].join).to match(/email/i)
    end

    it "leaves no orphaned course behind when a tutor is invalid" do
      payload = {
        course: {
          name: "Ruby on Rails Fundamentals",
          tutors_attributes: [
            { name: "Arshdeep", email: "arshdeep@example.com" },
            { name: "Neha", email: "not-an-email" }
          ]
        }
      }

      expect {
        post "/api/v1/courses", params: payload, as: :json
      }.not_to change(Course, :count)

      expect(Course.count).to be_zero
      expect(Tutor.count).to be_zero
    end

    it "rejects a tutor whose email is already taken" do
      create(:tutor, email: "arshdeep@example.com")

      payload = {
        course: {
          name: "Another Course",
          tutors_attributes: [ { name: "Arshdeep", email: "ARSHDEEP@example.com" } ]
        }
      }

      post "/api/v1/courses", params: payload, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Tutors email has already been taken")
    end

    it "rejects a request with an empty course payload" do
      post "/api/v1/courses", params: { course: {} }, as: :json

      expect(response).to have_http_status(:bad_request)
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
