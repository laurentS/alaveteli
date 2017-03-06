# -*- encoding : utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe AdminRequestController, "when administering requests" do

  describe 'GET #index' do

    it "is successful" do
      get :index
      expect(response).to be_success
    end

  end

  describe 'GET #show' do
    let(:info_request){ FactoryGirl.create(:info_request) }

    render_views

    it "is successful" do
      get :show, :id => info_request
      expect(response).to be_success
    end

    it 'shows an external info request with no username' do
      get :show, :id => FactoryGirl.create(:external_request)
      expect(response).to be_success
    end

    it "shows a suitable default 'your email has been hidden' message" do
      get :show, :id => info_request.id
      expect(assigns[:request_hidden_user_explanation]).
        to include(info_request.user.name)
      expect(assigns[:request_hidden_user_explanation]).
        to include("vexatious")
      get :show, :id => info_request.id, :reason => "not_foi"
      expect(assigns[:request_hidden_user_explanation]).
        not_to include("vexatious")
      expect(assigns[:request_hidden_user_explanation]).
        to include("not a valid FOI")
    end

  end

  describe 'GET #edit' do
    let(:info_request){ FactoryGirl.create(:info_request) }

    it "is successful" do
      get :edit, :id => info_request
      expect(response).to be_success
    end

  end

  describe 'PUT #update' do
    let(:info_request){ FactoryGirl.create(:info_request) }

    it "saves edits to a request" do
      post :update, { :id => info_request,
                      :info_request => { :title => "Renamed",
                                         :prominence => "normal",
                                         :described_state => "waiting_response",
                                         :awaiting_description => false,
                                         :allow_new_responses_from => 'anybody',
                                         :handle_rejected_responses => 'bounce' } }
      expect(request.flash[:notice]).to include('successful')
      info_request.reload
      expect(info_request.title).to eq("Renamed")
    end

    it 'expires the request cache when saving edits to it' do
      allow(InfoRequest).to receive(:find).with(info_request.id.to_s).and_return(info_request)
      expect(info_request).to receive(:expire)
      post :update, { :id => info_request,
                      :info_request => { :title => "Renamed",
                                         :prominence => "normal",
                                         :described_state => "waiting_response",
                                         :awaiting_description => false,
                                         :allow_new_responses_from => 'anybody',
                                         :handle_rejected_responses => 'bounce' } }
    end

  end

  describe 'DELETE #destroy' do
    let(:info_request){ FactoryGirl.create(:info_request) }

    it 'calls destroy on the info_request object' do
      allow(InfoRequest).to receive(:find).with(info_request.id.to_s).and_return(info_request)
      expect(info_request).to receive(:destroy)
      delete :destroy, { :id => info_request.id }
    end

    it 'uses a different flash message to avoid trying to fetch a non existent user record' do
      info_request = info_requests(:external_request)
      delete :destroy, { :id => info_request.id }
      expect(request.flash[:notice]).to include('external')
    end

    it 'redirects after destroying a request with incoming_messages' do
      incoming_message = FactoryGirl.create(:incoming_message_with_html_attachment,
                                            :info_request => info_request)
      delete :destroy, { :id => info_request.id }

      expect(response).to redirect_to(admin_requests_url)
    end

  end

  describe 'POST #hide' do
    let(:info_request){ FactoryGirl.create(:info_request) }

    it "hides requests and sends a notification email that it has done so" do
      post :hide, :id => info_request.id, :explanation => "Foo", :reason => "vexatious"
      info_request.reload
      expect(info_request.prominence).to eq("requester_only")
      expect(info_request.described_state).to eq("vexatious")
      deliveries = ActionMailer::Base.deliveries
      expect(deliveries.size).to eq(1)
      mail = deliveries[0]
      expect(mail.body).to match(/Foo/)
    end

    it 'expires the file cache for the request' do
      allow(InfoRequest).to receive(:find).with(info_request.id.to_s).and_return(info_request)
      expect(info_request).to receive(:expire)
      post :hide, :id => info_request.id, :explanation => "Foo", :reason => "vexatious"
    end

    context 'when hiding an external request' do

      before do
        @info_request = mock_model(InfoRequest, :prominence= => nil,
                                   :log_event => nil,
                                   :set_described_state => nil,
                                   :save! => nil,
                                   :user => nil,
                                   :user_name => 'External User',
                                   :is_external? => true)
        allow(@info_request).to receive(:expire)

        allow(InfoRequest).to receive(:find).with(@info_request.id.to_s).and_return(@info_request)
        @default_params = { :id => @info_request.id,
                            :explanation => 'Foo',
                            :reason => 'vexatious' }
      end

      def make_request(params=@default_params)
        post :hide, params
      end

      it 'should redirect the the admin page for the request' do
        make_request
        expect(response).to redirect_to(:controller => 'admin_request',
                                    :action => 'show',
                                    :id => @info_request.id)
      end

      it 'should set the request prominence to "requester_only"' do
        expect(@info_request).to receive(:prominence=).with('requester_only')
        expect(@info_request).to receive(:save!)
        make_request
      end

      it 'should not send a notification email' do
        expect(ContactMailer).not_to receive(:from_admin_message)
        make_request
      end

      it 'should add a notice to the flash saying that the request has been hidden' do
        make_request
        expect(request.flash[:notice]).to eq("This external request has been hidden")
      end

      it 'should expire the file cache for the request' do
        expect(@info_request).to receive(:expire)
        make_request
      end
    end

  end

end
