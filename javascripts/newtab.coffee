class ChromePicturesNewTab
  @FetchSize: 500

  constructor: ($viewport) ->
    @$viewport = $viewport

    @$photo = $("#photo")
    @$photoTitleLink = $("#photo-title-link")
    @$photoTitleOwnerLink = $("#photo-title-owner-link")
    @$photoRefreshLink = $("#photo-refresh-link")
    @$photoPinLink = $("#photo-pin-link")

    @viewportWidth = @$viewport.width()
    @viewportHeight = @$viewport.height()
    window.addEventListener "resize", =>
      @viewportWidth = @$viewport.width()
      @viewportHeight = @$viewport.height()
    , false

    @ensureCachedPhoto().then (photo) =>
      @displayPhoto(photo)

      timedOut = ((new Date()).getTime() -  parseInt(photo.timestamp || 0, 10)) > 60000
      if timedOut && !photo.isPinned
        @refreshPhoto()

    @bookmarksBar = new BookmarksBar()
    @bookmarksBar.render(@$viewport[0])

    @$photoRefreshLink.on "click", =>
      @refreshPhoto().then (photo) =>
        @displayPhoto(photo)

    @$photoPinLink.on "click", =>
      chrome.storage.local.set { photoIsPinned: true }, =>
        @$photoPinLink.text("Pinned")

    document.body.addEventListener "click", (event) =>
      unless $(event.target).closest(".bookmarks-popup").length
        @bookmarksBar.hidePopupIfPresent()
    , false

    window.addEventListener "resize", =>
      @bookmarksBar.hidePopupIfPresent()
    , false

  displayPhoto: (photo) ->
    @$photo.css "background-image", "url('#{photo.url}')"
    # @$photo.css "background-image", "url(#{photo.dataUri})"

    @$photoTitleLink.text(photo.title)
    @$photoTitleLink.attr("href", photo.webUrl)
    @$photoTitleOwnerLink.html("&copy; #{photo.ownerName}")
    @$photoTitleOwnerLink.attr("href", photo.ownerWebUrl)

    if photo.isPinned
      @$photoPinLink.text("Pinned")
    else
      @$photoPinLink.text("Pin")

  refreshPhoto: ->
    @fetchPhoto().then((photo) =>
      @savePhoto(photo)
    ).then =>
      @cachedPhoto()

  ensureCachedPhoto: ->
    @cachedPhoto().then(null, =>
      @fetchPhoto().then (photo) =>
        @savePhoto(photo)
    ).then =>
      @cachedPhoto()

  cachedPhoto: ->
    new RSVP.Promise (resolve, reject) ->
      try
        chrome.storage.local.get [
          "photoDataUri"
          "photoUrl"
          "photoContentType"
          "photoTitle"
          "photoWebUrl"
          "photoOwnerName"
          "photoOwnerWebUrl"
          "photoTimestamp"
          "photoIsPinned"
        ], (data) ->
          if data.photoDataUri?.length > 0
            console.log "Photo cache hit"
            resolve({
              dataUri: data.photoDataUri
              url: data.photoUrl
              contentType: data.photoContentType
              title: data.photoTitle
              webUrl: data.photoWebUrl
              ownerName: data.photoOwnerName
              ownerWebUrl: data.photoOwnerWebUrl
              timestamp: data.photoTimestamp
              isPinned: data.photoIsPinned
            })
          else
            console.warn "Photo cache miss"
            reject()
      catch err
        console.error "Photo cache error"
        reject(err)

  savePhoto: (photo) ->
    console.log "saving", photo
    new RSVP.Promise (resolve, reject) ->
      try
        chrome.storage.local.set({
          photoDataUri: photo.dataUri
          photoUrl: photo.url
          photoContentType: photo.contentType
          photoTitle: photo.title
          photoWebUrl: photo.webUrl
          photoOwnerName: photo.ownerName
          photoOwnerWebUrl: photo.ownerWebUrl
          photoTimestamp: (new Date()).getTime()
          photoIsPinned: false
        }, ->
          console.log "Photo saved"
          resolve()
        )
      catch err
        console.error "Error saving photo", err
        reject(err)

  fetchPhoto: ->
    new RSVP.Promise (resolve, reject) =>
      @fetchPhotos().then (resp) =>
        photos = $(resp).find("photo").toArray()
        index = parseInt(Math.random() * photos.length * 10, 10) % photos.length
        photo = photos[index]
        title = photo.getAttribute("title")
        webUrl = @photoWebUrl(photo.getAttribute("owner"), photo.getAttribute("id"))
        ownerName = photo.getAttribute("ownername")
        ownerWebUrl = @ownerWebUrl(photo.getAttribute("owner"))

        console.log "Use photo at index #{index} of #{photos.length} photos", photo
        console.log " * title: #{title}"
        console.log " * webUrl: #{webUrl}"
        console.log " * ownerName: #{ownerName}"

        @fetchPhotoSizes(photo.getAttribute("id")).then (resp) =>
          largestSize = _.reduce($(resp).find("size").toArray(), (largest, size) =>
            largest = size unless largest

            largestWidth = largest.getAttribute("width")
            largestHeight = largest.getAttribute("height")
            sizeWidth = size.getAttribute("width")
            sizeHeight = size.getAttribute("height")

            if sizeWidth <= @viewportWidth || sizeHeight <= @viewportHeight
              largestArea = largestWidth * largestHeight
              sizeArea = sizeWidth * sizeHeight
              largest = size if sizeArea > largestArea

            largest
          null)

          url = largestSize.getAttribute("source")
          contentType = "image/#{url.match(/\.([^.]+)$/)[1]}"
          photo.setAttribute "url", url
          photo.setAttribute "content-type", contentType

          @urlToBase64(url, contentType).then (dataUri) =>
            resolve({
              dataUri: dataUri
              url: url
              contentType: contentType
              title: title
              webUrl: webUrl
              ownerName: ownerName
              ownerWebUrl: ownerWebUrl
            })
      .catch ->
        console.error "Error fetching photo", arguments
        reject.apply(null, arguments)

  fetchPhotos: ->
    @flickrApiRequest("flickr.photos.search", {
      per_page: ChromePicturesNewTab.FetchSize
      page: 1

      tags: "NASA"
      extras: "license,owner_name"
      license: "1,2,3,4,5,7"
    })

  fetchPhotoSizes: (id) ->
    @flickrApiRequest("flickr.photos.getSizes", {
      photo_id: id
    })

  flickrApiRequest: (method, params) ->
    new RSVP.Promise (resolve, reject) ->
      $.ajax({
        type: "GET"
        url: "https://api.flickr.com/services/rest"
        data: _.extend({
          method: method
          api_key: "7d05080a526b965ba4978c0656dfdaf3"
        }, params)
      }).done((resp, status, req) ->
        resolve resp, status, req
      ).fail((req, status, message) ->
        reject req, status, message
      )

  photoWebUrl: (userId, photoId) ->
    "https://www.flickr.com/photos/#{userId}/#{photoId}"

  ownerWebUrl: (userId) ->
    "https://www.flickr.com/photos/#{userId}"

  urlToBase64: (url, contentType) ->
    new RSVP.Promise (resolve) ->
      canvas = document.createElement('CANVAS')
      ctx = canvas.getContext('2d')
      img = new Image()
      img.crossOrigin = 'Anonymous'
      img.onload = ->
        canvas.height = img.height
        canvas.width = img.width
        ctx.drawImage(img, 0, 0)

        dataURL = canvas.toDataURL(contentType)
        resolve(dataURL)
        $(canvas).remove()
      img.src = url

  #
  # Private Classes
  #

  class BookmarksBar

    constructor: ->
      @bookmarksLoaded = new RSVP.Promise (resolve, reject) =>
        chrome.bookmarks.getChildren "1", (bookmarks) =>
          @bookmarks = bookmarks
          resolve(@bookmarks)

    render: (@$viewport) ->
      @$el = document.createElement("div")
      @$el.id = "bookmarks-bar"

      @$viewport.appendChild(@$el)

      @bookmarksLoaded.then =>
        @mainBookmarksList = new BookmarksList(@bookmarks, { delegate: this })
        @mainBookmarksList.render(@$el)

        @otherBookmarksList = new BookmarksList([{ id: "2", title: "Other Bookmarks" }], { delegate: this })
        @otherBookmarksList.render(@$el)
        @otherBookmarksList.$el.className += " other-bookmarks"

    hidePopupIfPresent: ->
      @otherBookmarksList.hidePopupIfPresent()
      @mainBookmarksList.hidePopupIfPresent()

    BookmarksListDidOpenFolder: (bookmarksList) ->
      if bookmarksList == @mainBookmarksList
        @otherBookmarksList.hidePopupIfPresent()
      else
        @mainBookmarksList.hidePopupIfPresent()

    BookmarksListDidMouseOverItem: (bookmarksList, bookmarkItem) ->
      if bookmarkItem.isFolder()
        if bookmarksList == @mainBookmarksList
          @otherBookmarksList.hidePopupIfPresent()
        else
          @mainBookmarksList.hidePopupIfPresent()
      else
        @hidePopupIfPresent()

  class BookmarksList

    constructor: (@bookmarks, @options = {}) ->
      @delegate = @options.delegate

    render: (@$viewport) ->
      @$el = document.createElement("ul")
      @$el.className = "bookmarks-list clearfix"

      for bookmark in @bookmarks
        bookmarkItem = new BookmarkItem(bookmark)
        bookmarkItem.delegate = this
        bookmarkItem.render(@$el)

      @$viewport.appendChild(@$el)

    hidePopupIfPresent: ->
      if @popup
        @popup.hide()
        @popup = null

    openFolder: (bookmarkItem) ->
      chrome.bookmarks.getChildren bookmarkItem.bookmarkId, (bookmarks) =>
        @hidePopupIfPresent()
        @popup = new BookmarksPopup(bookmarks, { folderId: bookmarkItem.bookmarkId })
        @popup.render(bookmarkItem.$link)
      @delegate?.BookmarksListDidOpenFolder?(this)

    BookmarkItemDidClick: (bookmarkItem) ->
      @openFolder(bookmarkItem) if bookmarkItem.isFolder()

    BookmarkItemDidMouseOver: (bookmarkItem) ->
      @hidePopupIfPresent() unless bookmarkItem.isFolder()
      @delegate?.BookmarksListDidMouseOverItem?(this, bookmarkItem)

    BookmarkItemWillClick: (bookmarkItem) ->
      @hidePopupIfPresent()

  class BookmarksPopup

    constructor: (@bookmarks, @options = {}, @flowtipOptions = {}) ->
      @parentPopup = @options.parentPopup
      @parentRegion = @options.parentRegion
      @folderId = @options.folderId

    render: (@$target) ->
      @$el = document.createElement("ul")
      @$el.className = "bookmarks-list"

      for bookmark in @bookmarks
        bookmarkItem = new BookmarkItem(bookmark)
        bookmarkItem.delegate = this
        bookmarkItem.render(@$el)

      flowtipOptions = if @parentPopup
        {
          region: @parentRegion || "right"
          topDisabled: true
          leftDisabled: false
          rightDisabled: false
          bottomDisabled: true
          rootAlign: "edge"
          leftRootAlignOffset: 0
          rightRootAlignOffset: -0.1
          targetAlign: "edge"
          leftTargetAlignOffset: 0
          rightTargetAlignOffset: -0.1
        }
      else
        {
          region: "bottom"
          topDisabled: true
          leftDisabled: true
          rightDisabled: true
          bottomDisabled: false
          rootAlign: "edge"
          rootAlignOffset: 0
          targetAlign: "edge"
          targetAlignOffset: 0
        }

      @flowtip = new FlowTip(_.extend({
        className: "bookmarks-popup"
        hasTail: false
        rotationOffset: 0
        edgeOffset: 10
        targetOffset: 2
        maxHeight: "#{@maxHeight()}px"
      }, flowtipOptions, @flowtipOptions))

      @flowtip.setTooltipContent(@$el)
      @flowtip.setTarget(@$target)
      @flowtip.show()

      @flowtip.content.addEventListener "scroll", =>
        @hidePopupIfPresent()
      , false

    hide: ->
      @hidePopupIfPresent()
      @flowtip.hide()
      @flowtip.destroy()

    hidePopupIfPresent: ->
      if @popup
        @popup.hide()
        @popup = null

    openFolder: (bookmarkItem) ->
      chrome.bookmarks.getChildren bookmarkItem.bookmarkId, (bookmarks) =>
        @hidePopupIfPresent()
        @popup = new BookmarksPopup(bookmarks, {
          parentPopup: this
          parentRegion: if @parentPopup
            @flowtip._region
          folderId: bookmarkItem.bookmarkId
        })
        @popup.render(bookmarkItem.$link)

    maxHeight: ->
      if @parentPopup
        document.body.clientHeight - 20 # edgeOffset x 2
      else
        document.body.clientHeight - 41 # bookmarks-bar height + 1px border

    BookmarkItemDidMouseOver: (bookmarkItem) ->
      if bookmarkItem.isFolder()
        if @popup
          @hidePopupIfPresent() if @popup.folderId != bookmarkItem.bookmarkId
        else
          @openFolder(bookmarkItem)
      else
        @hidePopupIfPresent()

      @parentPopup?.BookmarksPopupDidMouseOverItem?(bookmarkItem)

    BookmarkItemDidMouseOut: (bookmarkItem) ->
      if bookmarkItem.isFolder()
        unless @mouseoutTimeout
          @mouseoutTimeout = _.delay =>
            @hidePopupIfPresent()
            @mouseoutTimeout = null
          , 100

    BookmarkItemWillClick: (bookmarkItem) ->
      if @popup && @popup.folderId != bookmarkItem.bookmarkId
        @hidePopupIfPresent()

    BookmarkItemDidClick: (bookmarkItem) ->
      @parentPopup?.BookmarksPopupDidClickItem?(bookmarkItem)

    BookmarksPopupDidMouseOverItem: (bookmarkItem) ->
      if @mouseoutTimeout
        clearTimeout(@mouseoutTimeout)
        @mouseoutTimeout = null

    BookmarksPopupDidClickItem: (bookmarkItem) ->
      if @parentPopup
        @hidePopupIfPresent()
      else
        @hide()

  class BookmarkItem

    constructor: (@bookmark) ->
      @bookmarkId = @bookmark.id

    render: (@$viewport) ->
      @$el = document.createElement("li")
      @$el.className = "bookmark-item"

      unless @bookmark.url
        @$el.className += " folder-item"

      $link = document.createElement("a")
      $label = document.createElement("span")

      $link.className = "clearfix"
      $link.setAttribute("href", @bookmark.url) unless @isFolder()

      $link.addEventListener "mouseover", =>
        if @mouseoutTimeout
          clearTimeout(@mouseoutTimeout)
          @mouseoutTimeout = null
        else
          _.delay =>
            @delegate?.BookmarkItemDidMouseOver?(this)
          , 110
      , false

      $link.addEventListener "mouseout", =>
        unless @mouseoutTimeout
          @mouseoutTimeout = _.delay =>
            @delegate?.BookmarkItemDidMouseOut?(this)
            @mouseoutTimeout = null
          , 100
      , false

      $link.addEventListener "mousedown", =>
        @delegate?.BookmarkItemWillClick?(this)
      , false

      $link.addEventListener "click", =>
        @delegate?.BookmarkItemDidClick?(this)
      , false

      $label.innerHTML = @bookmark.title.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      $label.innerHTML += " &raquo;" if @isFolder()

      $link.appendChild($label)
      @$el.appendChild($link)

      @$link = $link

      @$viewport.appendChild(@$el)

    isFolder: ->
      !@bookmark.url

window.onload = ->
  classicNewTab = new ChromePicturesNewTab $(document.body)
