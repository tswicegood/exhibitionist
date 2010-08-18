express = require "express"
fs = require "fs"
mustache = require "mustache"
path = require "path"
sys = require "sys"

# TODO: make this configurable so you can store the log elsewhere
log = sys

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
  c.path ||= exhibit_dir
  c

errorAndExit = (log, msg, code) ->
  log.error msg
  process.exit(code || -1)

noPresentationFound = (log) -> errorAndExit log, "Found a package.json, but there is no presentation section?"
noTitleSpecified = (log) -> errorAndExit log, "You must specify a title in your presentation"
noSlideSections = (log) -> errorAndExit log, "You must provide at least one entry in the sections array"
slidesNotCorrectType = (log) -> errorAndExit log, "`sections` must be an array"
zeroSlides = (log) -> errorAndExit log, "You have an empty `sections` array.  How am I to exhibit anything?"

checkConfig = (config, log) ->
  noPresentationFound(log) unless "presentation" of config
  noTitleSpecified(log) unless "title" of config.presentation
  noSlideSections(log) unless "sections" of config.presentation
  slidesNotCorrectType(log) unless sectionsConfigValueIsCorrect(config)
  zeroSlides(log) unless config.presentation.sections.length > 0

sectionsConfigValueIsCorrect = (config) ->
  t = typeof(config.presentation.sections)
  t == "object" or t == "array"



exports.Presentation = class Presentation
  constructor: (@path, @config) ->
    @sections = []

  loadSlides: ->
    for section of @config.presentation.sections
      @sections[@sections.length] = new Section(@config.presentation.sections[section], @config)

  run: ->
    app = express.createServer()
    app.get '/', (req, res) =>
      res.send mustache.to_html @sections[0].slides[0].slideContents(), @config.presentation
    app.listen(1981)

ignoreSwapFiles = (iter) ->
  # TODO: when the language supports it, this should be a list comprehension with an unless
  array = []
  for a in iter
    array[array.length] = a unless !a or (a and a[0] == '.')
  array

exports.Section = class Section
  constructor: (@name, @config) ->
    rawSlides = ignoreSwapFiles(fs.readdirSync(path.join(@config.path, @name)))
    @warnNoSlides() if rawSlides.length == 0
    @slides = new Slide(s, this, @config) for s in rawSlides

  warnNoSlides: ->
    # TODO: this should be a Warn
    log.puts "The #{@name} section is empty?"

exports.Slide = class Slide
  constructor: (@slide_file, @parent, @config) ->
    @contents = fs.readFileSync(path.join(@config.path, @parent.name, @slide_file), 'utf-8')

  slideContents: ->
    # TODO: show just the section.slide content
    @contents

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

