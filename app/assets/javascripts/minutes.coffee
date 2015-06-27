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
  fst = Number $(range.fst).attr('data-linenum')
  lst = Number $(range.lst).attr('data-linenum')
  return undefined if isNaN(fst) || isNaN(lst)
  return fst: fst, lst: lst

# Get the markdown source code of the current page.
#   fst: first line number
#   lst: last line number
# returns JSON encoded markdown source code
getOriginalMinuteAsJSON = (fst, lst) ->
  res = $.ajax
    url: window.location.pathname + ".json"
    async: false
    dataType: 'json'
  json = res.responseJSON
  json.body  = json.content.split("\n")[fst-1 .. lst-1].join("\n")
  return json

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

ready = ->
  $('.action-item').click (event) ->
    if range = getSelectionLineRange()
      minute = getOriginalMinuteAsJSON(range.fst, range.lst)
      repos = minute.repos
      issue =
        title: removeTrailer(removeHeader(minute.body.split("\n")[-1..][0]))
        body: chopIndent(minute.body)
        labels: "" # FIXME
        assignee: minute.screen_name # FIXME
      newGithubIssue(repos, issue)
    else
      alert "No valid range is specified."
    event.preventDefault()

$(document).ready(ready)
