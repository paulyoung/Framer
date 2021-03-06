{_} = require "./Underscore"

Utils = require "./Utils"

{Config} = require "./Config"
{Defaults} = require "./Defaults"
{BaseClass} = require "./BaseClass"
{EventEmitter} = require "./EventEmitter"
{Animation} = require "./Animation"
{Frame} = require "./Frame"
{LayerStyle} = require "./LayerStyle"
{LayerStates} = require "./LayerStates"
{LayerDraggable} = require "./LayerDraggable"

_RootElement = null
_LayerList = []

layerProperty = (name, cssProperty, fallback, validator, set) ->
	exportable: true
	default: fallback
	get: ->
		@_getPropertyValue name
	set: (value) ->

		# if not validator
		# 	console.log "Missing validator for Layer.#{name}", validator

		if validator(value) is false
			throw Error "value '#{value}' of type #{typeof value} is not valid for a Layer.#{name} property"

		@_setPropertyValue name, value
		@style[cssProperty] = LayerStyle[cssProperty](@)
		@emit "change:#{name}", value
		set @, value if set

layerStyleProperty = (cssProperty) ->
	exportable: true
	# default: fallback
	get: -> @style[cssProperty]
	set: (value) ->
		@style[cssProperty] = value
		@emit "change:#{cssProperty}", value

frameProperty = (name) ->
	exportable: false
	get: -> @frame[name]
	set: (value) ->
		frame = @frame
		frame[name] = value
		@frame = frame

