# Course & Tutor API

A small Rails API-only app with two endpoints: one to create a course along with its
tutors, and one to list all courses with their tutors.

A course has many tutors, and a tutor teaches one course only. The schema enforces that:
`tutors.course_id` is `NOT NULL` with a foreign key, and `tutors.email` has a unique
index, so the same person can't be added under two courses.

## Requirements

- Ruby 3.3.5
- Rails 8.1
- PostgreSQL

## Setup

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

The API runs on `http://localhost:3000`.

## Endpoints

### POST /api/v1/courses

Creates a course and its tutors in one request.

```bash
curl -X POST http://localhost:3000/api/v1/courses \
  -H "Content-Type: application/json" \
  -d '{
        "course": {
          "name": "Ruby on Rails Fundamentals",
          "description": "Build and ship web applications with Rails",
          "tutors_attributes": [
            { "name": "Arshdeep Tandon", "email": "arshdeep@example.com" },
            { "name": "Neha Sharma", "email": "neha@example.com" }
          ]
        }
      }'
```

`201 Created`

```json
{
  "id": 1,
  "name": "Ruby on Rails Fundamentals",
  "description": "Build and ship web applications with Rails",
  "tutors": [
    { "id": 1, "name": "Arshdeep Tandon", "email": "arshdeep@example.com" },
    { "id": 2, "name": "Neha Sharma", "email": "neha@example.com" }
  ]
}
```

`tutors_attributes` is optional, so a course can be created on its own.

### GET /api/v1/courses

Lists all courses with their tutors.

```bash
curl http://localhost:3000/api/v1/courses
```

`200 OK`

```json
[
  {
    "id": 1,
    "name": "Ruby on Rails Fundamentals",
    "description": "Build and ship web applications with Rails",
    "tutors": [
      { "id": 1, "name": "Arshdeep Tandon", "email": "arshdeep@example.com" },
      { "id": 2, "name": "Neha Sharma", "email": "neha@example.com" }
    ]
  }
]
```

The list is paginated with `page` and `per_page`. It defaults to 25 per page and caps
`per_page` at 100. Missing or invalid values fall back to the defaults.

```bash
curl -i "http://localhost:3000/api/v1/courses?page=2&per_page=3"
```

The body is still a plain array. The counts come back in headers:

```
X-Total-Count: 7
X-Page: 2
X-Per-Page: 3
X-Total-Pages: 3
```

### Errors

Both endpoints return errors in the same shape:

```json
{ "errors": ["Tutors email is invalid", "Name can't be blank"] }
```

`422` if the course or any of its tutors is invalid, in which case nothing is saved.
`400` if the `course` key is missing or empty.

## Tests

```bash
bundle exec rspec
```

32 examples covering the models and both endpoints: the success responses, the exact
fields returned, pagination edges, validation failures, and a check that a failed create
leaves no course behind.

## Notes on a few choices

I used `accepts_nested_attributes_for :tutors` instead of a `Courses::Create` service
object. It already saves the course and its tutors in one transaction and reports the
tutor errors on the course, so a service would only wrap `Course.new(params).save` in
another layer. It would be worth extracting once creation grows logic that doesn't belong
in the model, like emailing tutors or syncing to another system.

No Sidekiq either. The endpoint has to return the created records with their IDs, so it
can't reply before the write happens, and the write is two inserts in one transaction.
Background jobs fit the side effects around creation rather than the creation itself.

Responses go through ActiveModel::Serializers so the controller doesn't build JSON by hand
and columns like timestamps aren't exposed by accident. Moving to the JSON:API adapter is
a config change if a client needs that format.

The list endpoint uses `includes(:tutors)` to avoid an N+1, and pagination keeps the
payload bounded, since a constant query count still returns every row otherwise. The
totals go in headers instead of a `data`/`meta` envelope so the response stays the array
it already was. I wrote it by hand because limit and offset over an ordered scope is a few
lines, and Kaminari or Pagy mostly add view helpers an API doesn't need.

Strong params use `params.expect`, and `ApplicationController` rescues `ParameterMissing`
so a malformed payload gets a JSON `400` instead of an HTML error page.

Tutor emails are stripped and downcased before validation, which keeps the unique index
meaningful however the address was typed.
