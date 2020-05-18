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

describe Curl do
  before(:each) do
    @dir =  Dir.mktmpdir.to_s
    @curl = Curl.new(TestApp.new())
  end

  it "should clone url" do
    expect { @curl.clone(@dir, 'https://fossil-scm.org/home/uv/fossil-linux-x64-2.11-beta-202005171633.tar.gz') }
      .not_to raise_error(DownloadError)
    expect(File.exists?(File.join(@dir, 'fossil'))).to be true
  end

  it "should clone remote url with custom name" do
    expect { @curl.clone(@dir, 'https://codeload.github.com/SDL-mirror/SDL/zip/release-2.0.1', file_from: 'SDL-release-2.0.1', file_to: 'sdl2.zip') }.not_to raise_error(DownloadError)
    expect(File.exists?(File.join(@dir, 'configure'))).to eq(true)
  end

end

describe Git do
  before(:all) do
    @dir =  Dir.mktmpdir.to_s
    @git = Git.new(TestApp.new())
  end

  it "should clone remote" do
    expect { @git.clone(@dir, 'https://github.com/PICHURRIAJUEGOS-/muruby') }.not_to raise_error(DownloadError)
    expect(File.exists?(File.join(@dir, 'Gemfile'))).to eq(true)
  end

  it "should pull remote" do
    expect { @git.pull(@dir) }.not_to raise_error(DownloadError)
  end
  
  it "should not clone remote" do
    expect { @git.clone(@dir, 'http://bobos') }.to raise_error(DownloadError)
  end

  it "should not pull invalid" do
    expect { @git.pull("/tmp") }.to raise_error(DownloadError)
  end
end

describe Hg do
  before(:all) do
    @dir =  Dir.mktmpdir.to_s
    @hg = Hg.new(TestApp.new())
  end
  
  it "should clone remote to dir" do
    expect { @hg.clone(@dir, 'https://hg.tryton.org/cookiecutter/') }.not_to raise_error(DownloadError)
    expect(File.exists?(File.join(@dir, 'README.rst'))).to eq(true)
  end

  
  it 'should not clone remote' do
    expect { @hg.clone(@dir, 'https://hg.tryton.org/cookiecuttera/') }.to raise_error(DownloadError)
  end

  it "should not pull invalid directory" do
    expect { @hg.pull("/bad-dir") }.to raise_error(DownloadError)
  end

  it "should pull directory" do
    expect { @hg.pull(@dir) }.not_to raise_error(DownloadError)
  end
end
