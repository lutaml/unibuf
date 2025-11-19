# frozen_string_literal: true

module Unibuf
  # Base error class
  class Error < StandardError; end

  # Parse error
  class ParseError < Error; end

  # Serialization error
  class SerializationError < Error; end

  # Validation error
  class ValidationError < Error; end

  # Schema validation error
  class SchemaValidationError < ValidationError; end

  # Type validation error
  class TypeValidationError < ValidationError; end

  # Invalid value error
  class InvalidValueError < ValidationError; end

  # Type coercion error
  class TypeCoercionError < Error; end

  # File not found error
  class FileNotFoundError < Error; end

  # Invalid argument error
  class InvalidArgumentError < Error; end
end
