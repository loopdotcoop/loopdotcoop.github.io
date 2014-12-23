# Config (you can modify these)
config =
  backgroundTop:    '#000066'
  backgroundBottom: 'black'
  containerAxis: '0,1,0'
  containerDegrees: '135'
  diffusePalette:  'green,cyan,red,cyan,red,cyan,red'
  specularPalette: 'green,#66ff99,yellow'
  emissivePalette: '#001103,#00ff11,#110011'
  xExtent: 8
  yExtent: 8
  zExtent: 8
  xyzMinSum: 0
  xyzMaxSum: 8 # set to a very high number for no maximum value of x + y + z
  xGap: .4
  yGap: .6
  zGap: .4
  spaceScatter: .2
  timeScatter: 2
  propagationRate: 250 # in ms
  clickDuration  : 1000 # in ms
  clickPower     : 4
  diminishFactor : .5

# Calculated from config (let the program work these out)
calcConfig = ->
  config.clickPowerDiffDivider = config.clickDuration / config.clickPower
  config.propagationRate = parseInt config.propagationRate, 10
  config.spaceScatter    = parseFloat config.spaceScatter
  config.timeScatter     = parseFloat config.timeScatter
  config.diffusePalette  = config.diffusePalette .split(',')
  config.specularPalette = config.specularPalette.split(',')
  config.emissivePalette = config.emissivePalette.split(',')


$canvas       = null
$container    = null
$colorPalette = null

window.buffer = buffer = []
window.shapes = shapes = []
window.queue  = queue  = []
window.future = future = []

# Create a normal AudioContext
try
  audioCtx = new window.AudioContext
catch e
  log e

reset = ->
  for key,value of config
    $el = $ '#' + key
    if ! $el then continue
    config[key] = $el.value
#    console.log $el.getAttribute 'value'
  calcConfig()

  # Rebuild the audio buffer
  buffer = []
  for colorIndex in [0..2]
    buffer[colorIndex] = []
    for noteNum in [0..config.yExtent]
      renderAudio noteNum, colorIndex

  # Rebuild the color palette
  empty $colorPalette
  for color,i in config.diffusePalette
    $a = make 'appearance', { def:"flat-#{i}" }
    $a.appendChild make 'material', 
      diffuseColor:  color
      specularColor: config.specularPalette[i] or 'black'
      emissiveColor: config.emissivePalette[i] or 'black'
    $colorPalette.appendChild $a

  # Rebuild the interactive elements
  for x,j in shapes
    for y,k in x
      for z,l in y
        delete y[l]
      delete x[k]
    delete shapes[j]
  empty $container
  # window.shapes = [] # @todo why does this break interactivity?
  # window.queue  = [] # @todo why does this break interactivity?
  # window.future = [] # @todo why does this break interactivity?


# jQuery would be overkill for this simple app
$  = document.querySelector.bind document # http://stackoverflow.com/a/12637169
$$ = document.querySelectorAll.bind document

# Prepare the <PRE> element to display logs
log = (html, append=true) ->
  $pre = $ 'pre'
  if $pre
    if html
      if append then $pre.innerHTML += '\n' + html else $pre.innerHTML = html
      $pre.scrollTop = $pre.scrollHeight
      console.log html
    else $pre.innerHTML


# Call `report()` from the console to check that nothing is stuck in `queue` or `future`
window.report = report = ->
  return "queue: #{queue.length} future: #{future.length}"


resize = ->
  if $canvas
    $canvas.style.width  = (window.innerWidth * .8 - 40) + 'px'
    $canvas.style.height = window.innerHeight + 'px'


make = (tag, attr, inner) ->
  el = document.createElement tag
  for key, value of attr
    el.setAttribute key, value
  if inner then el.innerHTML = inner
  return el

empty = (node) ->
  while node.hasChildNodes()
    node.removeChild node.lastChild


