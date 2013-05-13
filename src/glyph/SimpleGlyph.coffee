# # ttf.js - JavaScript TrueType Font library
#
# Copyright (C) 2013 by ynakajima (https://github.com/ynakajima)
#
# Released under the MIT license.

# ## Simple Glyph Class
class SimpleGlyph
  constructor: (GID = null, glyfTable = null) ->
    @GID = GID
    @type = 'simple'
    @numberOfContours = 0
    @xMin = 0
    @yMin = 0
    @xMax = 0
    @yMax = 0
    @endPtsOfContours = []
    @instructionLength = 0
    @instructions = []
    @flags = []
    @xCoordinates = []
    @yCoordinates = []
    @glyfTable = glyfTable

    # _outline = [
    #   [ # first countour
    #     {x:  0, y: 10, relX: 0, relY: 10, on: true}, # coordinate
    #     {x: 40, y: 10, relX: 40, relY: 0, on: true },
    #     ...
    #   ],
    #   [ # second countour
    #     ...
    #   ],
    #   [....]
    # ]
    @_outline = []

    # Cache of svg path string
    @_svgPathStringCache = ''

    # set outline
    # @param {Object} outline
    # @return {SimpleGlyph} this
    @setOutline = (outline) ->
      @_outline = outline ? []
      @

    # return outline
    # @return {Object} outline
    @getOutline = () ->
      @_outline
  
  # Return SVG Path Data
  # @param {Array} matrix Matrix Array
  #                       [a, c, e]
  #                       [b, d, f]
  #                       [0, 0, 1]
  # @return {String}
  toSVGPathString: (matrix) ->
    if @_svgPathStringCache isnt ''
      return @_svgPathStringCache

    outline = @getTramsformedOutlin(matrix)
    pathString = []
    
    for contour, i in outline
      _contour = []
      startIndex = 0
      start = contour[0]

      # if start is off curve
      if not start.on
        if contor.length > 1
          startIndex = 1
          next = contour[1]

          # if next is off curve
          if not next.on
            _contour.push {
              x: (next.x - start.x) / 2
              y: (next.x - start.x) / 2
              relX: (next.relX - start.relX) / 2
              relY: (next.relY - start.relY) / 2
              on: true
            }

      # copy contour
      after_contour = []
      _contour = for coordinate, j in contour
        coordinate = {
          x: coordinate.x
          y: coordinate.y
          relX: coordinate.relX
          relY: coordinate.relY
          on: coordinate.on
        }

        if j < startIndex
          after_contour.push coordinate
        else
          coordinate

      _contour = _contour.concat after_contour
      start = _contour[0]
      end = _contour[_contour.length - 1]

      for c, k in _contour
        # start point
        if k is 0
          pathString.push 'M ' + [c.x, c.y].join(',')
       
        # other point
        else
          prev = _contour[k - 1]
          distance ={
            x: c.x - prev.x
            y: c.y - prev.y
          }

          # nothing to do
          if distance.x is 0 and distance.y is 0
            continue

          # line
          else if prev.on and c.on
            # h
            if distance.y is 0
              pathString.push 'H ' + c.x
            # v
            else if distance.x is 0
              pathString.push 'V ' + c.y
            # l
            else
              pathString.push 'L ' + [c.x, c.y].join(',')
          
          # q curve
          else if prev.on and not c.on
            pathString.push 'Q ' + [c.x, c.y].join(',')

          # t curve
          else if not prev.on and not c.on
            
            midPoint = {
              x: prev.x + (distance.x / 2)
              y: prev.y + (distance.y / 2)
              on: true
            }
            pathString.push [midPoint.x, midPoint.y].join(',') + ' T'

          # end curve
          else
            pathString.push [c.x, c.y].join(',')

          
      # close contour
      pathString.push if end.on then 'Z' else [start.x, start.y].join(',') + ' Z'

    # return Path
    @_svgPathStringCache = pathString.join(' ')

    
  # Return Matrix Tranformed Ouline
  # @param {Object} matrix 3x3 Matrix
  #                       {a, c, e
  #                        b, d, f
  #                        0, 0, 1}
  # @return {Array} Outline
  getTramsformedOutlin: (matrix) ->
    if typeof matrix is 'undefined'
      matrix = {
        a: 1, c: 0, e: 0,
        b: 0, d: 1, f: 0
      }

    for contour in @getOutline()
      for coordinate in contour
        {
          x: matrix.a * coordinate.x + matrix.c * coordinate.y + matrix.e
          y: matrix.b * coordinate.x + matrix.d * coordinate.y + matrix.f
          relX: matrix.a * coordinate.relX + matrix.c * coordinate.relY + matrix.e
          relY: matrix.b * coordinate.relX + matrix.d * coordinate.relY + matrix.f
          on: coordinate.on
        }


  # Create SimpleGlyph instance from TTFDataView
  # @param {TTFDataView} view
  # @param {Number} offset 
  # @param {Number} glyphID
  # @param {GlyfTable} glyfTable
  # @return {SimpleGlyph}
  @createFromTTFDataView: (view, offset, glyphID, glyfTable) ->
    
    # init flags
    ON_CURVE          = Math.pow 2, 0
    X_SHORT           = Math.pow 2, 1
    Y_SHORT           = Math.pow 2, 2
    REPEAT            = Math.pow 2, 3
    X_IS_SAME         = Math.pow 2, 4
    POSITIVE_X_SHORT  = Math.pow 2, 4
    Y_IS_SAME         = Math.pow 2, 5
    POSITIVE_Y_SHORT  = Math.pow 2, 5
    
    # init glyph
    view.seek offset
    g = new SimpleGlyph(glyphID, glyfTable)
    
    # number of contours
    g.numberOfContours = view.getShort()

    # no contours
    if g.numberOfContours is 0
      return g
    
    # xMin yMin xMax yMax
    g.xMin = view.getShort()
    g.yMin = view.getShort()
    g.xMax = view.getShort()
    g.yMax = view.getShort()
   
    # endPtsOfContours
    g.endPtsOfContours = for i in [1..g.numberOfContours]
      view.getUshort()

    # number of coordinates
    numberOfCoordinates = g.endPtsOfContours[g.endPtsOfContours.length - 1] + 1

    # instrunctions
    g.instructionLength = view.getUshort()
    if g.instructionLength > 0 
      g.instructions = for i in [1..g.instructionLength]
        view.getByte()
    
    # flags
    flags = []
    i = 0

    while i < numberOfCoordinates
      flag = view.getByte()
      flags.push flag
      i++

      # repeat
      if flag & REPEAT
        numRepeat = view.getByte()
        for j in [1..numRepeat]
          if i < numberOfCoordinates
            flags.push flag
            i++

    g.flags = flags

    # xCoordinates
    g.xCoordinates = for flag in flags
      x = 0
      if flag & X_SHORT # short Vector
        x = (if flag & POSITIVE_X_SHORT then 1 else -1) * view.getByte()
      else
        x = if flag & X_IS_SAME then 0 else view.getShort()

    # yCoordinates
    g.yCoordinates = for flag in flags
      y = 0
      if flag & Y_SHORT # short Vector
        y = (if flag & POSITIVE_Y_SHORT then 1 else -1) * view.getByte()
      else
        y = if flag & Y_IS_SAME then 0 else view.getShort()

    # outline
    startPtOfContour = x = y = 0
    outline = for endPtOfcountour in g.endPtsOfContours
      contour = for i in [startPtOfContour..endPtOfcountour]
        x += relX = g.xCoordinates[i]
        y += relY = g.yCoordinates[i]
        {
          x: x
          y: y
          relX: relX
          relY: relY
          on: flags[i] & ON_CURVE is ON_CURVE
        }
      startPtOfContour = endPtOfcountour + 1
      contour

    g.setOutline outline
    
    # return glyph
    g

# exports
module.exports = SimpleGlyph