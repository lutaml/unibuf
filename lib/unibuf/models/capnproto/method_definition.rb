# frozen_string_literal: true

module Unibuf
  module Models
    module Capnproto
      # Represents a Cap'n Proto method definition (RPC)
      class MethodDefinition
        attr_reader :name, :ordinal, :params, :results

        def initialize(attributes = {})
          @name = attributes[:name] || attributes["name"]
          @ordinal = attributes[:ordinal] || attributes["ordinal"]
          @params = Array(attributes[:params] || attributes["params"])
          @results = Array(attributes[:results] || attributes["results"])
        end

        # Queries
        def param_names
          params.map { |p| p[:name] }
        end

        def result_names
          results.map { |r| r[:name] }
        end

        def find_param(name)
          params.find { |p| p[:name] == name }
        end

        def find_result(name)
          results.find { |r| r[:name] == name }
        end

        # Validation
        def valid?
          validate!
          true
        rescue ValidationError
          false
        end

        def validate!
          raise ValidationError, "Method name required" unless name
          raise ValidationError, "Method ordinal required" unless ordinal

          if ordinal.to_i.negative?
            raise ValidationError,
                  "Ordinal must be non-negative"
          end

          # Validate params
          params.each do |param|
            unless param[:name] && param[:type]
              raise ValidationError,
                    "Method parameter must have name and type"
            end
          end

          # Validate results
          results.each do |result|
            unless result[:name] && result[:type]
              raise ValidationError,
                    "Method result must have name and type"
            end
          end

          true
        end

        def to_h
          {
            name: name,
            ordinal: ordinal,
            params: params,
            results: results,
          }
        end
      end
    end
  end
end
