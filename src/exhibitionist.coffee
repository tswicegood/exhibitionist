fs = require "fs"
path = require "path"
sys = require "sys"

FILE_NOT_FOUND = "ENOENT, No such file or directory"

getConfig = (exhibit_dir, log) ->
  try
    c = JSON.parse fs.readFileSync path.join(exhibit_dir, "package.json"), "utf-8"
  catch e
    throw e unless e.message[0...FILE_NOT_FOUND.length] == FILE_NOT_FOUND
    log.error "Couldn't find the package.json file?"
    log.error "Make sure you're in the correct directory"
    process.exit(-1)

  checkConfig c, log
  c

errorAndExit = (log, msg, code) ->
  log.error msg
  process.exit(code || -1)

noPresentationFound = (log) -> errorAndExit log, "Found a package.json, but there is no presentation section?"
noTitleSpecified = (log) -> errorAndExit log, "You must specify a title in your presentation"
noSlideSections = (log) -> errorAndExit log, "You must provide at least one entry in the sections array"
slidesNotCorrectType = (log) -> errorAndExit log, "`sections` must be an array"

checkConfig = (config, log) ->
  noPresentationFound(log) unless "presentation" of config
  noTitleSpecified(log) unless "title" of config.presentation
  noSlideSections(log) unless "sections" of config.presentation
  slidesNotCorrectType(log) unless sectionsConfigValueIsCorrect(config)

sectionsConfigValueIsCorrect = (config) ->
  t = typeof(config.presentation.sections)
  t == "object" or t == "array"

exports.Presentation = class Presentation
  constructor: (@path, @config) ->

  loadSlides: ->
    @config.presentation.sections
  run: ->

exports.Exhibitionist = class Exhibitionist
  constructor: (@exhibit_dir) ->
    @config = getConfig(@exhibit_dir, sys)
    @displayWelcome()
    @presentation = new Presentation(@exhibit_dir, @config)
    @presentation.loadSlides()

  run: ->
    @presentation.run()

  getTitle: ->
    t = @config.presentation.title
    t += ": " + @config.presentation.subtitle if "subtitle" of @config.presentation
    t

  displayWelcome: ->
    sys.puts "Starting up Exhibitionist for #{@getTitle()}"

