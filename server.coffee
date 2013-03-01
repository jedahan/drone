restify = require 'restify'
swagger = require 'swagger-doc'
toobusy = require 'toobusy'
fs = require 'fs'
async = require 'async'
Mongolian = require 'mongolian'
mongolian = new Mongolian
ObjectId = Mongolian.ObjectId
ObjectId.prototype.toJSON = ObjectId.prototype.toString
db = mongolian.db 'drone'
locations = db.collection 'locations'
videos = db.collection 'videos'

_check_if_busy = (req, res, next) ->
  if toobusy()
    res.send 503, "I'm busy right now, sorry."
  else next()

server = restify.createServer()
server.pre restify.pre.userAgentConnection()
server.use _check_if_busy
server.use restify.acceptParser server.acceptable # respond correctly to accept headers
server.use restify.bodyParser()
server.use restify.fullResponse() # set CORS, eTag, other common headers

newLocation = (req, res, next) ->
  uuid = req.params.uuid
  lng = parseFloat req.params.lng
  lat = parseFloat req.params.lat
  distance = parseFloat req.params.distance
  currentTime = new Date req.params.currentTime
  appname = req.params.appname
  console.log location = { uuid, lng, lat, distance, currentTime, appname, _rev: currentTime }
  
  drone.insert location, uuid, (err, body) ->
    if err and err.message is 'no_db_file'
      nano.db.create 'drone'
      res.send 'db initialised'
    else
      res.send body
  
getLocation = (req, res, next) ->
  id = JSON.parse(req.body).uuid
  drone.get id, revs_info: true, (err, body) -> res.send body

getIds = (req, res, next) ->
  res.send r.table('locations')('uuid').runp()

###
  API
###
#swagger.configure server
server.put  "/location", newLocation
server.get  "/location", getLocation
###
docs = swagger.createResource '/location'
docs.put "/location", "Upload a new drone location",
  nickname: "newLocation"
docs.get "/location", "Gets list of locations for a uuid",
  nickname: "getLocation"
  parameters: [
    { name: 'uuid', description: 'uuid', required: true, dataType: 'int', paramType: 'query' }
  ]
  errorResponses: [
    { code: 404, reason: "uuid not found" }
  ]
###
server.get  "/ids", getIds
###
docs = swagger.createResource '/uuid'
docs.get "/ids", "Gets list of uuids in",
  nickname: "getIds"
###
###
  Documentation
###
server.get /\/*/, restify.serveStatic directory: './static', default: 'index.html'


server.listen process.env.PORT or 8081, ->
  console.log "[%s] #{server.name} listening at #{server.url}", process.pid