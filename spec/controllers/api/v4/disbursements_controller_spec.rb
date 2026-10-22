# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V4::DisbursementsController do
  render_views

  describe "#create" do
    it "only fronts transfers into organizations the user manages" do
      user = create(:user)
      source_event = create(:event, :with_positive_balance, organizers: [user], plan_type: Event::Plan::HackClubAffiliate)
      own_event = create(:event, organizers: [user])
      public_event = create(:event)

      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"

      post(:create, params: { event_id: source_event.public_id, to_organization_id: own_event.public_id, name: "Own", amount_cents: 40_00 }, as: :json)
      expect(response).to have_http_status(:created)
      expect(Disbursement.last.canonical_pending_transactions.map(&:fronted)).to eq([true, true])

      post(:create, params: { event_id: source_event.public_id, to_organization_id: public_event.public_id, name: "Public", amount_cents: 40_00 }, as: :json)
      expect(response).to have_http_status(:created)
      expect(Disbursement.last.canonical_pending_transactions.map(&:fronted)).to eq([false, false])
    end

    it "categorizes both sides as internal transfers" do
      user = create(:user)
      source_event = create(:event, :with_positive_balance, organizers: [user])
      destination_event = create(:event, organizers: [user])

      token = create(:api_token, user:)
      request.headers["Authorization"] = "Bearer #{token.token}"

      post(:create, params: { event_id: source_event.public_id, to_organization_id: destination_event.public_id, name: "Internal", amount_cents: 40_00 }, as: :json)
      expect(response).to have_http_status(:created)

      disbursement = Disbursement.last
      expect(disbursement.source_transaction_category.slug).to eq("internal-transfer")
      expect(disbursement.destination_transaction_category.slug).to eq("internal-transfer")
      expect(disbursement.canonical_pending_transactions.map { |cpt| cpt.category.slug }).to eq(["internal-transfer", "internal-transfer"])
    end
  end
end
