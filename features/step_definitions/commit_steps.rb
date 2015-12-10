Given(/^I have the following commits$/) do |table|
  table.hashes.each do |row|
    create(:commit,
      sha: row['Sha'],
      message: row['Message'],
      committer: row['Committer'],
      committed_at: row['Committed At']
    )
  end
end

Then(/^I should see all the following commits$/) do |table|
  table.hashes.each do |row|
    content_block = find('.commit-item', text: row['Title'])
    expect(content_block).to have_content(row['Description'])
  end
end

Given(/^the commit with sha '(.*)' has some file changes$/) do |sha, table|
  commit = Commit.find_by_sha(sha)
  table.hashes.each do |row|
    commit.file_changes.create(filename: row['filename'], patch: row['patch'])
  end
end

Then(/^the following lines are (.*)$/) do |status, table|
  table.hashes.each do |row|
    expect(page).to have_css(".#{status}-line", text: row['Line'])
  end
end

Given(/^I have some commits of repository '(.*)' on Github$/) do |repo|
  @client = double
  @commits_result = {
    'sha' => '12321afdfa',
    'commit' => {
      'author' => {
        'date' => Date.today
      },
      'message' => 'message'
    },
    'committer' => {
      'login' => 'committer'
    }
  }

  @commits_result2 = {
    'sha' => '88383',
    'commit' => {
      'author' => {
        'date' => Date.today
      },
      'message' => 'message',
      'committer' => {
        'name' => 'committer2'
      }
    }
  }

  @commit_json = JSON(File.read("#{Rails.root}/spec/fixtures/commit.json"))
  @branches_json = JSON(File.read("#{Rails.root}/spec/fixtures/branches.json"))
  allow(@client).to receive(:commit).with(repo, anything, per_page: GITHUB_ENV['results_per_page']).and_return(@commit_json)
  allow(@client).to receive(:branches).with(repo, page: 1, per_page: GITHUB_ENV['results_per_page']).and_return(@branches_json)
  allow(@client).to receive(:branches).with(repo, page: 2, per_page: GITHUB_ENV['results_per_page'])
  allow(@client).to receive(:commits_since).with(repo, anything, anything).and_return([@commits_result, @commits_result2])
  $client = @client
end

Then(/^the commits of repository '(.*)' should be reloaded$/) do |repo|
  repository = Repository.find_by(full_name: repo)
  commit = repository.commits.find_by(sha: @commits_result['sha'], message: @commits_result['commit']['message'], committer: @commits_result['committer']['login'])
  expect(commit).to be_present
  expect(commit.file_changes.pluck(:patch)).to match_array @commit_json['files'].map { |file| file['patch'] }
  expect(repository.commits).to be_exists sha: @commits_result2['sha'], message: @commits_result2['commit']['message'], committer: @commits_result2['commit']['committer']['name']
end
