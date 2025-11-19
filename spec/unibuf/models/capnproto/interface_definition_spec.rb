# frozen_string_literal: true

require "spec_helper"
require "unibuf/models/capnproto/interface_definition"
require "unibuf/models/capnproto/method_definition"

RSpec.describe Unibuf::Models::Capnproto::InterfaceDefinition do
  describe "initialization" do
    it "creates interface with methods" do
      method = Unibuf::Models::Capnproto::MethodDefinition.new(
        name: "add",
        ordinal: 0,
        params: [],
        results: [],
      )
      interface = described_class.new(name: "Calculator", methods: [method])

      expect(interface.name).to eq("Calculator")
      expect(interface.methods.length).to eq(1)
    end
  end

  describe "queries" do
    let(:method1) do
      Unibuf::Models::Capnproto::MethodDefinition.new(
        name: "add",
        ordinal: 0,
        params: [],
        results: [],
      )
    end

    let(:method2) do
      Unibuf::Models::Capnproto::MethodDefinition.new(
        name: "subtract",
        ordinal: 1,
        params: [],
        results: [],
      )
    end

    let(:interface_def) do
      described_class.new(name: "Calculator", methods: [method1, method2])
    end

    it "finds method by name" do
      expect(interface_def.find_method("add")).to eq(method1)
    end

    it "returns method names" do
      expect(interface_def.method_names).to eq(["add", "subtract"])
    end

    it "returns ordinals" do
      expect(interface_def.ordinals).to eq([0, 1])
    end
  end

  describe "validation" do
    it "requires name" do
      interface = described_class.new(methods: [])

      expect(interface.valid?).to be false
      expect do
        interface.validate!
      end.to raise_error(Unibuf::ValidationError, /name required/)
    end

    it "requires at least one method" do
      interface = described_class.new(name: "Empty", methods: [])

      expect(interface.valid?).to be false
      expect do
        interface.validate!
      end.to raise_error(Unibuf::ValidationError,
                         /at least one method/)
    end

    it "detects duplicate ordinals" do
      method1 = Unibuf::Models::Capnproto::MethodDefinition.new(name: "a",
                                                                ordinal: 0, params: [], results: [])
      method2 = Unibuf::Models::Capnproto::MethodDefinition.new(name: "b",
                                                                ordinal: 0, params: [], results: [])
      interface = described_class.new(name: "Test", methods: [method1, method2])

      expect(interface.valid?).to be false
      expect do
        interface.validate!
      end.to raise_error(Unibuf::ValidationError,
                         /Duplicate ordinals/)
    end
  end
end

RSpec.describe Unibuf::Models::Capnproto::MethodDefinition do
  describe "initialization" do
    it "creates method with parameters and results" do
      method = described_class.new(
        name: "add",
        ordinal: 0,
        params: [{ name: "a", type: "Int32" }, { name: "b", type: "Int32" }],
        results: [{ name: "result", type: "Int32" }],
      )

      expect(method.name).to eq("add")
      expect(method.ordinal).to eq(0)
      expect(method.params.length).to eq(2)
      expect(method.results.length).to eq(1)
    end
  end

  describe "queries" do
    let(:method_def) do
      described_class.new(
        name: "add",
        ordinal: 0,
        params: [{ name: "a", type: "Int32" }, { name: "b", type: "Int32" }],
        results: [{ name: "result", type: "Int32" }],
      )
    end

    it "returns param names" do
      expect(method_def.param_names).to eq(["a", "b"])
    end

    it "returns result names" do
      expect(method_def.result_names).to eq(["result"])
    end

    it "finds param by name" do
      expect(method_def.find_param("a")).to eq({ name: "a", type: "Int32" })
    end

    it "finds result by name" do
      expect(method_def.find_result("result")).to eq({ name: "result",
                                                       type: "Int32" })
    end
  end

  describe "validation" do
    it "requires name" do
      method = described_class.new(ordinal: 0, params: [], results: [])

      expect do
        method.validate!
      end.to raise_error(Unibuf::ValidationError, /name required/)
    end

    it "requires ordinal" do
      method = described_class.new(name: "test", params: [], results: [])

      expect do
        method.validate!
      end.to raise_error(Unibuf::ValidationError, /ordinal required/)
    end

    it "validates parameters have name and type" do
      method = described_class.new(
        name: "test",
        ordinal: 0,
        params: [{ name: "a" }], # missing type
        results: [],
      )

      expect do
        method.validate!
      end.to raise_error(Unibuf::ValidationError,
                         /must have name and type/)
    end
  end
end
