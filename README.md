# Course & Tutor API

A small Rails API-only application that exposes two endpoints:

1. A single `POST` endpoint that creates a course together with its tutors.
2. A `GET` endpoint that lists every course along with its tutors.

## Domain

- A course has many tutors.
- A tutor teaches exactly one course.

The "one course per tutor" rule is enforced structurally: a tutor row holds a single
`course_id` with a foreign key and a `NOT NULL` constraint. Tutor emails carry a unique
index as well, so the same person cannot be registered under two different courses.

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

The API is then available at `http://localhost:3000`.

## Endpoints

### Create a course and its tutors

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

`tutors_attributes` is optional, so a course can also be created on its own.

### List all courses with their tutors

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

### Validation failures

If the course or any of its tutors is invalid, nothing is written and the endpoint
responds with `422 Unprocessable Content`:

```json
{ "errors": ["Tutors email is invalid", "Name can't be blank"] }
```

A request whose `course` payload is empty responds with `400 Bad Request`.

## Tests

```bash
bundle exec rspec
```

25 examples covering the models (associations, validations, nested creation) and both
endpoints, including the success responses, the exact serialized fields, validation
failures, and a case asserting that an invalid tutor leaves no orphaned course behind.

## Design notes

**Creating a course and its tutors in one request.** `Course` uses
`accepts_nested_attributes_for :tutors`, so `course.save` writes the parent and its
children inside a single transaction and reports child validation errors on the parent.
That is why a bad tutor rolls the entire request back, which the specs assert directly.

**No service object.** With nested attributes doing the transactional work, a
`Courses::Create` service would only wrap `Course.new(params).save` in another layer.
The extraction becomes worthwhile once creation grows behaviour that does not belong to
the model, for example notifying tutors, syncing to an external system, or branching on
the type of course being created. At the current scope it would be indirection without
purpose.

**No background job.** The endpoint has to return the created course and its tutor IDs,
which rules out responding before the write happens. The write itself is two inserts in
one transaction. Sidekiq would fit the side effects around creation, such as emailing the
tutors, rather than the creation itself.

**Serialization.** Responses are rendered with ActiveModel::Serializers, which keeps the
controller free of response shaping and makes the exposed fields explicit, so internal
columns such as timestamps are never leaked by accident. The default attributes adapter
produces the nested shape shown above; switching to the JSON:API adapter is a one-line
configuration change if a client needs that format.

**Queries.** The list endpoint uses `Course.includes(:tutors)` so the number of queries
stays constant as the number of courses grows, instead of issuing one query per course.

**Input handling.** Parameters are filtered with `params.expect`, the Rails 8 strong
parameters idiom, which permits exactly the course and tutor fields the API documents and
returns `400` rather than `500` when the payload is malformed.

**Emails.** Tutor emails are normalised to lowercase before validation, which keeps the
unique index meaningful no matter how the address was typed.