class Shape
  constructor: (@x, @y, @z) ->
    @t = make 'transform', { translation:"#{@x * config.xGap + @rndSpace() } #{@y * config.yGap + @rndSpace() } #{@z * config.zGap + @rndSpace() }" }
    s  = make 'shape'    , { onclick:"window.shapes[#{@x}][#{@y}][#{@z}].clicked()" }
    shapeTag = ['cone','cylinder','sphere','torus','box'][Math.floor Math.random() * 5 * (@x / config.xExtent)]
    s.appendChild make shapeTag    , { use:'small-' + shapeTag }
    @colorIndex = (Math.floor Math.random() * config.diffusePalette.length * ((@x / config.xExtent) + (@z / config.zExtent)) / 2)
    s.appendChild make 'appearance', { use:'flat-' + @colorIndex }
    @t.appendChild s
    $container.appendChild @t

  rndSpace: ->
    return (Math.random() - .5) * config.spaceScatter

  rndTime: ->
    return (Math.random() - .5) * config.timeScatter

  # mouseovered: ->
  #   source = audioCtx.createBufferSource()
  #   source.buffer = buffer[@y] # 
  #   gainNode = audioCtx.createGain()
  #   source.connect gainNode
  #   gainNode.connect audioCtx.destination
  #   gainNode.gain.value = .01
  #   source.start()

  clickTime: 0 # `0` signifies 'not animating'
  clicked: (@factor=1, @way=false) ->
    if 0 != @clickTime then console.log 'Already playing', @x, @y, @z
    if 0 == @clickTime # don't respond to clicks while animating
      @clickTime = timestampNow
      @render timestampNow
      queue.push @

      factor = @factor * config.diminishFactor

      try
        source = audioCtx.createBufferSource()
        source.buffer = buffer[@colorIndex][@y] # 
        gainNode = audioCtx.createGain()
        source.connect gainNode
        gainNode.connect audioCtx.destination
        gainNode.gain.value = factor
        source.start()
      catch e
        log e

      if .01 < factor # don't bother doing very gentle clicks
        jobs = []
        if shapes[@x + 1]         and shapes[@x + 1][@y] and shapes[@x + 1][@y][@z] and ('+x' == @way or ! @way) then jobs.push { shape:shapes[@x + 1][@y][@z], factor:factor, way:'+x' }
        if shapes[@x - 1]         and shapes[@x - 1][@y] and shapes[@x - 1][@y][@z] and ('-x' == @way or ! @way) then jobs.push { shape:shapes[@x - 1][@y][@z], factor:factor, way:'-x' }
        if shapes[@x][@y + 1]     and shapes[@x][@y + 1] and shapes[@x][@y + 1][@z] and ('+y' == @way or ! @way) then jobs.push { shape:shapes[@x][@y + 1][@z], factor:factor, way:'+y' }
        if shapes[@x][@y - 1]     and shapes[@x][@y - 1] and shapes[@x][@y - 1][@z] and ('-y' == @way or ! @way) then jobs.push { shape:shapes[@x][@y - 1][@z], factor:factor, way:'-y' }
        if shapes[@x][@y][@z + 1] and shapes[@x][@y]     and shapes[@x][@y][@z + 1] and ('+z' == @way or ! @way) then jobs.push { shape:shapes[@x][@y][@z + 1], factor:factor, way:'+z' }
        if shapes[@x][@y][@z - 1] and shapes[@x][@y]     and shapes[@x][@y][@z - 1] and ('-z' == @way or ! @way) then jobs.push { shape:shapes[@x][@y][@z - 1], factor:factor, way:'-z' }
        if 0 < jobs.length
          future.push
            timestamp: timestampNow + ( config.propagationRate * (1 - @rndTime()) )
            jobs: jobs
      # console.log timestampNow
      # console.log report()

  render: (timestamp) ->
    diff = timestamp - @clickTime # milliseconds since `clicked()` was last called
    scale = config.clickPower - diff / config.clickPowerDiffDivider # `2` if `diff` is `0`, or `0` if `diff` is `config.clickDuration`
    if config.clickDuration < diff
      @clickTime = 0 # `0` signifies 'not animating'
      scale = 0 # scale is probably approximately `0` already, but let's set it to precisely `0`, to be certain
    scale = scale * @factor + 1 # calculate the proper value for enlargement
    @t.setAttribute 'scale', "#{scale} #{scale} #{scale}"

#
# start = null
timestampNow = null
step = (timestamp) ->
  timestampNow = timestamp # make the most recent timestamp available to `clicked()`
  # if ! start then start = timestamp
  # progress = (timestamp - start) % 2000 / 2000

  if ! $canvas
    $canvas = $ 'canvas'
    resize()


  # Render `future`, or remove anything which is not animating
  index = 0
  length = future.length
  while index < length
    task = future[index]
    if task.timestamp < timestamp
      for job in task.jobs
        job.shape?.clicked job.factor, job.way # @todo make up for lost time # @todo why 'TypeError: job.shape is undefined' sometimes if `job.shape.clicked`
      future.splice index, 1
      length--
    else
      index++

  # Render `queue`, or remove anything which is not animating
  index = 0
  length = queue.length
  while index < length
    shape = queue[index]
    shape.render timestamp
    if 0 == shape.clickTime
      queue.splice index, 1
      length--
    else
      index++

  window.requestAnimationFrame step


window.clicker = (shape, scale=4) ->
  if ! shape.parentNode then return
  if 1 > scale then scale = 1
  shape.parentNode.setAttribute 'scale', "#{scale} #{scale} #{scale}"
  if 1 == scale then return
  setTimeout(
    ->
      window.clicker shapes[shape.x + 1]?[shape.y][shape.z], scale * .8
      window.clicker shapes[shape.x - 1]?[shape.y][shape.z], scale * .8
      window.clicker shapes[shape.x][shape.y + 1]?[shape.z], scale * .8
      window.clicker shapes[shape.x][shape.y - 1]?[shape.z], scale * .8
      window.clicker shapes[shape.x][shape.y][shape.z + 1] , scale * .8
      window.clicker shapes[shape.x][shape.y][shape.z - 1] , scale * .8
    , 100
  )


