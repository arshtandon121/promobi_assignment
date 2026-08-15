module Api
  module V1
    class CoursesController < ApplicationController
      include Paginated

      def index
        courses = paginate(Course.includes(:tutors).order(:id))

        render json: courses, status: :ok
      end

      def create
        course = Course.new(course_params)

        if course.save
          render json: course, status: :created
        else
          render json: { errors: course.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def course_params
        params.expect(course: [ :name, :description, tutors_attributes: [ [ :name, :email ] ] ])
      end
    end
  end
end
