#
# Get URL params as Object
#
getUrlParams = ->
  params = {}
  for param in window.location.search.substr(1).split('&')
    [key, val] = param.split('=')
    params[key] = decodeURIComponent(val)
  return params

# Get current region selected by mouse.
# returns {fst: FIRST_ELEMENT, lst: LAST_ELEMENT}
getSelectionRange = ->
  sel = window.getSelection()
  if !sel.isCollapsed && range = sel.getRangeAt(0)
     fst: range.startContainer.parentNode
     lst: range.endContainer.parentNode

# Get Current line numbers selected by mouse.
# returns {fst: FIRST_LINE_NUMBER, lst: LAST_LINE_NUMBER}
getSelectionLineRange = ->
  return undefined if !(range = getSelectionRange())
  fst = Number findNearestLinenum($(range.fst), -1)
  lst = Number findNearestLinenum($(range.lst),  1)
  return undefined if isNaN(fst) || isNaN(lst)
  return fst: fst, lst: lst

# Get the nearest data-linenum attribute from ELEMENT
# including itself. DIRECTION should be +1 or -1
#
# returns: value of data-linenum attribute
#
findNearestLinenum = (element, direction = -1) ->
  name = 'data-linenum'
  sel = "[#{name}]"
  ele = $(element)
  return ele.attr(name) if ele.is(sel)

  # Since ele does not have data-linenum,
  # inject a dummy data-linenum to ele, and
  # find its index among the other data-lineum holders.
  ele.attr(name, '??')
  index = $(sel).index(ele)

  buddy = $(sel)[index + direction]
  ele.removeAttr(name)
  return $(buddy).attr(name)


# Scroll to ELEMENT at the center of window
#
scrollToCenter = (element) ->
  ele = $(element)
  eleH = ele.height()
  winH = $(window).height()

  offset = ele.offset().top
  offset = offset - ((winH / 2) - (eleH / 2)) if eleH < winH

  $('html, body').animate({scrollTop: offset}, 600)

#
# Scroll to AI at the center of window and
# add class="marked" to highlight
#
markAndScrollToActionItem = (ai) ->
  ele = $("[data-action-item='#{ai}']")
  ele.parent().addClass('marked')
  scrollToCenter(ele)

# Get the JSON format of the current page.
#
# If the current page is /mintes/1, it will return /minutes/1.json.
# This function is supposed to be used to get a JSON-style content of
# currently displayed minute.
#
# returns JSON encoded structure.
#
getCurrentPageAsJSON = () ->
  res = $.ajax
    url: window.location.pathname + ".json"
    async: false
    dataType: 'json'
  json = res.responseJSON
  return json

# Convert markdown TEXT to html and update element UPDATE_ELEMENT.
#
renderMarkdown = (text, update_element) ->
  $.post '/minutes/preview', {text: text}, (data) ->
    $(update_element).html(data)

#
# Remove Headings of list item ``+ (A) ``
#
removeHeader = (string) ->
  string.replace(/^ *[*+-] */, '')

# Return a regexp to match a string in the array STRINGS.
# This is a JavaScript verion of Emacs regexp-opt
# https://gist.github.com/kawanet/5540864
#
array_to_regexp = (strings, regexp_option) ->
  re = strings
    .sort (a, b) ->
      b.length - a.length
    .map (str) ->
      str.replace /\W/g, (match) ->
        "\\" + match
    .join("|")
  return new RegExp(re, regexp_option)

#
# Remove trailing ``-->(...)'' from STRING.
#
removeTrailer = (string) ->
  string.replace(/(．)? *--(>|&gt;)\(.*\) */, '')


# Get the minimum indent level of LINES.
# LINES has multiple lines separated by "\n".
#
# For example, if LINES has these three lines:
#
# |    first line
# |      second line
# |  third line
#
# this function returns the minimum indent level as 2.
# calculated from the third line.
#
getIndentLevel = (lines) ->
  indent = 9999
  for line in lines.split("\n")
    match = /^ */.exec(line)
    if match && match[0].length < indent
      indent = match[0].length
  return indent

