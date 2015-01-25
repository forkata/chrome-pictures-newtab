namespace "ChromePicturesNewTab", (exports) ->
  class exports.BackgroundService
    fetchSize: 500
    poolThreshold: 50
    filterByLicenses: true
    filteredLicenses: [1, 2, 4, 5, 7]
    attrRegexp: new RegExp("^[^-]+-photo-(.+)")

    viewportWidth: 0
    viewportHeight: 0

    constructor: ->
      console.log "ChromePicturesNewTabService#constructor"

    setViewportSize: (width, height) ->
      @viewportWidth = width
      @viewportHeight = height
      RSVP.resolve()

    togglePinned: ->
      @cachedPhoto("current").then (photo) =>
        photo.isPinned = !photo.isPinned
        new RSVP.Promise (resolve, reject) =>
          try
            chrome.storage.local.set {
              "current-photo-isPinned": photo.isPinned
            }, =>
              resolve(photo)
          catch err
            reject(err)

    replaceCurrentPhoto: ->
      @ensureCachedPhoto("next").then (photo) =>
        photo.timestamp = null
        @savePhoto(photo, "current")

    replaceNextPhoto: ->
      @deleteCachedPhoto("next").then =>
        @ensureCachedPhoto("next")

    ensureCachedPhoto: (prefix) ->
      @cachedPhoto(prefix).catch =>
        @fetchPhoto().then (photo) =>
          @savePhoto(photo, prefix)

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
        @fetchPhotos().then (photos) =>
          index = parseInt(Math.random() * photos.length * 10, 10) % photos.length
          photo = photos[index]
          title = photo.getAttribute("title")
          webUrl = @photoWebUrl(photo.getAttribute("owner"), photo.getAttribute("id"))
          ownerName = photo.getAttribute("ownername")
          ownerWebUrl = @ownerWebUrl(photo.getAttribute("owner"))

          console.log "Use photo at index #{index} of #{photos.length} photos"
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

    fetchPhotos: (_date = null, _photos = []) ->
      if @_cachedPhotos
        RSVP.resolve(@_cachedPhotos)
      else
        _date = new Date() unless _date
        console.log "Fetching from #{@formatDate(_date)}"
        @flickrApiRequest("flickr.interestingness.getList", {
          per_page: @fetchSize
          page: 1
          date: @formatDate(_date)
          extras: "license,owner_name"
        }).then (resp) =>
          _photos = _photos.concat if @filterByLicenses
            query = _.map @filteredLicenses, (license) ->
              "photo[license=#{license}]"
            $(resp).find(query.join(",")).toArray()
          else
            $(resp).find("photo").toArray()

          return if _photos.length < @poolThreshold
            @fetchPhotos(new Date(_date.getTime() - 86400000), _photos)
          else
            @_cachedPhotos = _photos
            @_cachedPhotos

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

    formatDate: (date) ->
      string = "#{date.getFullYear()}"
      month = date.getMonth() + 1
      dom = date.getDate()

      string = if month < 10
        "#{string}-0#{month}"
      else
        "#{string}-#{month}"

      string = if dom < 10
        "#{string}-0#{dom}"
      else
        "#{string}-#{dom}"

      string

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
      (0.21 * rgb.r) + (0.72 * rgb.g) + (0.07 * rgb.b)

service = new ChromePicturesNewTab.BackgroundService()

chrome.runtime.onMessage.addListener (msg, sender, sendResponse) ->
  if service[msg.method]
    ret = service[msg.method](msg.args...)
    if ret.then
      ret.then ->
        sendResponse { resolve: arguments }
      .catch ->
        sendResponse { reject: arguments }
      return true
    else
      sendResponse { resolve: ret }
