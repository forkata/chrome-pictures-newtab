class ChromePicturesNewTab

  constructor: ($viewport) ->
    @$viewport = $viewport

window.onload = ->
  classicNewTab = new ChromePicturesNewTab(document.body)
