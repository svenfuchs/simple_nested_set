require 'gem_patching'

# actual patches
# patch for Arel 1.0.1
module SimpleNestedSetPatchArel1
  # Arel 1.0.0.rc1 Arel::Table#initialize and #table_exists? does not support
  # instantiating an Arel::Table before the database table has been created.
  #
  # This happens in adva-cms2 during the setup of the cucumber test application
  # where the environment has to be loaded (and thus models will be loaded) and
  # migrations will only be run afterwards.
  #
  # see http://github.com/rails/arel/commit/19c5a95f1093653d2628dfb2f53637b0425dbba4#commitcomment-133903
  #
  # Also, in Arel 1.0.0.rc1 Arel::Table#initialize @options won't be initialized
  # if the second argument is an engine, so #as will crash subsequently.
  #
  # These issues have been fixed in:
  #
  # http://github.com/svenfuchs/arel/commit/4b476404cbbecfedc255039c66c6eececb667d7f
  # http://github.com/svenfuchs/arel/commit/3b1b24551106bc116cba404c992b513c5fbd137b
  module Arel
    class Table
      def initialize(name, options = {})
        @name = name.to_s
        @table_exists = nil
        @table_alias = nil
        @christener = Arel::Sql::Christener.new
        @attributes = nil
        @matching_attributes = nil

        if options.is_a?(Hash)
          @options = options
          @engine = options[:engine] || Arel::Table.engine

          if options[:as]
            as = options[:as].to_s
            @table_alias = as unless as == @name
          end
        else
          @engine = options # Table.new('foo', engine)
          @options = {}
        end

        if @engine.connection
          begin
            require "arel/engines/sql/compilers/#{@engine.adapter_name.downcase}_compiler"
          rescue LoadError
            begin
              # try to load an externally defined compiler, in case this adapter has defined the compiler on its own.
              require "#{@engine.adapter_name.downcase}/arel_compiler"
            rescue LoadError
              raise "#{@engine.adapter_name} is not supported by Arel."
            end
          end

          @@tables ||= engine.connection.tables
        end
      end

      def as(table_alias)
        @options ||= {}
        Arel::Table.new(name, options.merge(:as => table_alias))
      end

      def table_exists?
        @table_exists ||= @@tables.include?(name) || engine.connection.table_exists?(name)
      end
    end
  end
end

# patch for Arel 2.0.x
module SimpleNestedSetPatchArel2
  attr_reader :options

  def initialize(name, options = Arel::Tanle.engine)
    @options = engine if Hash === engine
    super
  end

  def as(table_alias)
    @options ||= {}
    Arel::Table.new(name, options.merge(:as => table_alias))
  end
end

case Arel::VERSION
when '1.0.1'
  Gem.patching('arel', '1.0.1') do
    Arel::Table.send :include, SimpleNestedSetPatchArel1
  end
when /^2\.0\.[5-9]$/, /^2\.1\.[01]$/, '2.0.10' # successfully tested, could be '~> 2.0.5'
  Gem.patching('arel', Arel::VERSION) do
    Arel::Table.send :include, SimpleNestedSetPatchArel2
  end
else
  # latest tested version to enable Gem-patching-Exceptions
  # This can be removed once we cover all versions which need this patch
  Gem.patching('arel', '2.0.10') do
    Arel::Table.send :include, SimpleNestedSetPatchArel2
  end
end
