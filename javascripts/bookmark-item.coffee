namespace "ChromePicturesNewTab", (exports) ->
  class exports.BookmarkItem

    constructor: (@bookmark) ->
      @bookmarkId = @bookmark.id

    render: (@viewport) ->
      @el = document.createElement("li")
      @el.className = "bookmark-item"
      @el.className += " folder-item" unless @bookmark.url

      @link = document.createElement("a")
      @link.className = "clearfix"
      @link.setAttribute("href", @bookmark.url) unless @isFolder()

      @label = document.createElement("span")
      @label.innerHTML = @bookmark.title.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      @label.innerHTML += " &raquo;" if @isFolder()

      @link.appendChild(@label)
      @el.appendChild(@link)
      @viewport.appendChild(@el)

      @link.addEventListener "mouseover", =>
        if @mouseoutTimeout
          clearTimeout(@mouseoutTimeout)
          @mouseoutTimeout = null
        else
          _.delay =>
            @delegate?.BookmarkItemDidMouseOver?(this)
          , 110
      , false

      @link.addEventListener "mouseout", =>
        unless @mouseoutTimeout
          @mouseoutTimeout = _.delay =>
            @delegate?.BookmarkItemDidMouseOut?(this)
            @mouseoutTimeout = null
          , 100
      , false

      @link.addEventListener "mousedown", =>
        @delegate?.BookmarkItemWillClick?(this)
      , false

      @link.addEventListener "click", =>
        @delegate?.BookmarkItemDidClick?(this)
      , false

    isFolder: ->
      !@bookmark.url
