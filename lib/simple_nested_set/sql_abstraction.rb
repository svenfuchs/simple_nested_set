module SimpleNestedSet
  module SqlAbstraction
    # return a database-specific 'GROUP_CONCAT'-statement, ready to be
    # inserted into arel.project()
    def group_concat(database, field, separator = '/')
      case database.to_sym
      when :sqlite, :sqlite3
        "GROUP_CONCAT(#{field}, '#{separator}')"
      when :mysql
        "GROUP_CONCAT(`#{field}`, '#{separator}')"
      when :postgresql
        "array_to_string(array_agg(\"#{field}\"), '#{separator}')"
      else
        raise ArgumentError, "#{database} is not supported by SimpleNestedSet::SqlAbstraction#group_concat"
      end
    end
  end
end