# Decrease indents of LINES by LEVEL.
# LINES has multiple lines separated by "\n".
#
# For example, if you call this function with LEVEL is 2 and LINES has
# these three lines:
#
# |    first line
# |      second line
# |  third line
#
# this function returns:
#
# |  first line
# |    second line
# |third line
#
chopIndentLevel = (lines, level) ->
  return lines if level == 0
  space = new RegExp("^#{' '.repeat(level)}")
  result = ''
  for line in lines.split("\n")
    result += line.replace(space, '') + "\n"
  return result

# Decrease indents of LINES to zero.
#
chopIndent = (lines) ->
  chopIndentLevel(lines, getIndentLevel(lines))

# Find words listed in KEYWORDS by scanning the LINES.
#
# If LINES has a string enumerated in KEYWORDS the sting will
# be counted up as a candidate.
#
# For example,
#
# LINES:
# | nomlab/foo is great, but nomlab/bar is not.
# | blah blah...
#
# KEYWORDS:
#   ["nomlab/foo", "nomlab/bar", "nomlab/baz"]
#
# returns:
#   ["nomlab/foo", "nomlab/bar"]
#
# FIXME: this function breaks original KEYWORDS
#
findKeywords = (lines, keywords) ->
  regexp = array_to_regexp(keywords, "g")
  repos = lines.match(regexp) || []
  keywords = repos.filter((x, i, self) ->
    self.indexOf(x) == i
  )
  keywords

# Extract lines from line number FST to LST.
#
extractLines = (lines, fst, lst) ->
    lines.split("\n")[fst-1 .. lst-1].join("\n")

# Open new github issue draft
#   repos: yoshinari-nomura/sandbox
#   issue: {title: TEST, body: Blah, labels: bug, assignee: yoshinari-nomura}
newGithubIssue = (repos, issue) ->
  github = 'https://github.com'
  window.open("#{github}/#{repos}/issues/new?#{$.param(issue)}")

# Post new github comment
#   repos: nomlab/sandbox
#   issue: {body: Blah}
newGithubComment = (repos, target_issue_num, comment) ->
  github = 'https://github.com'
  github_api = 'https://api.github.com'
  res = $.ajax
    async: false
    type: "POST"
    url: "/minutes/comment"
    dataType: 'json'
    data:
      url: "#{github_api}/repos/#{repos}/issues/#{target_issue_num}/comments"
      comment: comment
    success: (res) ->
      window.open(res.html_url)
    error: (res) ->
      alert "Failed to create comment"

# Get User's Github *public* repositories in ORGANIZATION
# https://developer.github.com/v3/repos/#list-organization-repositories
#
getGithubPublicRepositories = (organization, full) ->
  res = $.ajax
    url: "https://api.github.com/orgs/#{organization}/repos"
    async: false
    dataType: 'json'
  repos = []
  for r in res.responseJSON
    repos.push (if full then r.full_name else r.name)
  return repos

# Get User's Github *public* repositories in ORGANIZATION using JSONP
# https://developer.github.com/v3/repos/#list-organization-repositories
#
getGithubPublicRepositoriesJSONP = (organization, full, callback) ->
  res = $.ajax
    url: "https://api.github.com/orgs/#{organization}/repos"
    dataType: 'jsonp'
    success: (res) ->
      repos = []
      for r in res.data
        repos.push (if full then r.full_name else r.name)
      callback(repos)

# Get User's Github *ALL* repositories in user's default organization
# /users/repositories returns a same structure with:
# https://developer.github.com/v3/repos/#list-organization-repositories
#
# FIXME: needs same interface with getGithubPublicRepositories
#
getGithubAllHomeRepositories = (full = false) ->
  res = $. ajax
    async: false
    type: "GET"
    url: "/users/repositories"
    dataType: "json"
  repos = []
  for r in (res.responseJSON || [])
    repos.push (if full then r.full_name else r.name)
  return repos

