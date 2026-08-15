module Paginated
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  private

  def paginate(scope)
    total_count = scope.except(:includes, :order).count

    response.headers["X-Total-Count"] = total_count.to_s
    response.headers["X-Page"] = page.to_s
    response.headers["X-Per-Page"] = per_page.to_s
    response.headers["X-Total-Pages"] = total_pages(total_count).to_s

    scope.limit(per_page).offset((page - 1) * per_page)
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

  def total_pages(total_count)
    [ (total_count.to_f / per_page).ceil, 1 ].max
  end
end
