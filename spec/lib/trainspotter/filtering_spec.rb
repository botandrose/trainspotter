require "rails_helper"

RSpec.describe "Trainspotter filtering" do
  after do
    Trainspotter.reset_filters!
  end

  describe ".filtered_paths" do
    it "returns default filtered paths" do
      expect(Trainspotter.filtered_paths).to include(%r{^/assets/})
    end

    it "can be customized" do
      Trainspotter.filtered_paths = [%r{^/custom/}]
      expect(Trainspotter.filtered_paths).to eq([%r{^/custom/}])
    end
  end

  describe ".filter_request?" do
    it "filters asset paths" do
      expect(Trainspotter.filter_request?("/assets/application.js")).to be true
      expect(Trainspotter.filter_request?("/assets/styles.css")).to be true
    end

    it "filters webpack/vite paths" do
      expect(Trainspotter.filter_request?("/packs/application.js")).to be true
      expect(Trainspotter.filter_request?("/vite/client")).to be true
    end

    it "filters active storage paths" do
      expect(Trainspotter.filter_request?("/rails/active_storage/blobs/123")).to be true
    end

    it "filters action cable path" do
      expect(Trainspotter.filter_request?("/cable")).to be true
    end

    it "filters source maps" do
      expect(Trainspotter.filter_request?("/assets/application.js.map")).to be true
    end

    it "filters hot reload updates" do
      expect(Trainspotter.filter_request?("/assets/main.hot-update.js")).to be true
    end

    it "does not filter regular paths" do
      expect(Trainspotter.filter_request?("/posts")).to be false
      expect(Trainspotter.filter_request?("/users/123")).to be false
      expect(Trainspotter.filter_request?("/api/v1/items")).to be false
    end

    it "respects custom filters" do
      Trainspotter.filtered_paths = [%r{^/admin/}]
      expect(Trainspotter.filter_request?("/admin/dashboard")).to be true
      expect(Trainspotter.filter_request?("/assets/app.js")).to be false
    end
  end

  describe ".reset_filters!" do
    it "restores default filters" do
      Trainspotter.filtered_paths = [%r{^/custom/}]
      Trainspotter.reset_filters!
      expect(Trainspotter.filtered_paths).to eq(Trainspotter::DEFAULT_FILTERED_PATHS)
    end
  end
end