################################################################
# setup and DOM manipulations

setupAutoCompleteEmoji = (element) ->
  img_url = "https://raw.githubusercontent.com/Ranks/emojify.js/master/src/images/emoji"
  $(element).textcomplete [
      match: /\B:([\-+\w]*)$/

      search: (term, callback) ->
        callback $.map window.emoji_list, (emoji) ->
          return emoji if emoji.indexOf(term) >= 0
          return null

      template: (value) ->
        "<img src=\"#{img_url}/#{value}.png\" width=\"16\"></img> #{value}"

      replace:  (value) ->
        ":#{value}:"

      index: 1
    ],
    onKeydown: (e, commands) ->
      return commands.KEY_ENTER if e.ctrlKey && e.keyCode == 74 # CTRL-J

setupAutoCompleteRepository = (element, repos_list) ->
  $(element).textcomplete [
      match: /([\-+\w]*)$/

      search: (term, callback) ->
        callback $.map repos_list, (repos) ->
          return repos if repos.indexOf(term) >= 0
          return null

      replace:  (value) ->
        "#{value}"

      index: 1
    ],
    onKeydown: (e, commands) ->
      return commands.KEY_ENTER if e.ctrlKey && e.keyCode == 74 # CTRL-J
    zIndex: 10000
    listPosition: (position) ->
      this.$el.css(this._applyPlacement(position))
      this.$el.css('position', 'absolute')
      return this

setupAutoCompleteTag = (element) ->
  $.ajax
    async:     false
    type:      "GET"
    url:       "/tags"
    dataType:  "json"
    success:   (tags, status, xhr)   ->
      window.tag_list = $.map tags, (tag) ->
        return tag.name

  $(element).textcomplete [
      match: /([\-+\w]*)$/

      search: (term, callback) ->
        callback $.map window.tag_list, (tag) ->
          return tag if tag.indexOf(term) >= 0
          return null

      replace: (value) ->
        "#{value}"

      index: 1
    ],
    onKeydown: (e, commands) ->
      return commands.KEY_ENTER if e.ctrlKey && e.keyCode == 74 # CTRL-J
    zIndex: 10000
    listPosition: (position) ->
      this.$el.css(this._applyPlacement(position))
      this.$el.css('position', 'absolute')
      return this

setupTabCallback = ->
  $('a[data-toggle="tab"]').on 'shown.bs.tab', (e) ->
    old = $(e.relatedTarget).attr('href') # previous active tab
    cur = $(e.target).attr('href')  # newly activated tab
    if $(cur).attr('id') == "preview"
      renderMarkdown($(old).children('textarea').val(), $(cur))

# setup Tag manipulation form
#
# #current-tags .. display current tag labes (div)
# #tag-names ... tags separated by space (hidden text field)
# #tag-name .. current input field
# #add-tag-button ... add button
#
setupTagForm = (selector) ->
  str_to_ary = (str) ->
    str = str.trim()
    return [] if str == ''
    return str.split(/\s+/)

  tags = ->
    str_to_ary($('#tag-names').val())

  set_tags = (tag_array) ->
    $('#tag-names').val(tag_array.join(' '))
    return tags()

  add_tags = (tag_array) ->
    ary = tags()
    tag_array.map (tag) ->
      ary.push(tag) if !(tag in ary)
    set_tags(ary)

  remove_tag = (tag) ->
    ary = tags().filter (x) -> x != tag.trim()
    set_tags(ary)

  redisplay = ->
    $('#current-tags').empty()
    tags().map (tag_name) ->
      $('#current-tags').append """
        <span class="label label-primary tag-label">
          <span class="glyphicon glyphicon-tag" aria-hidden="true"></span> #{tag_name}
          <span id="#{tag_name}" class="glyphicon glyphicon-remove remove-tag-icon" aria-hidden="true"></span></span>
      """

  $('#current-tags').on 'click', '.remove-tag-icon', (e) ->
    remove_tag($(this).attr('id'))
    redisplay()

  $('#tag-add-button').on 'click', (e) ->
    add_tags(str_to_ary($('#tag-name').val()))
    $('#tag-name').val('') # clear input field
    redisplay()

  $('#tag-name').on 'keypress', (e) ->
    e.preventDefault() if e.keyCode == 13 # Enter

  redisplay() if $('#tag-names').val()?
  setupAutoCompleteTag('#tag-name')

