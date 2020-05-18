require 'tmpdir'

require 'spec_helper'
require 'muruby/console'

class TestApp < Thor
  include Thor::Actions

  no_commands {
  }
end

describe Environment do
  it "run command with environment" do
    @shell = Shell.new(TestApp.new())
    @shell.env['TESTVAR'] = 'yeah'
    out = @shell.run('echo $TESTVAR', :capture => true)
    expect(out).to match 'yeah'
  end
end
