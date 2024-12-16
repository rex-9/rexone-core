require 'rails_helper'

RSpec.describe Asset, type: :model do
  describe 'validations' do
    # url
    context 'when url is not valid url' do
      let(:asset) { build(:asset, url: 'testing.com') }
      it 'url should not be invalid url' do
        expect(asset).not_to be_valid
      end
    end

    context 'when url is a valid url' do
      let(:asset) { build(:asset, url: 'https://www.google.com/image.jpg') }
      it 'url should be valid url' do
        expect(asset).to be_valid
      end
    end
  end
end
