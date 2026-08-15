module Paginated
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  private

  def paginate(scope)
    scope.limit(per_page).offset((page - 1) * per_page)
  end

  def pagination_meta(scope)
    total_count = scope.except(:includes, :order, :limit, :offset).count

    {
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: [ (total_count.to_f / per_page).ceil, 1 ].max
    }
  end

  def page
    @page ||= [ params[:page].to_i, 1 ].max
  end

  def per_page
    @per_page ||= begin
      requested = params[:per_page].to_i

      requested.positive? ? [ requested, MAX_PER_PAGE ].min : DEFAULT_PER_PAGE
    end
  end
end
