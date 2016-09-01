class Query

  ## @elements = [{operator => eq, argument => "arg", column => tag},
  ##               operator => in, argument => "arg", column => content}, ...]
  def initialize(query)
    @original_string = query
    @elements = parse(query)
  end

  ## return Minutes via scope filter
  def to_scope
    scope = Minute.all
    @elements.each do |q|
      if scope.respond_to?(q[:column])
        scope = scope.send(q[:column], q[:argument], q[:operator])
      else
        scope = scope.where(create_sql(q[:operator],
                                       q[:argument],
                                       q[:column]))
      end
    end
    scope
  end

  ## return plane search query
  def to_string
    @original_string
  end

  private

  def create_sql(operator, argument, column)
    case operator.to_sym
    when :like
      sql = "LOWER(#{column}) LIKE " + "'%#{argument.downcase}%'"
    when :not_like
      sql = "LOWER(#{column}) NOT LIKE " + "'%#{argument.downcase}%'"
    else
      raise "Error: Unsupported Operator: #{operator}."
    end

    return sql
  end

  def parse(query)
    elements = []
    query.split("\s").each do |q|
      element = {}
      next unless q =~ /(-|)(?:(\w+):|)([\w+-]+)/
      no, column, argument = $1, $2, $3

      if column
        if no == "-"
          element[:operator] = "not_eq"
        else
          element[:operator] = "eq"
        end
        element[:column] = column
      else
        if no == "-"
          element[:operator] = "not_like"
        else
          element[:operator] = "like"
        end
        element[:column] = "content"
      end
      element[:argument] = argument
      elements << element
    end
    elements
  end
end
