require 'spec_helper'

klass = RUBY_VERSION < '2.4.0' ? Kernel : Warning
describe klass do
  describe '.with_raised_warnings' do
    it 'makes .warn raise' do
      expect {
        described_class.with_raised_warnings { described_class.warn('foo') }
      }.to raise_error(RaisedWarning)
    end

    it 'only affects calls to .warn within the block' do
      expect { described_class.warn('bar') }.to output('bar').to_stderr
    end
  end
end
