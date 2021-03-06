Feature: As a user
  I want to fetch all recent commits of watched repositories from github

Scenario Outline:
  Given I have the watched repository '<Repository>'
  And I have some commits of repository '<Repository>' on Github
  And I am on the commits page
  When I click on '<Action>'
  Then I should see 'Request sent. Please reload page later'
  And I wait for 'CommitsFetch' workers to finish
  And I wait for 'RepositoryCommitsFetch' workers to finish
  And I wait for 'FileChangesFetch' workers to finish
  And I wait for 'CommentsFetch' workers to finish
  Then the commits of repository '<Repository>' should be reloaded

  Examples:
  | Repository   | Action             |
  | org/repo     | Fetch commits      |
  | org1/repo1   | Reload all commits |
