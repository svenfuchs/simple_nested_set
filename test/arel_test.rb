require File.expand_path('../test_helper', __FILE__)

class ArelTest < Test::Unit::TestCase
  test "foo" do
    where_clauses = Node.new.nested_set.where_clauses
    table = Node.arel_table
    aliaz = table.as(:l)

    query = aliaz.project(aliaz[:id].count).
                  where(aliaz[:lft].lt(table[:lft])).
                  where(aliaz[:rgt].lt(table[:rgt]))

    query = [query.to_sql] + where_clauses.map { |clause| clause.gsub(table.name, 'l') }
    query = query.join(' AND ')

    expected = %(SELECT COUNT("l"."id") FROM "nodes" "l" WHERE "l"."lft" < "nodes"."lft" AND "l"."rgt" < "nodes"."rgt" AND ("l"."type" = 'Node') AND ("l"."scope_id" IS NULL))
    assert_equal expected, query
  end
end

