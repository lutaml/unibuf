# frozen_string_literal: true

module Unibuf
  # Base error class for all Unibuf errors
  class Error < StandardError; end

  # Parsing errors
  class ParseError < Error; end
  class SyntaxError < ParseError; end
  class UnexpectedTokenError < ParseError; end
  class UnterminatedStringError < ParseError; end

  # Validation errors
  class ValidationError < Error; end
  class TypeValidationError < ValidationError; end
  class SchemaValidationError < ValidationError; end
  class ReferenceValidationError < ValidationError; end
  class RequiredFieldError < ValidationError; end

  # Model errors
  class ModelError < Error; end
  class InvalidFieldError < ModelError; end
  class InvalidValueError < ModelError; end
  class TypeCoercionError < ModelError; end

  # File errors
  class FileError < Error; end
  class FileNotFoundError < FileError; end
  class FileReadError < FileError; end
  class FileWriteError < FileError; end

  # CLI errors
  class CLIError < Error; end
  class InvalidArgumentError < CLIError; end
  class CommandExecutionError < CLIError; end
end