setupAutoCompleteSearchForm = (element) ->
  $.ajax
    async:     false
    type:      "GET"
    url:       "/tags"
    dataType:  "json"
    success:   (tags, status, xhr)   ->
      window.tag_list = $.map tags, (tag) ->
        return tag.name

  $.ajax
    async:     false
    type:      "GET"
    url:       "/users"
    dataType:  "json"
    success:   (users, status, xhr)   ->
      window.user_list = $.map users, (user) ->
        return user.screen_name

  $(element).textcomplete [
      match:  /tag:([\-+\w]*)$/

      search: (term, callback) ->
        callback $.map window.tag_list, (tag) ->
          return tag if tag.indexOf(term) >= 0
          return null

      replace: (value) ->
        "tag:#{value}"

      index: 1
    ],
    onKeydown: (e, commands) ->
      return commands.KEY_ENTER if e.ctrlKey && e.keyCode == 74 # CTRL-J
    zIndex: 10000
    listPosition: (position) ->
      this.$el.css(this._applyPlacement(position))
      this.$el.css('position', 'absolute')
      return this

  $(element).textcomplete [
      match:  /author:([\-+\w]*)$/

      search: (term, callback) ->
        callback $.map window.user_list, (user) ->
          return user if user.indexOf(term) >= 0
          return null

      replace: (value) ->
        "author:#{value}"

      index: 1
    ],
    onKeydown: (e, commands) ->
      return commands.KEY_ENTER if e.ctrlKey && e.keyCode == 74 # CTRL-J
    zIndex: 10000
    listPosition: (position) ->
      this.$el.css(this._applyPlacement(position))
      this.$el.css('position', 'absolute')
      return this

setupMinuteSearchButtonCallback = ->
  $('#search-minutes-by-tag').on 'click', (e) ->
    $('tbody').empty()
    tagName = $('#tag-name').val()
    if tagName is ""
      $. ajax
        async: false
        type: "GET"
        url: "/minutes"
        dataType: "json"
        success:  (minutes, status, xhr)   ->
          unless minutes is null
            $.map minutes, (minute) ->
              displayMinuteRow(minute)
    else
      $. ajax
        async: false
        type: "GET"
        url: "/minutes/search_by_tag"
        dataType: "json"
        data:
          tag_name: $('#tag-name').val()
        success:  (minutes, status, xhr)   ->
          unless minutes is null
            $.map minutes, (minute) ->
              displayMinuteRow(minute)

displayMinuteRow = (minute) ->
  $('tbody').append("<tr>\
                       <td><a href='/minutes/#{minute.id}'>#{minute.title || ""}</a></td>\
                       <td>#{minute.dtstart || ""}</td>\
                       <td>#{minute.location || ""}</td>\
                       <td>#{minute.author?.name || ""}</td>\
                       <td><a href='/minutes/#{minute.id}/edit'><i class='fa fa-pencil'></i></a></td>\
                       <td><a href='/minutes/#{minute.id}/reuse'><i class='fa fa-repeat'></i></a></td>\
                       <td><a href='/minutes/#{minute.id}' data-method='delete' rel='nofollow' data-confirm='Are you sure?'><i class='fa fa-trash'></i></a></td>\
                     </tr>")


