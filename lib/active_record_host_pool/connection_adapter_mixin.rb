# frozen_string_literal: true
['mysql_adapter', 'mysql2_adapter'].each do |adapter|
  begin
    require "active_record/connection_adapters/#{adapter}"
  rescue LoadError
  end
end

module ActiveRecordHostPool
  module DatabaseSwitch
    def self.included(base)
      base.class_eval do
        attr_reader(:_host_pool_current_database)

        def _host_pool_current_database=(database)
          @_host_pool_current_database = database
          @config[:database] = _host_pool_current_database if ActiveRecord::VERSION::MAJOR >= 5
        end

        alias_method :execute_without_switching, :execute
        alias_method :execute, :execute_with_switching

        alias_method :drop_database_without_no_switching, :drop_database
        alias_method :drop_database, :drop_database_with_no_switching

        alias_method :create_database_without_no_switching, :create_database
        alias_method :create_database, :create_database_with_no_switching

        alias_method :disconnect_without_host_pooling!, :disconnect!
        alias_method :disconnect!, :disconnect_with_host_pooling!
      end
    end

    def execute_with_switching(*args)
      if _host_pool_current_database && ! @_no_switch
        _switch_connection
      end
      execute_without_switching(*args)
    end

    def drop_database_with_no_switching(*args)
      begin
        @_no_switch = true
        drop_database_without_no_switching(*args)
      ensure
        @_no_switch = false
      end
    end

    def create_database_with_no_switching(*args)
      begin
        @_no_switch = true
        create_database_without_no_switching(*args)
      ensure
        @_no_switch = false
      end
    end

    def disconnect_with_host_pooling!
      @_cached_current_database = nil
      @_cached_connection_object_id = nil
      disconnect_without_host_pooling!
    end

    private

    def _switch_connection
      if _host_pool_current_database && ((_host_pool_current_database != @_cached_current_database) || @connection.object_id != @_cached_connection_object_id)
        log("select_db #{_host_pool_current_database}", "SQL") do
          clear_cache! if respond_to?(:clear_cache!)
          raw_connection.select_db(_host_pool_current_database)
        end
        @_cached_current_database = _host_pool_current_database
        @_cached_connection_object_id = @connection.object_id
      end
    end

    # prevent different databases from sharing the same query cache
    def cache_sql(sql, *args)
      super(_host_pool_current_database.to_s + "/" + sql, *args)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandler

      if ActiveRecord::VERSION::MAJOR == 5
        if ActiveRecord::VERSION::MINOR == 0
          def establish_connection(spec)
            owner_to_pool[spec.name] = ActiveRecordHostPool::PoolProxy.new(spec)
          end
        else
          def establish_connection(spec)
            resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new(Base.configurations)
            spec = resolver.spec(spec)

            owner_to_pool[spec.name] = ActiveRecordHostPool::PoolProxy.new(spec)
          end
        end

      elsif ActiveRecord::VERSION::MAJOR == 4

        def establish_connection(owner, spec)
          @class_to_pool.clear
          raise RuntimeError, "Anonymous class is not allowed." unless owner.name
          owner_to_pool[owner.name] = ActiveRecordHostPool::PoolProxy.new(spec)
        end

      elsif ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 2

        def establish_connection(owner, spec)
          @connection_pools[spec] ||= ActiveRecordHostPool::PoolProxy.new(spec)
          @class_to_pool[owner] = @connection_pools[spec]
        end

      else

        def establish_connection(owner, spec)
          @connection_pools[owner] = ActiveRecordHostPool::PoolProxy.new(spec)
        end

      end

    end
  end
end

["MysqlAdapter", "Mysql2Adapter"].each do |k|
  next unless ActiveRecord::ConnectionAdapters.const_defined?(k)
  ActiveRecord::ConnectionAdapters.const_get(k).class_eval { include ActiveRecordHostPool::DatabaseSwitch }
end
