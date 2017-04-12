require 'spec_helper'

RSpec.describe AlaveteliPro::RequestSummary, type: :model do
  let(:public_bodies) { FactoryGirl.create_list(:public_body, 3) }
  let(:public_body_names) { public_bodies.map(&:name).join(" ") }

  describe ".create_or_update_from" do
    # All these classes create and update summaries of themselves during an
    # after_save callback. That makes testing this method explicitly hard, so
    # we skip the callback for the duration of these tests.
    before :all do
      InfoRequest.skip_callback(:save, :after, :create_or_update_request_summary)
      DraftInfoRequest.skip_callback(:save, :after, :create_or_update_request_summary)
      InfoRequestBatch.skip_callback(:save, :after, :create_or_update_request_summary)
      AlaveteliPro::DraftInfoRequestBatch.skip_callback(:save, :after, :create_or_update_request_summary)
    end

    after :all do
      InfoRequest.set_callback(:save, :after, :create_or_update_request_summary)
      DraftInfoRequest.set_callback(:save, :after, :create_or_update_request_summary)
      InfoRequestBatch.set_callback(:save, :after, :create_or_update_request_summary)
      AlaveteliPro::DraftInfoRequestBatch.set_callback(:save, :after, :create_or_update_request_summary)
    end

    it "raises an ArgumentError if the request is of the wrong class" do
      event = FactoryGirl.create(:info_request_event)
      expect { AlaveteliPro::RequestSummary.create_or_update_from(event) }.
        to raise_error(ArgumentError)
    end

    context "when the request already has a summary" do
      it "updates the existing summary from a request" do
        summary = FactoryGirl.create(:request_summary)
        request = summary.summarisable
        public_body = FactoryGirl.create(:public_body)
        request.title = "Updated title"
        request.public_body = public_body
        request.save
        updated_summary = AlaveteliPro::RequestSummary.create_or_update_from(request)
        expect(updated_summary.id).to eq summary.id
        expect(updated_summary.title).to eq request.title
        expect(updated_summary.public_body_names).to eq public_body.name
        expect(updated_summary.summarisable).to eq request
      end

      it "updates the existing summary from a batch request" do
        batch = FactoryGirl.create(
          :info_request_batch,
          public_bodies: public_bodies
        )
        summary = FactoryGirl.create(:request_summary, summarisable: batch)
        public_body = FactoryGirl.create(:public_body)
        batch.title = "Updated title"
        batch.body = "Updated body"
        batch.public_bodies << public_body
        batch.save
        updated_summary = AlaveteliPro::RequestSummary.create_or_update_from(batch)
        expect(updated_summary.id).to eq summary.id
        expect(updated_summary.title).to eq batch.title
        expect(updated_summary.body).to eq batch.body
        expect(updated_summary.public_body_names).to match /.*#{public_body.name}.*/
        expect(updated_summary.summarisable).to eq batch
      end
    end

    context "when the request doesn't already have a summary" do
      it "creates a summary from an info_request" do
        request = FactoryGirl.create(:info_request)
        summary = AlaveteliPro::RequestSummary.create_or_update_from(request)
        expect(summary.title).to eq request.title
        expect(summary.body).to eq request.outgoing_messages.first.body
        expect(summary.public_body_names).to eq request.public_body.name
        expect(summary.summarisable).to eq request
      end

      it "creates a summary from a draft_info_request" do
        draft = FactoryGirl.create(:draft_info_request)
        summary = AlaveteliPro::RequestSummary.create_or_update_from(draft)
        expect(summary.title).to eq draft.title
        expect(summary.body).to eq draft.body
        expect(summary.public_body_names).to eq draft.public_body.name
        expect(summary.summarisable).to eq draft
      end

      it "creates a summary from an info_request_batch" do
        batch = FactoryGirl.create(
          :info_request_batch,
          public_bodies: public_bodies
        )
        summary = AlaveteliPro::RequestSummary.create_or_update_from(batch)
        expect(summary.title).to eq batch.title
        expect(summary.body).to eq batch.body
        expect(summary.public_body_names).to eq public_body_names
        expect(summary.summarisable).to eq batch
      end

      it "creates a summary from an draft_info_request_batch" do
        draft = FactoryGirl.create(
          :draft_info_request_batch,
          public_bodies: public_bodies
        )
        summary = AlaveteliPro::RequestSummary.create_or_update_from(draft)
        expect(summary.title).to eq draft.title
        expect(summary.body).to eq draft.body
        expect(summary.public_body_names).to eq public_body_names
        expect(summary.summarisable).to eq draft
      end
    end

    describe "setting public body names" do
      context "when the request is a draft with no public body" do
        let(:draft) do
          FactoryGirl.create(:draft_info_request, public_body: nil)
        end
        let(:summary) do
          AlaveteliPro::RequestSummary.create_or_update_from(draft)
        end

        it "sets the public body names to nil" do
          expect(summary.public_body_names).to be_nil
        end
      end
    end
  end
end