#
# Set values to Issue form selected by ID
#
# options = {
#   selector: CSS selector of target form like '#create-issue-modal'
#   title: issue title (string)
#   organization: github organization
#   repos_candidates: Repository names to be listed in repository menu
#   repos_all: All repository names in ORGANIZATION
#   description: Issue description (markdown string)
# }
#
setupIssueForm = (options) ->
  id = options.selector
  $("#{id} #title").val(options.title)
  $("#{id} #selected-range").val(options.description)
  $("#{id} #repository").val('')

  str_repos = ""
  for r in options.repos_candidates
    str_repos = str_repos + "<label class='label label-primary candidate-repository'>#{r}</label> "
  $("#{id} #repositories-list").replaceWith("<p id='repositories-list'><i class='fa fa-lightbulb-o fa-fw'></i>#{str_repos}<p>")

  setupAutoCompleteRepository("#repository", options.repos_all)

  $("#{id} .candidate-repository").on 'click', (event) ->
    $("#{id} #repository").val(event.target.innerHTML)

  $("#{id} #submit-button").off('click').on 'click', ->
    param = $("#{id} #submit-form").serializeArray()
    if param[2].value
      issue =
        title: param[0].value
        body: param[1].value
        projects: "#{organization}/1"
        # labels: "" # FIXME
        # assignee: minute.screen_name # FIXME
      newGithubIssue("#{options.organization}/#{param[2].value}", issue)
      $('#create-issue-modal').modal("hide")
    else
      alert "No repository specified"
  return $("#{id}")

#
# Set values to comment form selected by ID
#
# options = {
#   selector: CSS selector of target form like '#create-comment-modal'
#   repo: Repository name to comment
#   target: Issue number to comment
#   description: Issue description (markdown string)
# }
#
setupCommentForm = (options) ->
  id = options.selector
  $("#{id} #target").text("Create comment to #{options.organization}/#{options.repo}/##{options.target}")
  $("#{id} #comment-body").val(options.description)

  $("#{id} #submit-button").off('click').on 'click', ->
    param = $("#{id} #comment-form").serializeArray()
    if param[0].value
      comment = param[0].value
      newGithubComment("#{options.organization}/#{options.repo}","#{options.target}", comment)
      $('#create-comment-modal').modal("hide")
    else
      alert "Please input comment"
  return $("#{id}")

ready = ->
  repos_all = getGithubAllHomeRepositories()
  setupAutoCompleteEmoji('#minute_content')
  setupAutoCompleteSearchForm('#search-form')
  setupTabCallback()
  setupTagForm('#tag-form')
  setupMinuteSearchButtonCallback()
  if ai = getUrlParams().ai
    markAndScrollToActionItem(ai)

  $('.action-item').on 'click', (event) ->
    event.preventDefault()
    if range = getSelectionLineRange()
      minute = getCurrentPageAsJSON()
      description = chopIndent(extractLines(minute.content, range.fst, range.lst))
      title = removeHeader(removeTrailer(description.trim().split("\n")[-1..][0]))
      ai_num = $(this).attr("data-action-item")
      url = "#{this.href.split('?')[0]}?ai=#{ai_num}"
      form = setupIssueForm
        selector: '#create-issue-modal'
        title: title
        organization: minute.organization
        repos_candidates: findKeywords(minute.content, repos_all)
        repos_all: repos_all
        description: "Created from [AI#{ai_num}](#{url}) of minute #{minute.id}.\n#{description}"
      form.modal("show")
    else
      alert "No valid range is specified."

  $('.github-issue').on 'click',(event) ->
    event.preventDefault()
    if range = getSelectionLineRange()
      minute = getCurrentPageAsJSON()
      description = chopIndent(extractLines(minute.content, range.fst, range.lst))
      ai_num = $(this).attr("data-action-item")
      url = "#{window.location.href.split('?')[0]}?ai=#{ai_num}"
      form = setupCommentForm
        selector: '#create-comment-modal'
        organization: minute.organization
        repo: $(this).attr("href").split('/')[4]
        target: $(this).attr("href").split('/')[6]
        description: "Commented from [minute #{minute.id}](#{url}).\n#{description}"
      form.modal("show")
    else
      location.href = $(this).attr("href")

$(document).ready(ready)
