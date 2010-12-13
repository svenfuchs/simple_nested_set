module SimpleNestedSet
  # database-specific statements, ready to be
  # inserted into arel.project()
  module SqlAbstraction
    def group_concat(database, field, separator = '/')
      case database.to_sym
      when :sqlite, :sqlite3
        "GROUP_CONCAT(#{field}, '#{separator}')"
      when :mysql, :mysql2
        "GROUP_CONCAT(`#{field}`, '#{separator}')"
      when :postgresql
        "array_to_string(array_agg(\"#{field}\"), '#{separator}')"
      else
        raise ArgumentError, "#{database} is not supported by SimpleNestedSet::SqlAbstraction#group_concat"
      end
    end

    def order_by(database, order)
      case database.to_sym
      when :sqlite, :sqlite3
        order.to_s
      when :mysql, :mysql2
        "`#{order }`"
      when :postgresql
        "\"#{order}\" NULLS FIRST"
      end
    end
  end
end
