ready = ->
  $.ajax
    async:     false
    type:      "GET"
    url:       "/tags"
    dataType:  "json"
    success:   (data, status, xhr)   ->
      window.tag_list = "sample1"
    error:     (xhr,  status, error) ->
      alert status
