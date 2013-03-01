restify = require 'restify'
swagger = require 'swagger-doc'
toobusy = require 'toobusy'
fs = require 'fs'
async = require 'async'

# MongoDB setup
Mongolian = require 'mongolian'
mongolian = new Mongolian
ObjectId = Mongolian.ObjectId
ObjectId.prototype.toJSON = ObjectId.prototype.toString
db = mongolian.db 'drone'

# Collections
locations = db.collection 'locations'
videos = db.collection 'videos'
gcm = db.collection 'gcm'

_check_if_busy = (req, res, next) ->
  if toobusy()
    res.send 503, "I'm busy right now, sorry."
  else next()

_exists = (item, cb) -> cb item?

server = restify.createServer()
server.pre restify.pre.userAgentConnection()
server.use _check_if_busy
server.use restify.acceptParser server.acceptable # respond correctly to accept headers
server.use restify.bodyParser uploadDir: 'static/uploads'
server.use restify.fullResponse() # set CORS, eTag, other common headers


# when the app starts, register its gcm if its not in the db
newGcm = (req, res, next) ->
  uuid = req.params.uuid
  appname = req.params.appname
  stop = req.params.stop
  heartbeat = new Date().getTime()

  gcm.findOne {uuid, appname}, (err, body) ->
    console.error err if err
    if body?
      res.send body
    else
      res.send gcm.insert { uuid, appname, stop, heartbeat }

# get a list of uuids by appname
getGcm = (req, res, next) ->
  appname = JSON.parse(req.body).appname
  gcm.find(appname).toArray (err, body) ->
    console.error err if err
    res.send body

getAppnames = (req, res, next) ->
  gcm.distinct 'appname', (err, body) ->
    res.send body

newLocation = (req, res, next) ->
  uuid = req.params.uuid
  lng = parseFloat req.params.lng
  lat = parseFloat req.params.lat
  distance = parseFloat req.params.distance
  currentTime = new Date req.params.currentTime
  appname = req.params.appname
  
  res.send locations.insert { uuid, lng, lat, distance, currentTime, appname }

getLocations = (req, res, next) ->
  uuid = JSON.parse(req.body).uuid
  locations.find(uuid).toArray (err, body) ->
    console.error err if err
    res.send body

getLocation = (req, res, next) ->
  uuid = JSON.parse(req.body).uuid
  locations.findOne {uuid}, (err, body) ->
    console.error err if err
    res.send body

getUsers = (req, res, next) ->
  locations.distinct "uuid", (err, body) ->
    res.send body

newVideo = (req, res, next) ->
  currentTime = new Date req.params.currentTime
  uuid = req.params.uuid
  data = server.url + '/' + req.files.data.path
  direction = req.params.direction or null
  videos.insert {uuid, currentTime, data, direction}
  res.send data

getVideo = (req, res, next) ->
  uuid = JSON.parse(req.body).uuid
  direction = JSON.parse(req.body).direction or null
  async.filter {uuid, direction}, _exists, (filter) ->
    videos.findOne filter, (err, body) ->
      res.send body

getVideos = (req, res, next) ->
  uuid = JSON.parse(req.body).uuid
  direction = JSON.parse(req.body).direction or null
  async.filter {uuid, direction}, _exists, (filter) ->
    videos.find(filter).toArray (err, body) ->
      console.error err if err
      res.send body

###
  API
###
swagger.configure server
server.put  "/location", newLocation
server.get  "/location", getLocation
server.get  "/locations", getLocations

server.get  "/users", getUsers

server.put "/video", newVideo
server.get "/video", getVideo
server.get "/videos", getVideos

server.put "/live", newGcm
server.get "/live", getGcm

server.get "/appnames", getAppnames
###
  Documentation
###
docs = swagger.createResource '/killer_locations'
docs.put "/location", "Upload a new drone location",
  nickname: "newLocation"
  parameters: [
    { name: 'appname', description: 'package appname', required: true, dataType: 'string', paramType: 'query' }
    { name: 'uuid', description: 'uuid', required: true, dataType: 'string', paramType: 'query' }
    { name: 'lat', description: 'latitude', required: true, dataType: 'long', paramType: 'query' }
    { name: 'lng', description: 'longitude', required: true, dataType: 'long', paramType: 'query' }
    { name: 'distance', description: 'distance from 319 scholes in m', required: true, dataType: 'int', paramType: 'query' }
    { name: 'currentTime', description: 'datetime', required: true, dataType: 'Date', paramType: 'query' }
  ]

docs.get "/location", "Gets the last known location for a uuid",
  nickname: "getLocation"
  parameters: [
    { name: 'uuid', description: 'uuid', required: true, dataType: 'string', paramType: 'query' }
  ]

docs.get "/locations", "Gets all the known locations for a uuid",
  nickname: "getLocations"
  parameters: [
    { name: 'uuid', description: 'uuid', required: true, dataType: 'string', paramType: 'query' }
  ]

docs = swagger.createResource '/killer_gcm'
docs.put "/gcm", "Register a gcm connection",
  nickname: "newGcm"
  parameters: [
    { name: 'appname', description: 'package appname', required: true, dataType: 'string', paramType: 'query' }
    { name: 'uuid', description: 'uuid', required: true, dataType: 'string', paramType: 'query' }
  ]

docs.get "/gcm", "Gets all the uuids for a particular appname",
  nickname: "getGcm"
  parameters: [
    { name: 'appname', description: 'package appname', required: true, dataType: 'string', paramType: 'query' }
  ]

docs.get "/apps", "Gets all the registered packagenames/appnames",
  nickname: "getApps"

docs = swagger.createResource '/killer_users'
docs.get "/users", "Gets list of unique users",
  nickname: "getUsers"

server.get /\/*/, restify.serveStatic directory: './static', default: 'index.html'

server.listen process.env.PORT or 8081, ->
  console.log "[%s] #{server.name} listening at #{server.url}", process.pid