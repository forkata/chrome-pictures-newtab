class ChromePicturesNewTab
  fetchSize: 500
  attrRegexp: new RegExp("^[^-]+-photo-(.+)")

  constructor: ($viewport) ->
    @$viewport = $viewport

    @$photo = $("#photo")
    @$photoFooter = $("#photo-footer")
    @$photoTitleLink = $("#photo-title-link")
    @$photoTitleOwnerLink = $("#photo-title-owner-link")
    @$photoRefreshLink = $("#photo-refresh-link")
    @$photoPinLink = $("#photo-pin-link")
    @$photoPinLinkText = $("#photo-pin-link span")

    @viewportWidth = @$viewport.width()
    @viewportHeight = @$viewport.height()

    window.addEventListener "resize", =>
      @viewportWidth = @$viewport.width()
      @viewportHeight = @$viewport.height()
    , false

    @ensureCachedPhoto("current").then (photo) =>
      nowTime = (new Date()).getTime()
      photoTime = parseInt(photo.timestamp) || Infinity
      diffTime = nowTime - photoTime
      timedOut = diffTime > 900000

      if timedOut && !photo.isPinned
        @advancePhoto()
      else
        @displayPhoto(photo)
        @ensureCachedPhoto("next")

    @bookmarksBar = new BookmarksBar()
    @bookmarksBar.render(@$viewport[0])

    @$photoRefreshLink.on "click", =>
      @withLoadingAnimation @$photoRefreshLink, =>
        @refreshPhoto()

    @$photoPinLink.on "click", =>
      @togglePinned()

    document.body.addEventListener "click", (event) =>
      unless $(event.target).closest(".bookmarks-popup").length
        @bookmarksBar.hidePopupIfPresent()
    , false

    window.addEventListener "resize", =>
      @bookmarksBar.hidePopupIfPresent()
    , false

  withLoadingAnimation: ($target, func) ->
    if !$target.hasClass("loading")
      $target.addClass("loading")
      func().then =>
        $target.removeClass("loading")

  togglePinned: ->
    @cachedPhoto("current").then (photo) =>
      photo.isPinned = !photo.isPinned
      chrome.storage.local.set {
        "current-photo-isPinned": photo.isPinned
      }, =>
        @updatePinnedDisplay(photo)

  updatePinnedDisplay: (photo) ->
    @$photoPinLinkText.text if photo.isPinned
      "Unpin"
    else
      "Pin"

  displayPhoto: (photo) ->
    console.log "Displaying photo", photo

    chrome.storage.local.get ["current-photo-timestamp"], (data) ->
      console.log "Checking photo timestamp", data
      if !data["current-photo-timestamp"]
        photoTime = (new Date()).getTime()
        console.log "Setting photo timestamp to #{photoTime}"
        data["current-photo-timestamp"] = photoTime
        chrome.storage.local.set data

    @$photo.css "background-image", "url('#{photo.url}')"
    # @$photo.css "background-image", "url(#{photo.dataUri})"

    @$photoTitleLink.text(photo.title)
    @$photoTitleLink.attr("href", photo.webUrl)
    @$photoTitleOwnerLink.html("&copy; #{photo.ownerName}")
    @$photoTitleOwnerLink.attr("href", photo.ownerWebUrl)

    if (photo.bottomGrayscale / 255.0) * 100 < 50
      @$photoFooter.attr("data-color", "dark")
    else
      @$photoFooter.attr("data-color", "light")

    if (photo.topGrayscale / 255.0) * 100 < 50
      $(@bookmarksBar.el).attr("data-color", "dark")
    else
      $(@bookmarksBar.el).attr("data-color", "light")

    @updatePinnedDisplay(photo)
    null

  advancePhoto: ->
    @ensureCachedPhoto("next").then (photo) =>
      photo.timestamp = null
      @savePhoto(photo, "current").then =>
        @displayPhoto(photo)
        @deleteCachedPhoto("next").then =>
          @ensureCachedPhoto("next")

  refreshPhoto: ->
    @fetchPhoto().then (photo) =>
      @savePhoto(photo, "next").then =>
        @advancePhoto()

  ensureCachedPhoto: (prefix) ->
    @cachedPhoto(prefix).then null, =>
      @fetchPhoto().then (photo) =>
        @savePhoto(photo, prefix)
        photo

  cachedPhoto: (prefix) ->
    new RSVP.Promise (resolve, reject) =>
      try
        chrome.storage.local.get [
          "#{prefix}-photo-dataUri"
          "#{prefix}-photo-topGrayscale"
          "#{prefix}-photo-bottomGrayscale"
          "#{prefix}-photo-url"
          "#{prefix}-photo-contentType"
          "#{prefix}-photo-title"
          "#{prefix}-photo-webUrl"
          "#{prefix}-photo-ownerName"
          "#{prefix}-photo-ownerWebUrl"
          "#{prefix}-photo-timestamp"
          "#{prefix}-photo-isPinned"
        ], (data) =>
          photo = @decodePhoto(data)
          if photo.dataUri?.length > 0
            console.log "Photo cache hit: #{prefix}"
            resolve(photo)
          else
            console.warn "Photo cache miss: #{prefix}"
            reject()
      catch err
        console.error "Photo cache error: #{prefix}", err
        reject(err)

  savePhoto: (photo, prefix) ->
    new RSVP.Promise (resolve, reject) =>
      try
        data = @encodePhoto(photo, prefix)
        chrome.storage.local.set data, ->
          console.log "Photo saved with prefix: #{prefix}"
          resolve()
      catch err
        console.error "Error saving photo", err
        reject(err)

  deleteCachedPhoto: (prefix) ->
    new RSVP.Promise (resolve, reject) =>
      try
        chrome.storage.local.remove [
          "#{prefix}-photo-dataUri"
          "#{prefix}-photo-topGrayscale"
          "#{prefix}-photo-bottomGrayscale"
          "#{prefix}-photo-url"
          "#{prefix}-photo-contentType"
          "#{prefix}-photo-title"
          "#{prefix}-photo-webUrl"
          "#{prefix}-photo-ownerName"
          "#{prefix}-photo-ownerWebUrl"
          "#{prefix}-photo-timestamp"
          "#{prefix}-photo-isPinned"
        ], ->
          console.log "Photo deleted with prefix: #{prefix}"
          resolve()
      catch err
        console.error "Error deleting photo", err
        reject(err)

  decodePhoto: (data) ->
    photo = {}
    _.each _.keys(data), (key) =>
      attrName = key.match(@attrRegexp)[1]
      photo[attrName] = data[key]
    photo

  encodePhoto: (photo, prefix) ->
    data = {}
    _.each _.keys(photo), (attr) =>
      data["#{prefix}-photo-#{attr}"] = photo[attr]
    data

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

          @urlToImageData(url, contentType).then (imageData) =>
            resolve({
              dataUri: imageData.dataUri
              topGrayscale: imageData.topGrayscale
              bottomGrayscale: imageData.bottomGrayscale
              url: url
              contentType: contentType
              title: title
              webUrl: webUrl
              ownerName: ownerName
              ownerWebUrl: ownerWebUrl
              timestamp: null
              isPinned: false
            })
      .catch ->
        console.error "Error fetching photo", arguments
        reject.apply(null, arguments)

  fetchPhotos: ->
    @flickrApiRequest("flickr.interestingness.getList", {
      per_page: @fetchSize
      page: 1
      extras: "license,owner_name"
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

  urlToImageData: (url, contentType) ->
    new RSVP.Promise (resolve) =>
      canvas = document.createElement('CANVAS')
      ctx = canvas.getContext('2d')
      img = new Image()
      img.crossOrigin = 'Anonymous'
      img.onload = =>
        canvas.height = img.height
        canvas.width = img.width

        ctx.drawImage(img, 0, 0)
        topData = ctx.getImageData(0, 0, img.width, 20)
        bottomData = ctx.getImageData(0, img.height - 16, img.width, 16)

        resolve({
          dataUri: canvas.toDataURL(contentType)
          topGrayscale: @rgbToGrayscale(@averageRgb(topData))
          bottomGrayscale: @rgbToGrayscale(@averageRgb(bottomData))
        })

        $(canvas).remove()
      img.src = url

  averageRgb: (data) ->
    count = 0
    index = 0
    rgb = { r: 0, g: 0, b: 0 }

    while (true)
      break if index >= data.data.length
      rgb.r += data.data[index]
      rgb.g += data.data[index + 1]
      rgb.b += data.data[index + 2]
      index += 5 * 4 # sample every 5 pixels
      count += 1

    rgb.r = Math.floor(rgb.r / count)
    rgb.g = Math.floor(rgb.g / count)
    rgb.b = Math.floor(rgb.b / count)

    rgb

  rgbToGrayscale: (rgb) ->
    console.log rgb
    (0.21 * rgb.r) + (0.72 * rgb.g) + (0.07 * rgb.b)

window.onload = ->
  classicNewTab = new ChromePicturesNewTab $(document.body)
