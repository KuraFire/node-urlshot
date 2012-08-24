http    = require 'http'
url     = require 'url'
child   = require 'child_process'
fs      = require 'fs'

index = fs.readFileSync 'public/index.html'

server = http.createServer()
server.listen process.env.PORT or 8888

cacheSeconds = process.env.CACHE_SECONDS or 24 * 60 * 60

expirationDate = ->
  date = new Date()
  date.setTime date.getTime() + cacheSeconds * 1000
  date.toUTCString()

server.on 'request', (request, response) ->
  params = url.parse(request.url, true).query

  if imageurl = params.url
    viewport   = params.viewport or '1024x768'
    scrollto   = params.scrollto or 0
    fullpage   = params.fullpage in ['1', 'true']
    format     = if params.format in ['png', 'jpg'] then params.format else 'png'
    mimeHeader = 'Content-Type': "image/#{format}"
    url2image  = child.spawn 'phantomjs', ['lib/url2image.js', imageurl, viewport, scrollto, fullpage, format]
    imageData  = ''

    url2image.stdout.on 'data', (data) ->
      imageData += data

    url2image.on 'exit', (code) ->
      if code is 0
        responseData = new Buffer imageData.toString().replace(/\n/, ''), 'base64'
        response.setHeader 'Content-Length', responseData.length
        response.setHeader 'Cache-Control', "public, max-age=#{cacheSeconds}"
        response.setHeader 'Expires', expirationDate()
        response.writeHead 201, mimeHeader
        response.end responseData
      else
        response.writeHead 500, mimeHeader
        response.end()

  else if request.url is '/' and /html/.test request.headers.accept
    response.writeHead 200, 'Content-Type': 'text/html'
    response.end index

  else
    response.statusCode = 404
    response.end()