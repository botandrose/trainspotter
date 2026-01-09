require "rails_helper"

RSpec.describe Trainspotter::Ingest::ParamsParser do
  describe ".parse" do
    it "parses simple string hash" do
      result = described_class.parse('{"email"=>"alice@example.com"}')
      expect(result).to eq({ "email" => "alice@example.com" })
    end

    it "parses nested hashes" do
      result = described_class.parse('{"session"=>{"email"=>"alice@example.com", "password"=>"[FILTERED]"}}')
      expect(result).to eq({
        "session" => {
          "email" => "alice@example.com",
          "password" => "[FILTERED]"
        }
      })
    end

    it "parses empty hash" do
      result = described_class.parse("{}")
      expect(result).to eq({})
    end

    it "parses arrays" do
      result = described_class.parse('{"ids"=>[1, 2, 3]}')
      expect(result).to eq({ "ids" => [ 1, 2, 3 ] })
    end

    it "parses arrays of strings" do
      result = described_class.parse('{"tags"=>["ruby", "rails"]}')
      expect(result).to eq({ "tags" => [ "ruby", "rails" ] })
    end

    it "parses nested arrays and hashes" do
      result = described_class.parse('{"users"=>[{"name"=>"Alice"}, {"name"=>"Bob"}]}')
      expect(result).to eq({
        "users" => [
          { "name" => "Alice" },
          { "name" => "Bob" }
        ]
      })
    end

    it "parses integers" do
      result = described_class.parse('{"count"=>42}')
      expect(result).to eq({ "count" => 42 })
    end

    it "parses negative integers" do
      result = described_class.parse('{"offset"=>-10}')
      expect(result).to eq({ "offset" => -10 })
    end

    it "parses floats" do
      result = described_class.parse('{"price"=>19.99}')
      expect(result).to eq({ "price" => 19.99 })
    end

    it "parses nil" do
      result = described_class.parse('{"value"=>nil}')
      expect(result).to eq({ "value" => nil })
    end

    it "parses boolean true" do
      result = described_class.parse('{"active"=>true}')
      expect(result).to eq({ "active" => true })
    end

    it "parses boolean false" do
      result = described_class.parse('{"active"=>false}')
      expect(result).to eq({ "active" => false })
    end

    it "handles escaped quotes in strings" do
      result = described_class.parse('{"message"=>"He said \\"hello\\""}')
      expect(result).to eq({ "message" => 'He said "hello"' })
    end

    it "handles escaped backslashes" do
      result = described_class.parse('{"path"=>"C:\\\\Users\\\\test"}')
      expect(result).to eq({ "path" => 'C:\\Users\\test' })
    end

    it "handles newlines in strings" do
      result = described_class.parse('{"text"=>"line1\\nline2"}')
      expect(result).to eq({ "text" => "line1\nline2" })
    end

    it "returns empty hash for nil input" do
      result = described_class.parse(nil)
      expect(result).to eq({})
    end

    it "returns empty hash for empty string" do
      result = described_class.parse("")
      expect(result).to eq({})
    end

    it "returns empty hash for whitespace-only string" do
      result = described_class.parse("   ")
      expect(result).to eq({})
    end

    it "raises ParseError for invalid input" do
      expect { described_class.parse("not a hash") }.to raise_error(Trainspotter::Ingest::ParamsParser::ParseError)
    end

    it "raises ParseError for malformed hash" do
      expect { described_class.parse('{"key"=>') }.to raise_error(Trainspotter::Ingest::ParamsParser::ParseError)
    end

    it "handles whitespace around elements" do
      result = described_class.parse('{ "key" => "value" }')
      expect(result).to eq({ "key" => "value" })
    end

    it "parses typical Rails params format" do
      params = '{"utf8"=>"✓", "authenticity_token"=>"[FILTERED]", "user"=>{"email"=>"test@example.com", "password"=>"[FILTERED]", "remember_me"=>"1"}, "commit"=>"Log in"}'
      result = described_class.parse(params)
      expect(result).to eq({
        "utf8" => "✓",
        "authenticity_token" => "[FILTERED]",
        "user" => {
          "email" => "test@example.com",
          "password" => "[FILTERED]",
          "remember_me" => "1"
        },
        "commit" => "Log in"
      })
    end

    it "handles empty arrays" do
      result = described_class.parse('{"items"=>[]}')
      expect(result).to eq({ "items" => [] })
    end

    it "parses deeply nested structures" do
      result = described_class.parse('{"a"=>{"b"=>{"c"=>{"d"=>"value"}}}}')
      expect(result).to eq({
        "a" => {
          "b" => {
            "c" => {
              "d" => "value"
            }
          }
        }
      })
    end
  end
end
