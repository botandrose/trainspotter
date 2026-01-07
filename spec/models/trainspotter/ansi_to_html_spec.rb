require "rails_helper"

RSpec.describe Trainspotter::AnsiToHtml do
  describe ".convert" do
    it "returns empty string for nil" do
      expect(described_class.convert(nil)).to eq("")
    end

    it "returns plain text unchanged" do
      expect(described_class.convert("hello world")).to eq("hello world")
    end

    it "converts bold code" do
      result = described_class.convert("\e[1mBold\e[0m")
      expect(result).to include('class="ansi-bold"')
      expect(result).to include("Bold")
    end

    it "converts color codes" do
      result = described_class.convert("\e[36mcyan text\e[0m")
      expect(result).to include('class="ansi-cyan"')
      expect(result).to include("cyan text")
    end

    it "handles multiple codes in sequence" do
      result = described_class.convert("\e[1;36mBold Cyan\e[0m")
      expect(result).to include("ansi-bold")
      expect(result).to include("ansi-cyan")
    end

    it "escapes HTML in the text" do
      result = described_class.convert("<script>alert('xss')</script>")
      expect(result).to include("&lt;script&gt;")
      expect(result).not_to include("<script>")
    end

    it "handles SQL-style ANSI codes" do
      input = "  \e[1m\e[36mPost Load (0.5ms)\e[0m  SELECT * FROM posts"
      result = described_class.convert(input)

      expect(result).to include("ansi-bold")
      expect(result).to include("ansi-cyan")
      expect(result).to include("Post Load")
      expect(result).to include("SELECT * FROM posts")
    end

    it "closes unclosed spans" do
      result = described_class.convert("\e[36munclosed")
      expect(result.scan("</span>").length).to eq(result.scan("<span").length)
    end

    it "returns html_safe string" do
      result = described_class.convert("test")
      expect(result).to be_html_safe
    end
  end
end
