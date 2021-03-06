snippets = {}
randomComments = {}

textcompleteOptions = [
  match: /\b(\w+)$/
  index: 1
  search: (term, callback) ->
    callback($.map(snippets, (value, key) ->
      if matchString(key, term) then key else null
    ))
  replace: (word) ->
    "#{snippets[word]}".split('[[cursor]]')
]

matchString = (str, term) ->
  regex = ''
  for ch in term
    regex += "#{ch}.*"
  str.match(regex)

sample = (items) ->
  items[Math.floor(Math.random() * items.length)]

removeItem = (items, value) ->
  items.filter (val) ->
    val != value

fetchSnippets = ->
  $.ajax
    url: '/snippets'
    dataType: 'json'
    success: (data) ->
      snippets = data.snippets

fetchRandomComments = ->
  $.ajax
    url: '/commits_suggestions'
    dataType: 'json'
    success: (data) ->
      randomComments = data.comments

$ ->
  fetchSnippets()
  fetchRandomComments()

  $fileChangeContent = $('.file-change-content')
  $fileChangeContent.find('textarea[name=body]').textcomplete(textcompleteOptions)

  $fileChangeContent.on 'keydown', 'textarea[name=body]', (e) ->
    if (e.keyCode || e.which) == 9
      e.preventDefault()
      caretPos = $(this)[0].selectionStart
      val = $(this).val()
      $(this).val("#{val.substring(0, caretPos)}  #{val.substring(caretPos)}")
      $(this)[0].selectionStart = $(this)[0].selectionEnd = caretPos + 2

  $fileChangeContent.on 'change', '[name=rules]', (e) ->
    $this = $(this)
    text = sample(randomComments[$this.val()])
    $this.closest('form').find('[name=body]').val(text)
    false

  $fileChangeContent.on 'click', '.cancel-btn', ->
    $(this).closest('.comment-form').remove()
    false

  $fileChangeContent.on 'click', '.random-comment', ->
    $this = $(this)
    $body = $this.closest('form').find('[name=body]')
    comments = randomComments[$this.siblings("[name=rules]").val()]
    comments = removeItem(comments, $body.val())
    if comments.length > 0
      $body.val(sample(comments))
    false

  $fileChangeContent.find('p').on 'click', ->
    $this = $(this)
    $comments = $this.siblings('.comments')
    return if $comments.find('.comment-form').length > 0
    $.ajax
      url: '/comments/new'
      method: 'get'
      data:
        line: $this.closest('.line-change').data('line')
        filename: $this.closest('.file-change').find('.file-change-header').text()
        commit_id: location.pathname.split('/').pop()

      success: (data) ->
        $comments.append(data)
        $textarea = $comments.find('[name=body]')
        $textarea.focus()
        $textarea.textcomplete(textcompleteOptions)


