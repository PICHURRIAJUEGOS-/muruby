require 'tmpdir'

require 'spec_helper'
require 'muruby/console'

class TestApp < Thor
  include Thor::Actions
  
  def cache_path
    File.join(Dir.tmpdir, 'app-cache')
  end

end

describe Hg do
  before(:all) do
    @dir =  Dir.mktmpdir.to_s
    @hg = Hg.new(TestApp.new())
  end
  
  it "should clone remote to dir" do
    @hg.clone(@dir, 'https://hg.tryton.org/cookiecutter/')
    expect(File.exists?(File.join(@dir, 'README.rst'))).to eq(true)
  end

  it "should not pull invalid directory" do
    expect { @hg.pull("/bad-dir") }.to raise_error(DownloadError)
  end

  it "should pull directory" do
    expect { @hg.pull(@dir) }.not_to raise_error(DownloadError)
  end
end
