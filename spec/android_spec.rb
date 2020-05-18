require 'tmpdir'

require 'spec_helper'
require 'muruby/console'

class TestApp < Thor
  include Thor::Actions

  no_commands {
    def cache_path
      File.join(Dir.tmpdir, 'app-cache')
    end
  }

end

describe "android environment" do
  before(:all) do
    @android = AndroidEnvironment.new(
      TestApp.new(),
      File.join(Dir.tmpdir, 'muruby-test-sdk').to_s,
      File.join(Dir.tmpdir, 'muruby-test-ndk').to_s
    )
  end

  describe "sdk manager" do
    it "should download sdk" do
      @android.download_sdk
      expect(File.exists?(File.join(@android.android_sdk_dir, 'bin', 'sdkmanager'))).to be true
    end
    
    it "run command sdkmanager" do
      expect(@android.sdk_manager('--version')).to be true
    end

    it "available build versions" do
      expect(@android.available_build_tools_version_sdk).to include("30.0.0-rc1")
    end

    it "configure" do
      @android.configure_sdk
    end
  end

  it "should download ndk" do
    @android.download_ndk
    expect(File.exists?(File.join(@android.android_ndk_dir, 'ndk-build'))).to be true
  end

  
end