class exports.Layer extends BaseClass

	constructor: (options={}) ->

		_LayerList.push @

		# We have to create the element before we set the defaults
		@_createElement()
		@_setDefaultCSS()

		options = Defaults.getDefaults "Layer", options

		super options

		# Keep track of the default values
		# @_defaultValues = options._defaultValues

		# We need to explicitly set the element id again, becuase it was made by the super
		@_element.id = "FramerLayer-#{@id}"

		# Extract the frame from the options, so we support minX, maxX etc.
		if options.hasOwnProperty "frame"
			frame = new Frame options.frame
		else
			frame = new Frame options

		@frame = frame

		# Insert the layer into the dom or the superLayer element
		if not options.superLayer
			@bringToFront()
			@_insertElement() if not options.shadow
		else
			@superLayer = options.superLayer

		# Set needed private variables
		@_subLayers = []

	##############################################################
	# Properties

	# Css properties
	@define "width",  layerProperty "width",  "width", 100, _.isNumber
	@define "height", layerProperty "height", "height", 100, _.isNumber

	@define "visible", layerProperty "visible", "display", true, _.isBool
	@define "opacity", layerProperty "opacity", "opacity", 1, _.isNumber
	@define "index", layerProperty "index", "zIndex", 0, _.isNumber
	@define "clip", layerProperty "clip", "overflow", true, _.isBool
	
	@define "scrollHorizontal", layerProperty "scrollHorizontal", "overflowX", false, _.isBool, (layer, value) ->
		layer.ignoreEvents = false if value is true
	
	@define "scrollVertical", layerProperty "scrollVertical", "overflowY", false, _.isBool, (layer, value) ->
		layer.ignoreEvents = false if value is true

	@define "scroll",
		get: -> @scrollHorizontal is true or @scrollVertical is true
		set: (value) -> @scrollHorizontal = @scrollVertical = true

	# Behaviour properties
	@define "ignoreEvents", layerProperty "ignoreEvents", "pointerEvents", true, _.isBool

	# Matrix properties
	@define "x", layerProperty "x", "webkitTransform", 0, _.isNumber
	@define "y", layerProperty "y", "webkitTransform", 0, _.isNumber
	@define "z", layerProperty "z", "webkitTransform", 0, _.isNumber

	@define "scaleX", layerProperty "scaleX", "webkitTransform", 1, _.isNumber
	@define "scaleY", layerProperty "scaleY", "webkitTransform", 1, _.isNumber
	@define "scaleZ", layerProperty "scaleZ", "webkitTransform", 1, _.isNumber
	@define "scale", layerProperty "scale", "webkitTransform", 1, _.isNumber

	# @define "scale",
	# 	get: -> (@scaleX + @scaleY + @scaleZ) / 3.0
	# 	set: (value) -> @scaleX = @scaleY = @scaleZ = value

	@define "originX", layerProperty "originX", "webkitTransformOrigin", 0.5, _.isNumber
	@define "originY", layerProperty "originY", "webkitTransformOrigin", 0.5, _.isNumber
	# @define "originZ", layerProperty "originZ", "webkitTransformOrigin", 0.5

	@define "rotationX", layerProperty "rotationX", "webkitTransform", 0, _.isNumber
	@define "rotationY", layerProperty "rotationY", "webkitTransform", 0, _.isNumber
	@define "rotationZ", layerProperty "rotationZ", "webkitTransform", 0, _.isNumber
	@define "rotation",  layerProperty "rotationZ", "webkitTransform", 0, _.isNumber

	# Filter properties
	@define "blur", layerProperty "blur", "webkitFilter", 0, _.isNumber
	@define "brightness", layerProperty "brightness", "webkitFilter", 100, _.isNumber
	@define "saturate", layerProperty "saturate", "webkitFilter", 100, _.isNumber
	@define "hueRotate", layerProperty "hueRotate", "webkitFilter", 0, _.isNumber
	@define "contrast", layerProperty "contrast", "webkitFilter", 100, _.isNumber
	@define "invert", layerProperty "invert", "webkitFilter", 0, _.isNumber
	@define "grayscale", layerProperty "grayscale", "webkitFilter", 0, _.isNumber
	@define "sepia", layerProperty "sepia", "webkitFilter", 0, _.isNumber

	# Mapped style properties

	@define "backgroundColor", layerStyleProperty "backgroundColor"
	@define "borderRadius", layerStyleProperty "borderRadius"
	@define "borderColor", layerStyleProperty "borderColor"
	@define "borderWidth", layerStyleProperty "borderWidth"


	##############################################################
	# Identity

	@define "name",
		exportable: true
		default: ""
		get: -> 
			@_getPropertyValue "name"
		set: (value) ->
			@_setPropertyValue "name", value
			# Set the name attribute of the dom element too
			# See: https://github.com/koenbok/Framer/issues/63
			@_element.setAttribute "name", value

	##############################################################
	# Geometry

	@define "frame",
		get: ->
			new Frame @
		set: (frame) ->
			return if not frame
			for k in ["x", "y", "width", "height"]
				@[k] = frame[k]

	@define "minX", frameProperty "minX"
	@define "midX", frameProperty "midX"
	@define "maxX", frameProperty "maxX"
	@define "minY", frameProperty "minY"
	@define "midY", frameProperty "midY"
	@define "maxY", frameProperty "maxY"

	convertPoint: (point) ->
		# Convert a point on screen to this views coordinate system
		# TODO: needs tests
		Utils.convertPoint point, null, @

	screenFrame: ->
		# Get this views absolute frame on the screen
		# TODO: needs tests
		Utils.convertPoint @frame, @, null

	contentFrame: ->
		Utils.frameMerge @subLayers.map (layer) -> layer.frame.properties

	centerFrame: ->
		# Get the centered frame for its superLayer
		# We always make these pixel perfect
		# TODO: needs tests
		if @superLayer
			frame = @frame
			frame.midX = parseInt @superLayer.width / 2.0
			frame.midY = parseInt @superLayer.height / 2.0
			return frame

		else
			frame = @frame
			frame.midX = parseInt window.innerWidth / 2.0
			frame.midY = parseInt window.innerHeight / 2.0
			return frame

	center: -> @frame = @centerFrame() # Center  in superLayer
	centerX: -> @x = @centerFrame().x # Center x in superLayer
	centerY: -> @y = @centerFrame().y # Center y in superLayer

	pixelAlign: ->
		@x = parseInt @x
		@y = parseInt @y


	##############################################################
	# CSS

	@define "style",
		get: -> @_element.style
		set: (value) ->
			_.extend @_element.style, value
			@emit "change:style"

	@define "html",
		get: ->
			@_elementHTML?.innerHTML

		set: (value) ->

			# Insert some html directly into this layer. We actually create
			# a child node to insert it in, so it won't mess with Framers
			# layer hierarchy.

			if not @_elementHTML
				@_elementHTML = document.createElement "div"
				@_element.appendChild @_elementHTML

			@_elementHTML.innerHTML = value

			# If the contents contains something else than plain text
			# then we turn off ignoreEvents so buttons etc will work.

			if not (
				@_elementHTML.childNodes.length == 1 and
				@_elementHTML.childNodes[0].nodeName == "#text")
				@ignoreEvents = false

			@emit "change:html"

	computedStyle: ->
		document.defaultView.getComputedStyle @_element

	_setDefaultCSS: ->
		@style = Config.layerBaseCSS

	@define "classList",
		get: -> @_element.classList


	##############################################################
	# DOM ELEMENTS

	_createElement: ->
		return if @_element?
		@_element = document.createElement "div"

	_insertElement: ->
		Utils.domComplete @__insertElement

	__insertElement: =>
		if not _RootElement
			_RootElement = document.createElement "div"
			_RootElement.id = "FramerRoot"
			_.extend _RootElement.style, Config.rootBaseCSS
			document.body.appendChild _RootElement

		_RootElement.appendChild @_element

	destroy: ->

		if @superLayer
			@superLayer._subLayers = _.without @superLayer._subLayers, @

		@_element.parentNode.removeChild @_element
		@removeAllListeners()

		_LayerList = _.without _LayerList, @


	##############################################################
	## COPYING

	copy: ->

		# Todo: what about events, states, etc.

		layer = @copySingle()

		for subLayer in @subLayers
			copiedSublayer = subLayer.copy()
			copiedSublayer.superLayer = layer

		layer

	copySingle: -> new Layer @properties

	##############################################################
	## ANIMATION

	animate: (options) ->

		options.layer = @
		options.curveOptions = options

		animation = new Animation options
		animation.start()

		animation

	##############################################################
	## IMAGE

	@define "image",
		exportable: true
		default: ""
		get: ->
			@_getPropertyValue "image"
		set: (value) ->

			currentValue = @_getPropertyValue "image"

			if currentValue == value
				return @emit "load"

			# Todo: this is not very nice but I wanted to have it fixed
			# defaults = Defaults.getDefaults "Layer", {}

			# console.log defaults.backgroundColor
			# console.log @_defaultValues?.backgroundColor

			# if defaults.backgroundColor == @_defaultValues?.backgroundColor
			# 	@backgroundColor = null

			@backgroundColor = null

			# Set the property value
			@_setPropertyValue "image", value

			imageUrl = value

			# Optional base image value
			# imageUrl = Config.baseUrl + imageUrl

			# If the file is local, we want to avoid caching
			# if Utils.isLocal()
			# 	imageUrl += "?nocache=#{Date.now()}"

			# As an optimization, we will only use a loader
			# if something is explicitly listening to the load event

			if @events?.hasOwnProperty "load" or @events?.hasOwnProperty "error"

				loader = new Image()
				loader.name = imageUrl
				loader.src = imageUrl

				loader.onload = =>
					@style["background-image"] = "url('#{imageUrl}')"
					@emit "load", loader

				loader.onerror = =>
					@emit "error", loader

			else
				@style["background-image"] = "url('#{imageUrl}')"

	##############################################################
	## HIERARCHY

	@define "superLayer",
		exportable: false
		get: ->
			@_superLayer or null
		set: (layer) ->

			return if layer is @_superLayer

			# Check the type
			if not layer instanceof Layer
				throw Error "Layer.superLayer needs to be a Layer object"

			# Cancel previous pending insertions
			Utils.domCompleteCancel @__insertElement

			# Remove from previous superlayer sublayers
			if @_superLayer
				@_superLayer._subLayers = _.without @_superLayer._subLayers, @
				@_superLayer._element.removeChild @_element
				@_superLayer.emit "change:subLayers", {added:[], removed:[@]}

			# Either insert the element to the new superlayer element or into dom
			if layer
				layer._element.appendChild @_element
				layer._subLayers.push @
				layer.emit "change:subLayers", {added:[@], removed:[]}
			else
				@_insertElement()

			# Set the superlayer
			@_superLayer = layer

			# Place this layer on top of it's siblings
			@bringToFront()

			@emit "change:superLayer"

	superLayers: ->

		superLayers = []

		recurse = (layer) ->
			return if not layer.superLayer
			superLayers.push layer.superLayer
			recurse layer.superLayer

		recurse @

		superLayers

	# Todo: should we have a recursive subLayers function?
	# Let's make it when we need it.

	@define "subLayers",
		exportable: false
		get: -> _.clone @_subLayers

	@define "siblingLayers",
		exportable: false
		get: ->

			# If there is no superLayer we need to walk through the root
			if @superLayer is null
				return _.filter _LayerList, (layer) =>
					layer isnt @ and layer.superLayer is null

			return _.without @superLayer.subLayers, @

	addSubLayer: (layer) ->
		layer.superLayer = @

	removeSubLayer: (layer) ->

		if layer not in @subLayers
			return

		layer.superLayer = null

	subLayersByName: (name) ->
		_.filter @subLayers, (layer) -> layer.name == name

	##############################################################
	## ANIMATION

	animate: (options) ->

		start = options.start
		start ?= true
		delete options.start

		options.layer = @
		animation = new Animation options
		animation.start() if start
		animation

	animations: ->
		# Current running animations on this layer
		_.filter Animation.runningAnimations(), (a) =>
			a.options.layer == @

	animateStop: ->
		_.invoke @animations(), "stop"

	##############################################################
	## INDEX ORDERING

	bringToFront: ->
		@index = _.max(_.union([0], @siblingLayers.map (layer) -> layer.index)) + 1

	sendToBack: ->
		@index = _.min(_.union([0], @siblingLayers.map (layer) -> layer.index)) - 1

	placeBefore: (layer) ->
		return if layer not in @siblingLayers

		for l in @siblingLayers
			if l.index <= layer.index
				l.index -= 1

		@index = layer.index + 1

	placeBehind: (layer) ->
		return if layer not in @siblingLayers

		for l in @siblingLayers
			if l.index >= layer.index
				l.index += 1

		@index = layer.index - 1

	##############################################################
	## STATES

	@define "states",
		get: -> @_states ?= new LayerStates @

	#############################################################################
	## Draggable

	@define "draggable",
		get: ->
			@_draggable ?= new LayerDraggable @
			@_draggable

	##############################################################
	## SCROLLING

	# TODO: Tests

	@define "scrollFrame",
		get: ->
			return new Frame
				x: @scrollX
				y: @scrollY
				width: @width
				height: @height
		set: (frame) ->
			@scrollX = frame.x
			@scrollY = frame.y

	@define "scrollX",
		get: -> @_element.scrollLeft
		set: (value) -> @_element.scrollLeft = value

	@define "scrollY",
		get: -> @_element.scrollTop
		set: (value) -> @_element.scrollTop = value

	##############################################################
	## EVENTS

	addListener: (event, originalListener) =>

		# # Modify the scope to be the calling object, just like jquery
		# # also add the object as the last argument
		listener = (args...) =>
			originalListener.call @, args..., @

		# Because we modify the listener we need to keep track of it
		# so we can find it back when we want to unlisten again
		originalListener.modifiedListener = listener

		# Listen to dom events on the element
		super event, listener
		@_element.addEventListener event, listener

		@_eventListeners ?= {}
		@_eventListeners[event] ?= []
		@_eventListeners[event].push listener

		# We want to make sure we listen to these events
		@ignoreEvents = false

	removeListener: (event, listener) ->

		# If the original listener was modified, remove that
		# one instead
		if listener.modifiedListener
			listener = listener.modifiedListener

		super event, listener
		
		@_element.removeEventListener event, listener
		@_eventListeners[event] = _.without @_eventListeners[event], listener

	removeAllListeners: ->

		return if not @_eventListeners

		for eventName, listeners of @_eventListeners
			for listener in listeners
				@removeListener eventName, listener

	on: @::addListener
	off: @::removeListener

exports.Layer.Layers = -> _.clone _LayerList
