require 'rails_helper'

RSpec.describe Repository, type: :model do
  it { is_expected.to have_many(:branches).dependent(:destroy) }
  it { is_expected.to have_many(:commits).dependent(:destroy) }

  it_behaves_like 'sortable by id'
  it_behaves_like 'watchable'
end
