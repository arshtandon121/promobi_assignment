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
      expect(response.parsed_body["errors"]).to be_present
    end

    it "describes bad requests with the same error shape as validation failures" do
      post "/api/v1/courses", params: { course: {} }, as: :json

      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body.keys).to contain_exactly("errors")
      expect(response.parsed_body["errors"]).to all(be_a(String))
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
      expect(response.headers["X-Total-Count"]).to eq("0")
      expect(response.headers["X-Total-Pages"]).to eq("1")
    end
  end

  describe "GET /api/v1/courses pagination" do
    it "returns the first page and reports the totals in headers" do
      create_list(:course, 30)

      get "/api/v1/courses"

      expect(response.parsed_body.size).to eq(25)
      expect(response.headers["X-Total-Count"]).to eq("30")
      expect(response.headers["X-Page"]).to eq("1")
      expect(response.headers["X-Per-Page"]).to eq("25")
      expect(response.headers["X-Total-Pages"]).to eq("2")
    end

    it "keeps the body a bare array so the response shape is unchanged" do
      create_list(:course, 3)

      get "/api/v1/courses", params: { per_page: 2 }

      expect(response.parsed_body).to be_an(Array)
      expect(response.parsed_body.first.keys).to contain_exactly("id", "name", "description", "tutors")
    end

    it "walks through the pages without repeating or dropping a course" do
      create_list(:course, 5)

      get "/api/v1/courses", params: { per_page: 2 }
      first_page = response.parsed_body.map { |course| course["id"] }

      get "/api/v1/courses", params: { per_page: 2, page: 2 }
      second_page = response.parsed_body.map { |course| course["id"] }

      get "/api/v1/courses", params: { per_page: 2, page: 3 }
      third_page = response.parsed_body.map { |course| course["id"] }

      expect(first_page.size).to eq(2)
      expect(second_page.size).to eq(2)
      expect(third_page.size).to eq(1)
      expect(first_page + second_page + third_page).to eq(Course.order(:id).pluck(:id))
    end

    it "returns an empty page past the end of the collection" do
      create_list(:course, 2)

      get "/api/v1/courses", params: { page: 99 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
      expect(response.headers["X-Total-Count"]).to eq("2")
    end

    it "caps per_page so a client cannot ask for the whole table" do
      get "/api/v1/courses", params: { per_page: 5_000 }

      expect(response.headers["X-Per-Page"]).to eq(Paginated::MAX_PER_PAGE.to_s)
    end

    it "falls back to the defaults when the parameters are junk" do
      create_list(:course, 3)

      get "/api/v1/courses", params: { page: "-4", per_page: "abc" }

      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Page"]).to eq("1")
      expect(response.headers["X-Per-Page"]).to eq(Paginated::DEFAULT_PER_PAGE.to_s)
      expect(response.parsed_body.size).to eq(3)
    end
  end
end