boot = ->
  log 'Booting...', false

  $container    = $ '#container'
  $colorPalette = $ '#colorPalette'
  $fieldset     = $ 'fieldset'

  for key,value of config
    label = make 'label', {}, key + ':'
    label.appendChild make 'input', { id:key, value:value, onkeypress:"if (event.which == 13 || event.keyCode == 13) { construct() }" }
    $fieldset.appendChild label

  button = make 'a', { onclick:'construct()', class:'button' }, 'Rebuild'
  $fieldset.appendChild button

  construct()


renderAudio = (noteNum, colorBuffer) ->
  try

    # freq = (noteNum + 4) * 200 # eg `freq` is `1000` when `noteNum` is `0`, or `1200` when `noteNum` is `1`, etc
    freq = ([
      44100 * 32 * 1      / 5400 # 1
      44100 * 32 * 5  / 4 / 5400 # 1.25
      44100 * 32 * 3  / 2 / 5400 # 1.5
      # 44100 * 32 * 15 / 8 / 5400 # 1.875
      44100 * 32 * 1  * 2 / 5400 # 2
      44100 * 32 * 9  / 4 / 5400 # 2.25
      44100 * 32 * 5  / 2 / 5400 # 2.5
      44100 * 32 * 3      / 5400 # 3
      44100 * 32 * 4      / 5400 # 4
      44100 * 32 * 9  / 2 / 5400 # 4.5
      44100 * 32 * 5      / 5400 # 5
    ])[noteNum]
    colorChoice = ([
      ['sine','square']
      ['sine','sine','triangle','triangle']
      ['sine','sawtooth']
    ])[colorBuffer]
    octave = ([1,.5,.25])[colorBuffer]

    # Create an offline audio context (which cannot be reused after rendering)
    duration = 1 # in seconds
    offlineCtx = new OfflineAudioContext 1, 44100*duration, 44100 # numOfChannels, length, sampleRate

    # Cache buffered audio when background rendering has finished
    offlineCtx.oncomplete = (evt) ->
      buffer[colorBuffer].push evt.renderedBuffer
      elapsed = Math.round( (audioCtx.currentTime - renderTime) * 1000000 ) / 1000
      # log "...offline render \##{buffer[colorBuffer].length} is complete, after #{elapsed}ms"

    # Create four oscillator nodes in the offline audio context
    sounds = for i in [0 .. 3]
      offlineCtx.createOscillator()

    # Prepare some unique sounds, and connect them to the offline audio context
    for type, i in colorChoice
      sounds[i].type = type
      # log (    ) + 'Hz ' + type
      sounds[i].frequency.value = ( freq + Math.floor( Math.random() * 5 ) ) * octave
      gainNode = offlineCtx.createGain()
      sounds[i].connect gainNode
      gainNode.connect offlineCtx.destination
      gainNode.gain.exponentialRampToValueAtTime 0.01, offlineCtx.currentTime + 1
      sounds[i].start()

    # Begin rendering
    offlineCtx.startRendering()
    renderTime = audioCtx.currentTime
    # log 'Starting offline rendering...'

  catch e
    log e


window.construct = construct = ->
  log 'Constructing...'

  reset()
  resize()

  $('html').style.backgroundColor = config.backgroundBottom
  $('body').style.backgroundImage = "linear-gradient(180deg, #{config.backgroundTop}, #{config.backgroundBottom})"
  $('body').style.backgroundRepeat = "no-repeat"
  $container.setAttribute 'translation', "-#{config.xExtent * config.xGap / 2} -#{config.yExtent * config.yGap / 2} -#{config.zExtent * config.zGap / 2}"
  $container.setAttribute 'rotation'   , config.containerAxis + ' ' + (config.containerDegrees * 0.01745329251)
  $container.setAttribute 'center'     , "#{config.xExtent * config.xGap / 2} #{config.yExtent * config.yGap / 2} #{config.zExtent * config.zGap / 2}"

  # $('fog').setAttribute 'visibilityRange', (Math.max config.xExtent, config.yExtent, config.zExtent) * 4
  # $('fog').setAttribute 'color', config.background
 
  for x in [0..config.xExtent]
    for y in [0..config.yExtent]
      for z in [0..config.zExtent]
        xyzSum = x + y + z
        if config.xyzMinSum <= xyzSum <= config.xyzMaxSum
          shapes[x] ?= []
          shapes[x][y] ?= []
          shapes[x][y][z] = new Shape x,y,z

  window.requestAnimationFrame step


# Build the scene when the DOM is ready
window.addEventListener 'load', boot

window.addEventListener 'resize', resize


