restify = require 'restify'
swagger = require 'swagger-doc'
toobusy = require 'toobusy'
r = require 'rethinkdb'
r.connect { host: 'localhost', port: 28015 }, (conn) ->
  r.db('drone').tableCreate('location').run()

###
  Server Options
###
server = restify.createServer()
server.pre restify.pre.userAgentConnection()
server.use _check_if_busy
server.use restify.acceptParser server.acceptable # respond correctly to accept headers
server.use restify.fullResponse() # set CORS, eTag, other common headers

newLocation = (req, res, next) ->
  uuid = req.params.uuid
  long = parseFloat req.params.long
  lat = parseFloat req.params.lat
  distance = parseFloat req.params.distance
  currentTime = new Date req.params.currentTime
  appname = req.params.appname

  location = { uuid, long, lat, distance, currentTime, appname }
  r.db('drone').table('locations').insert(location).run()

getLocation = (req, res, next) ->
  uuid = req.params.uuid
  res.send r.db('drone').table('locations').filter({'uuid': uuid}).run()

###
  API
###
swagger.configure server
server.put  "/location", newLocation
server.get  "/location", getLocation

docs = swagger.createResource '/location'
docs.put "/location", "Upload a new drone location",
  nickname: "newDroneLocation"
docs.get "/location", "Gets list of locations for a uuid",
  nickname: "getLocation"
  parameters: [
    { name: 'uuid', description: 'uuid', required: true, dataType: 'int', paramType: 'query' }
  ]
  errorResponses: [
    { code: 404, reason: "uuid not found" }
  ]

server.get  "/ids", getIds
docs = swagger.createResource '/uuid'
docs.get "/ids", "Gets list of uuids in",
  nickname: "getIds"
###
  Documentation
###
server.get /\/*/, restify.serveStatic directory: './static', default: 'index.html'


server.listen process.env.PORT or 8081, ->
  console.log "[%s] #{server.name} listening at #{server.url}", process.pid