require 'spec_helper'

RSpec.describe RefusalAdvice do
  let(:data) do
    files = Dir.glob(Rails.root + 'spec/fixtures/refusal_advice/*.yml')
    RefusalAdvice::Store.from_yaml(files)
  end

  describe '.default' do
    subject { described_class.default(info_request) }

    let(:path) { Rails.root.join('spec/fixtures/refusal_advice') }

    before do
      Rails.configuration.paths['config/refusal_advice'].push(path)
    end

    after do
      Rails.configuration.paths['config/refusal_advice'].unshift(path)
    end

    context 'with info request' do
      let(:info_request) { FactoryBot.build(:info_request) }
      it do
        is_expected.to eq(
          described_class.new(data, info_request: info_request)
        )
      end
    end

    context 'without info request' do
      let(:info_request) { nil }
      it { is_expected.to eq(described_class.new(data)) }
    end
  end

  describe '#legislation' do
    let(:instance) { described_class.new(data, info_request: info_request) }
    subject { instance.legislation }

    let(:legislation) { double(:legislation) }

    context 'with info request' do
      let(:info_request) { FactoryBot.build(:info_request) }

      it 'returns info request legislation' do
        allow(info_request).to receive(:legislation).and_return(legislation)
        is_expected.to eq legislation
      end
    end

    context 'without info request' do
      let(:info_request) { nil }

      it 'returns default legislation' do
        allow(Legislation).to receive(:default).and_return(legislation)
        is_expected.to eq legislation
      end
    end
  end

  describe '#questions' do
    let(:instance) { described_class.new(data) }
    subject { instance.questions }

    context 'for the FOI legislation' do
      before do
        allow(instance).to receive(:legislation).and_return(
          double(:legislation, key: :foi)
        )
      end

      let(:foi_questions) do
        [RefusalAdvice::Question.new(id: 'foo'),
         RefusalAdvice::Question.new(id: 'bar')]
      end

      it { is_expected.to eq(foi_questions) }
    end

    context 'for the EIR legislation' do
      before do
        allow(instance).to receive(:legislation).and_return(
          double(:legislation, key: :eir)
        )
      end

      let(:eir_questions) do
        [RefusalAdvice::Question.new(id: 'baz')]
      end

      it { is_expected.to eq(eir_questions) }
    end
  end

  describe '#actions' do
    let(:instance) { described_class.new(data) }
    subject { instance.actions }

    context 'for the FOI legislation' do
      before do
        allow(instance).to receive(:legislation).and_return(
          double(:legislation, key: :foi)
        )
      end

      let(:foi_actions) do
        [
          RefusalAdvice::Question.new(title: 'Hello World', suggestions: [
                                        { id: 'aaa' }, { id: 'bbb' }
                                      ])
        ]
      end

      it { is_expected.to eq(foi_actions) }
    end

    context 'for the EIR legislation' do
      before do
        allow(instance).to receive(:legislation).and_return(
          double(:legislation, key: :eir)
        )
      end

      let(:eir_actions) do
        [
          RefusalAdvice::Question.new(title: 'Hello World', suggestions: [
                                        { id: 'ccc' }
                                      ])
        ]
      end

      it { is_expected.to eq(eir_actions) }
    end
  end

  describe '#==' do
    subject { a == b }

    let(:data_a) { double }
    let(:data_b) { double }

    context 'with the same data' do
      let(:a) { described_class.new(data_a) }
      let(:b) { described_class.new(data_a) }
      it { is_expected.to eq(true) }
    end

    context 'with different data' do
      let(:a) { described_class.new(data_a) }
      let(:b) { described_class.new(data_b) }
      it { is_expected.to eq(false) }
    end
  end
end