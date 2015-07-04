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



# Get the markdown source code of the current page.
#   fst: first line number
#   lst: last line number
# returns JSON encoded markdown source code
getOriginalMinuteAsJSON = () ->
  res = $.ajax
    url: window.location.pathname + ".json"
    async: false
    dataType: 'json'
  json = res.responseJSON
  return json

renderMarkdown = (text, update_element) ->
  $.post '/minutes/preview', {text: text}, (data) ->
    $(update_element).html(data)

# Stub getOriginalMinuteAsJSON for test
getOriginalMinuteAsJSON_Stub = (fst, lst) ->
  return {
    title: "Minute 2015-06-10"
    body: "# Blah\n+ fst: #{fst}\n+ lst: #{lst}\n"
    labels: "bug"
  }

#
# Remove Headings of list item ``+ (A) ``
#
removeHeader = (string) ->
  string.replace(/^ *[*+-] */, '')
#  string.replace(/^ *[*+-]( \(.\))? */, '')

# Return a regexp to match a string in the array STRINGS
# JavaScript verion of Emacs regexp-opt
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
# Remove trailing ``-->(...)''
#
removeTrailer = (string) ->
  string.replace(/(．)? *--(>|&gt;)\(.*\) */, '')

getIndentLevel = (string) ->
  indent = 9999
  for line in string.split("\n")
    match = /^ */.exec(line)
    if match && match[0].length < indent
      indent = match[0].length
  return indent

chopIndentLevel = (string, level) ->
  return string if level == 0
  space = new RegExp("^#{' '.repeat(level)}")
  result = ''
  for line in string.split("\n")
    result += line.replace(space, '') + "\n"
  return result

chopIndent = (string) ->
  chopIndentLevel(string, getIndentLevel(string))

# Open new github issue draft
#   repos: yoshinari-nomura/sandbox
#   issue: {title: TEST, body: Blah, labels: bug, assignee: yoshinari-nomura}
newGithubIssue = (repos, issue) ->
  github = 'https://github.com'
  window.open("#{github}/#{repos}/issues/new?#{$.param(issue)}")

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
  # alert "REPOS:" + repos.join("\n")
  return repos

# Get User's Github *public* repositories in ORGANIZATION
# https://developer.github.com/v3/repos/#list-organization-repositories
# JSONP should be async
getGithubPublicRepositoriesJSONP = (organization, full, callback) ->
  res = $.ajax
    url: "https://api.github.com/orgs/#{organization}/repos"
    dataType: 'jsonp'
    success: (res) ->
      repos = []
      for r in res.data
        repos.push (if full then r.full_name else r.name)
      callback(repos)

# Guess suitable repository candidates by
# scanning the content of MINUTE.
#
# Candidates are scanned from user's profile
# via GitHub API
#
getGithubTargetRepository = (minute, repos_list) ->
  regexp = array_to_regexp(repos_list, "g")
  repos = minute.content.match(regexp)
  repos_list = repos.filter((x, i, self) ->
    self.indexOf(x) == i
  )
  # alert (if repos then repos.join("\n") else "NO match")
  repos_list

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

setupTabCallback = ->
  $('a[data-toggle="tab"]').on 'shown.bs.tab', (e) ->
    old = $(e.relatedTarget).attr('href') # previous active tab
    cur = $(e.target).attr('href')  # newly activated tab
    if $(cur).attr('id') == "preview"
      renderMarkdown($(old).children('textarea').val(), $(cur))

dipslaySelectionLineRange = (str) ->
  $('#selected-range').append("#{str}")

displayGithubRepository = (repos_list) ->
  str_repos = ""
  for r in repos_list
    str_repos = str_repos + "<label class='label label-primary candidate-repository'>#{r}</label> "
  $('#repositories-list').replaceWith("<p id='repositories-list'><i class='fa fa-lightbulb-o fa-fw'></i>#{str_repos}<p>")
  $('.candidate-repository').click (event) ->
    $('#repository').val(event.target.innerHTML)

getRepository = () ->
  res = $. ajax
    async: false
    type: "GET"
    url: "/users/repositories"
    dataType: "json"
  createRegularExpression(res)

createRegularExpression = (data) ->
  data_list = []
  for d in data.responseJSON
    data_list.push(d[1][1])
  data_list

getSelectionLine = (body, fst, lst) ->
    line = body.content.split("\n")[fst-1 .. lst-1].join("\n")

ready = ->
  repos_list = getRepository()
  minute = getOriginalMinuteAsJSON()
  setupAutoCompleteEmoji('#minute_content')
  setupTabCallback()

  $('.action-item').click (event) ->
    if range = getSelectionLineRange()
      line = getSelectionLine(minute, range.fst, range.lst)
      setupAutoCompleteRepository('#repository', repos_list)
      repos_list = getGithubTargetRepository(minute, repos_list)
      displayGithubRepository(repos_list)
      dipslaySelectionLineRange(chopIndent(line))
      $('#create-issue-modal').modal("show")
    else
      alert "No valid range is specified."
    event.preventDefault()

  $('#submit-button').click ->
    param = $('#submit-form').serializeArray()
    if param[1].value
      issue =
        title: removeTrailer(removeHeader(param[0].value.split("\n")[-1..][0]))
        body: param[0].value
        labels: "" # FIXME
        # assignee: minute.screen_name # FIXME
      newGithubIssue("#{minute.organization}/#{param[1].value}", issue)
      $('#create-issue-modal').modal("hide")
    else
      alert "No inputed repository"

$(document).ready(ready)
